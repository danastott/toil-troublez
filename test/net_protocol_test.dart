// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/net/client_connection.dart';
import 'package:toil_troublez/net/host_lobby.dart';
import 'package:toil_troublez/session/local_session.dart';

String picks(GameEngine e) =>
    e.pendingPicks.map((o) => 'r${o.row}:${o.side.name}').join(' ');

String fp(GameEngine e) {
  final b = StringBuffer('s${e.seed} ${e.phase.name} c${e.current} '
      'd${e.drawPile.length} x${e.discardPile.length}');
  for (final p in e.players) {
    b.write(' p${p.id}[${p.trove.map((c) => c.id).join(",")}:${p.collections}]');
  }
  for (final row in e.forest.rows) {
    b.write('|');
    for (final s in row) {
      b.write(s.card.id);
      if (s.cloak != null) b.write('+${s.cloak!.id}');
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

Future<void> until(bool Function() cond,
    {Duration t = const Duration(seconds: 10)}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > t) throw StateError('wait timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('host + client: lobby sync, start, moves, bots, identical finish',
      () async {
    final host = HostLobby(hostName: 'TestHost', port: 0);
    await host.start();
    addTearDown(() => host.leave());
    final client = ClientConnection(
      address: '127.0.0.1',
      port: host.port,
      myName: 'Smith',
    );
    addTearDown(client.dispose);
    await client.connect();

    await until(() => client.lobby != null);
    await until(() => (host.lobby?.seats.length ?? 0) == 2);
    host.addBot();
    await until(() => (client.lobby?.seats.length ?? 0) == 3);
    host.startGame();
    await until(() => client.table != null);
    final cs = client.table!;
    final hs = host.table! as LocalGameSession;
    expect(cs.engine.seed, hs.engine.seed);
    expect(fp(cs.engine), fp(hs.engine));

    final rng = Random(42);
    final sw = Stopwatch()..start();
    var iter = 0;
    var lastSecond = -1;
    String? lastFp;
    while (!hs.engine.over) {
      final f = fp(hs.engine);
      final seat = hs.engine.acting;
      if (seat == 1) {
        // The client decides once per host state, and only when its engine
        // has caught up (otherwise the host would reject the command).
        // Without this latch the same command is resubmitted every tick and
        // floods the shared websocket/event loop until nothing is delivered.
        if (f != lastFp && fp(cs.engine) == f) {
          lastFp = f;
          final cmd = Bot.decide(cs.engine, 1, BotSkill.master, rng);
          final canAct = cs.canAct;
          cs.submit(cmd);
          if (!canAct || cs.errorMessage != null) {
            print('iter=$iter CLIENT REJECT: canAct=$canAct '
                'err=${cs.errorMessage} acting=${cs.engine.acting} '
                'phase=${cs.engine.phase} cmd=$cmd');
          }
        }
      } else if (seat != null) {
        if (f != lastFp) {
          lastFp = f;
          hs.applyAs(seat, Bot.decide(hs.engine, seat, BotSkill.master, rng));
        }
      }
      try {
        await until(() => fp(cs.engine) == fp(hs.engine));
      } on StateError {
        print('DIVERGED:\n  host   ${fp(hs.engine)}\n  client ${fp(cs.engine)}');
        rethrow;
      }
      // Unconditional pacing: the loop must never busy-spin, or it floods
      // the websocket and starves the shared event loop.
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final sec = sw.elapsed.inSeconds;
      if (sec != lastSecond) {
        lastSecond = sec;
        print('t=${sec}s i=$iter seat=$seat phase=${hs.engine.phase} '
              'pend=${hs.engine.pendingCard?.id} cAct=${cs.engine.acting} '
              'hp=${picks(hs.engine)} cp=${picks(cs.engine)} ${fp(hs.engine)}');
      }
      iter++;
      if (sw.elapsed > const Duration(seconds: 25)) {
        fail('stuck 25s: seat=$seat phase=${hs.engine.phase} '
            'cAct=${cs.engine.acting} hp=${picks(hs.engine)} '
            'cp=${picks(cs.engine)}\nhost: ${fp(hs.engine)}\n'
            'client: ${fp(cs.engine)}');
      }
    }
    print('DONE i=$iter t=${sw.elapsedMilliseconds}ms winners=${hs.engine.winners}');
    expect(hs.engine.over, isTrue);
    await until(() => cs.engine.over);
    expect(fp(cs.engine), fp(hs.engine));
    expect(cs.engine.winners, hs.engine.winners);
    expect(cs.engine.winners, isNotEmpty);
  });
}