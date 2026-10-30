// ignore_for_file: avoid_print
import 'dart:math';

import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';

/// Win-rate sweep for the continue margin: seat 0 = master @ margin,
/// seats 1-2 = amateur baseline. Reports seat-0 win rate + avg score.
void main(List<String> args) {
  final n = int.parse(args.isNotEmpty ? args[0] : '900');
  const np = 3;
  final margins = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0];
  for (final m in margins) {
    Bot.testMarginOverride = m;
    final rngSeed = Random(999);
    var xScore = 0.0, baseScore = 0.0, xWins = 0;
    for (var g = 0; g < n; g++) {
      final seed = rngSeed.nextInt(1 << 30);
      final players = [
        Player(id: 0, name: 'X', isBot: true, skill: BotSkill.master),
        Player(id: 1, name: 'A1', isBot: true, skill: BotSkill.amateur),
        Player(id: 2, name: 'A2', isBot: true, skill: BotSkill.amateur),
      ];
      final e = GameEngine(players: players, seed: seed);
      final rngs = [for (var i = 0; i < np; i++) Random(seed * 31 + i)];
      while (!e.over) {
        final me = e.acting!;
        e.apply(Bot.decide(e, me, e.players[me].skill!, rngs[me]),
            byPlayer: me);
      }
      xScore += e.players[0].score;
      baseScore += (e.players[1].score + e.players[2].score) / 2;
      if (e.players[0].score >= e.players[1].score &&
          e.players[0].score >= e.players[2].score) {
        xWins++;
      }
    }
    Bot.testMarginOverride = null;
    print('margin=${m.toStringAsFixed(1)}: '
        'avg=${(xScore / n).toStringAsFixed(2)} '
        'baseline=${(baseScore / n).toStringAsFixed(2)} '
        'winRate=${(xWins / n * 100).toStringAsFixed(1)}%');
  }
}
