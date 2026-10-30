// ignore_for_file: avoid_print
import 'dart:math';

import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/engine.dart';

/// Throwaway harness: plays full bot games and reports aggregate stats.
void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args.first) : 300;
  var busts = 0;
  var collections = 0;
  var vanish = 0, summon = 0, poison = 0, cloak = 0;
  var reshuffles = 0;
  var deckEnds = 0;
  var totalCmds = 0;
  var games = 0;
  final skillWins = <BotSkill, int>{
    BotSkill.amateur: 0,
    BotSkill.skilled: 0,
    BotSkill.master: 0,
  };
  final skills = BotSkill.values;

  for (var g = 0; g < n; g++) {
    final seed = 1000 + g * 977;
    final np = 2 + (seed % 5); // 2..6
    final players = [
      for (var i = 0; i < np; i++)
        Player(
            id: i,
            name: 'B$i',
            isBot: true,
            skill: skills[(seed >> (i % 5)) % 3]),
    ];
    final e = GameEngine(players: players, seed: seed);
    final rngs = [for (var i = 0; i < np; i++) Random(seed * 31 + i)];
    var cmds = 0;
    while (!e.over) {
      if (++cmds > 20000) {
        throw StateError('game $seed did not terminate after $cmds cmds; '
            'phase=${e.phase} current=${e.current}');
      }
      final me = e.acting!;
      e.apply(Bot.decide(e, me, e.players[me].skill!, rngs[me]), byPlayer: me);
    }
    totalCmds += cmds;
    games++;
    busts += e.events.where((ev) => ev.type == EventType.bust).length;
    collections +=
        e.events.where((ev) => ev.type == EventType.collection).length;
    vanish += e.events.where((ev) => ev.type == EventType.vanish).length;
    summon += e.events.where((ev) => ev.type == EventType.summon).length;
    poison += e.events.where((ev) => ev.type == EventType.poison).length;
    cloak += e.events.where((ev) => ev.type == EventType.cloak).length;
    reshuffles += e.depletions;
    if (e.events.any((ev) => ev.type == EventType.deckEmpty)) deckEnds++;
    if (e.winners.isEmpty) {
      throw StateError('game $seed ended with no winners');
    }
    for (final w in e.winners.toSet()) {
      final sk = e.players[w].skill!;
      skillWins[sk] = (skillWins[sk] ?? 0) + 1;
    }
    for (final p in e.players) {
      if (p.score < 0) throw StateError('negative score in game $seed');
    }
  }
  print('games=$games totalCmds=$totalCmds (avg '
      '${(totalCmds / games).toStringAsFixed(0)}/game)');
  print('busts=$busts collections=$collections '
      'vanish=$vanish summon=$summon poison=$poison cloak=$cloak');
  print('reshuffles=$reshuffles deckEnds=$deckEnds');
  print('win share by skill: $skillWins');
}
