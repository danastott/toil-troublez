// ignore_for_file: avoid_print
// Local (no-network) full-game smoke: every seat driven by Bot.decide.
import 'dart:math';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';

String snap(GameEngine e) {
  final res = e.resolution;
  final van = res?.vanish;
  return '${e.phase.name}#${e.pendingCard?.id}#${e.current}'
      '#${e.forest.rows.map((r) => r.length).join(',')}'
      '#${e.drawPile.length}'
      '#${[for (final p in e.players) '${p.trove.map((c) => c.id).join("-")}:${p.collections}'].join(";")}'
      '#res=${res == null ? "-" : "q${res.queue.length},sum${res.summonTarget},poi${res.poisonTarget},van${van == null ? "-" : "${van.type},${van.awaitingVictim}"}"}';
}

void main() {
  final engine = GameEngine(
    players: [
      Player(id: 0, name: 'A'),
      Player(id: 1, name: 'B'),
      Player(id: 2, name: 'C'),
    ],
    seed: 7,
  );
  final rng = Random(1);
  var moves = 0;
  var ignored = 0;
  final sw = Stopwatch()..start();
  while (!engine.over) {
    final seat = engine.acting;
    if (seat == null) {
      moves++;
      if (moves > 5000) {
        print('FAIL: acting null forever; ${snap(engine)}');
        return;
      }
      continue;
    }
    final before = snap(engine);
    final cmd = Bot.decide(engine, seat, BotSkill.master, rng);
    engine.apply(cmd, byPlayer: seat);
    moves++;
    if (before == snap(engine)) {
      ignored++;
      print('IGNORED($ignored): seat=$seat $cmd\n  $before');
      if (ignored > 10) {
        print('FAIL: repeated ignored commands');
        return;
      }
    }
    if (moves > 200000) {
      print('FAIL: no termination; ${snap(engine)}');
      return;
    }
  }
  print('OK: over in $moves moves, ${sw.elapsedMilliseconds}ms, '
      'scores=${engine.players.map((p) => '${p.name}:${p.score}').join(' ')}');
}
