// ignore_for_file: avoid_print
// Pure-Dart (no flutter_test) host+client protocol smoke with progress logs.
import 'dart:async';
import 'dart:math';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/net/client_connection.dart';
import 'package:toil_troublez/net/host_lobby.dart';
import 'package:toil_troublez/session/local_session.dart';

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
  if (e.pendingCard != null) b.write(' p=${e.pendingCard!.id}');
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

Future<void> until(bool Function() cond, {Duration t = const Duration(seconds: 10)}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > t) throw StateError('wait timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> main() async {
  final host = HostLobby(hostName: 'TestHost', port: 0);
  await host.start();
  final client = ClientConnection(address: '127.0.0.1', port: host.port, myName: 'Smith');
  await client.connect();
  await until(() => client.lobby != null);
  await until(() => (host.lobby?.seats.length ?? 0) == 2);
  host.addBot();
  await until(() => (client.lobby?.seats.length ?? 0) == 3);
  host.startGame();
  await until(() => client.table != null);
  final cs = client.table!;
  final hs = host.table! as LocalGameSession;
  print('started; fp=${fp(hs.engine)}');

  final rng = Random(42);
  final sw = Stopwatch()..start();
  var iter = 0;
  var lastLog = '';
  String? lastFp;
  while (!hs.engine.over) {
    final f = fp(hs.engine);
    final seat = hs.engine.acting;
    if (seat == 1) {
      // Decide once per state, and only once the client engine has caught
      // up with the host (otherwise the host would reject the command).
      if (f != lastFp && fp(cs.engine) == f) {
        lastFp = f;
        cs.submit(Bot.decide(cs.engine, 1, BotSkill.master, rng));
      }
    } else if (seat != null) {
      if (f != lastFp) {
        lastFp = f;
        hs.applyAs(seat, Bot.decide(hs.engine, seat, BotSkill.master, rng));
      }
    }
    if (f != lastLog && sw.elapsed.inSeconds % 2 == 0) {
      lastLog = f;
      print('t=${sw.elapsed.inSeconds}s i=$iter $f');
    }
    iter++;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    if (sw.elapsed > const Duration(seconds: 60)) {
      print('STUCK: host=$f client=${fp(cs.engine)} csErr=${cs.errorMessage}');
      throw StateError('net smoke stuck after 60s');
    }
  }
  print(hs.engine.over
      ? 'DONE over=true winner=${hs.engine.winners}'
      : 'NOT OVER');
  await host.leave();
  client.dispose();
}