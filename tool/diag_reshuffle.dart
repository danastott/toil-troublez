// TEMP diagnostic: play full 4-player all-bot games and trace the order in
// which cards come out of the draw pile, marking reshuffle points.
import 'dart:math';

import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';

void main() {
  final rng = Random(42);
  var reshuffleGames = 0;
  var longRunAfterReshuffle = 0;
  var sortedAfterReshuffle = 0;
  final examples = <String>[];

  for (var g = 0; g < 400; g++) {
    final seed = rng.nextInt(1 << 30);
    final e = GameEngine(
      players: [
        for (var i = 0; i < 4; i++)
          Player(id: i, name: 'P$i', isBot: true, skill: BotSkill.skilled),
      ],
      seed: seed,
    );
    final rngs = [for (var i = 0; i < 4; i++) Random(seed + i * 7)];
    var steps = 0;
    while (!e.over && steps++ < 20000) {
      final me = e.acting;
      if (me == null) break;
      e.apply(Bot.decide(e, me, BotSkill.skilled, rngs[me]), byPlayer: me);
    }
    if (!e.over) {
      print('game $g (seed $seed) did not terminate');
      continue;
    }

    // Trace the draw order; 'M' for magicians, digits for talisman numbers.
    final trace = StringBuffer();
    var reshuffleSeen = false;
    for (final ev in e.events) {
      if (ev.type == EventType.reshuffle) {
        trace.write(' | ');
        reshuffleSeen = true;
      } else if (ev.type == EventType.draw && ev.card != null) {
        final c = ev.card!;
        trace.write(c.isTalisman ? '${c.number}' : 'M');
      }
    }

    if (!reshuffleSeen) continue;
    reshuffleGames++;
    final seg = trace.toString().split('|').last.trim();
    final nums = <int>[];
    for (var i = 0; i < seg.length; i++) {
      final c = seg.codeUnitAt(i);
      if (c == 77) {
        nums.add(-1);
      } else if (c >= 48 && c <= 57) {
        nums.add(c - 48);
      }
    }
    // Run length over talisman numbers only (magicians are one big group
    // of 23, so their runs are expected and not a bug signal).
    final tal = nums.where((n) => n > 0).toList();
    var run = 1;
    var maxRun = 1;
    for (var i = 1; i < tal.length; i++) {
      run = tal[i] == tal[i - 1] ? run + 1 : 1;
      if (run > maxRun) maxRun = run;
    }
    if (maxRun >= 4) longRunAfterReshuffle++;
    // Is the talisman part weakly increasing (the buggy sorted signature)?
    var sorted = true;
    for (var i = 1; i < tal.length; i++) {
      if (tal[i] < tal[i - 1]) {
        sorted = false;
        break;
      }
    }
    if (tal.length >= 8 && sorted) {
      sortedAfterReshuffle++;
      if (examples.length < 3) {
        examples.add('seed=$seed post-reshuffle draws: $seg');
      }
    }
  }

  print('games: 400');
  print('games that reached a reshuffle: $reshuffleGames');
  print('post-reshuffle maxRun>=4: $longRunAfterReshuffle');
  print('post-reshuffle talisman draws weakly-sorted: $sortedAfterReshuffle');
  for (final ex in examples) print(ex);
}
