// ignore_for_file: avoid_print
// 2 players (host + client), both seats driven through the real paths:
// seat 0 via the host session, seat 1 via the client connection websocket.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/rules.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/net/client_connection.dart';
import 'package:toil_troublez/net/host_lobby.dart';
import 'package:toil_troublez/session/local_session.dart';

Future<bool> waitUntil(bool Function() cond, Duration t) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > t) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

String fp(GameEngine e) {
  final b = StringBuffer('${e.phase.name} c${e.current} '
      'd${e.drawPile.length} x${e.discardPile.length}');
  for (final p in e.players) {
    b.write(' p${p.id}[${p.trove.map((c) => c.id).join(",")}:${p.collections}]');
  }
  for (final row in e.forest.rows) {
    b.write('|');
    for (final s in row) {
      b.write(s.card.id);
    }
  }
  if (e.pendingCard != null) b.write(' pend=${e.pendingCard!.id}');
  // Resolution-internal state: a magician resolution can advance (vanish
  // type chosen, summon target set) without any pile or forest change, so
  // the decision latch must see it.
  final r = e.resolution;
  if (r != null) {
    final v = r.vanish;
    final vd = v == null
        ? '-'
        : '${v.type?.index}/${v.pos}/${v.awaitingVictim}/${v.victims.join(",")}';
    b.write(' res h${r.holder} ${r.mode.name}'
        ' q${r.queue.map((c) => c.id).join("-")}'
        ' v$vd'
        ' s${r.summonTarget ? 1 : 0}p${r.poisonTarget ? 1 : 0} a${e.acting}');
  }
  return b.toString();
}

 String _opt(PlacementOption o) {
   if (o is NewRowPlacement) return 'N';
   if (o is RowPlacement) {
     return 'R${o.row}${o.side == PlaceSide.left ? 'l' : 'r'}';
   }
   if (o is CloakPlacement) return 'C${o.targetId}';
   return '?';
 }

 String _troves(GameEngine e) => e.players
     .map((p) => 'p${p.id}['
         '${p.trove.map((c) => c.isTalisman ? '${c.id}:${c.talisman!.label}' : '${c.id}:MAG${c.magician!}').join(",")}'
         ':${p.collections}]')
     .join(' ');

 String full(GameEngine e) {
   final r = e.resolution;
   final res = r == null
       ? '-'
       : 'res[h${r.holder} ${r.mode.name} q${r.queue.map((c) => c.id).join(",")} '
           'v=${r.vanish?.type} s=${r.summonTarget} p=${r.poisonTarget} a=${r.actingPlayer}]';
   return '${e.phase.name} c${e.current} dep${e.depletions} '
       'd${e.drawPile.length} x${e.discardPile.length} pend=${e.pendingCard?.id} '
       'popt[${e.pendingOptions.map(_opt).join(",")}] '
       'ppick[${e.pendingPicks.map((o) => 'P${o.row}${o.side == PlaceSide.left ? 'l' : 'r'}').join(",")}] '
       '$res '
       '${_troves(e)} '
      'f[${e.forest.rows.map((ro) => ro.map((s) => s.card.id).join("/")).join("|")}]';
 }

void main() {
  test('two-player game plays out over the websocket', () async {
    final host = HostLobby(hostName: 'TestHost2', port: 0);
    await host.start();
    addTearDown(() => host.leave());
    final client = ClientConnection(
      address: '127.0.0.1',
      port: host.port,
      myName: 'Solo',
    );
    addTearDown(client.dispose);
    await client.connect();
    await waitUntil(() => client.lobby != null, const Duration(seconds: 10));
    await waitUntil(
        () => (host.lobby?.seats.length ?? 0) == 2,
        const Duration(seconds: 10));
    host.startGame();
    await waitUntil(() => client.table != null, const Duration(seconds: 10));
    final cs = client.table!;
    final hs = host.table! as LocalGameSession;

    final rng = Random(7);
    final sw = Stopwatch()..start();
    var i = 0;
    String? lastFp;
    while (!hs.engine.over) {
      final f = fp(hs.engine);
      final seat = hs.engine.acting;
      if (seat == 1) {
        // The client decides once per state, and only when its engine has
        // caught up with the host's view (otherwise the host would reject
        // the command). Retry every tick until it catches up.
        if (f != lastFp && fp(cs.engine) == f) {
          lastFp = f;
          cs.submit(Bot.decide(cs.engine, 1, BotSkill.master, rng));
        }
      } else if (seat != null) {
        if (f != lastFp) {
          lastFp = f;
          hs.applyAs(0, Bot.decide(hs.engine, 0, BotSkill.master, rng));
        }
      }
      // Unconditional pacing: the loop must never busy-spin, or it floods
      // the websocket and starves the shared event loop.
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (sw.elapsed > const Duration(seconds: 30)) {
        final hsTry = Bot.decide(hs.engine, 0, BotSkill.master, rng)
            .toJson()
            .toString();
        final csTry = Bot.decide(cs.engine, 1, BotSkill.master, rng)
            .toJson()
            .toString();
        print('STUCK seed=${hs.engine.seed} acting=${hs.engine.acting} '
            'hsTry=$hsTry csTry=$csTry\n'
            'host=${full(hs.engine)}\n'
            'client=${full(cs.engine)} csErr=${cs.errorMessage}');
        fail('stuck 30s');
      }
    }
    print('DONE i=$i t=${sw.elapsedMilliseconds}ms '
        'winners=${hs.engine.winners}');
    await waitUntil(() => cs.engine.over, const Duration(seconds: 5));
    expect(fp(cs.engine), fp(hs.engine));
    expect(hs.engine.winners, isNotEmpty);
  });
}