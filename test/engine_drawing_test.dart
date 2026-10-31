import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/commands.dart';
import 'package:toil_troublez/game/cards.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/game/rules.dart';

/// The drawing phase is a stable decision point: the engine waits for an
/// explicit [DrawCmd] or [PassCmd] instead of auto-drawing.
void main() {
  List<Player> three() => [
        Player(id: 0, name: 'You'),
        Player(id: 1, name: 'Bot 1', isBot: true, skill: BotSkill.skilled),
        Player(id: 2, name: 'Bot 2', isBot: true, skill: BotSkill.skilled),
      ];

  // Seed 1: seat 0 acts first and its first draw is playable.
  // Seed 40: seat 0 acts first and its first draw busts.
  GameEngine game(int seed) => GameEngine(players: three(), seed: seed);

  test('deck: 3 of each kind and color, each kind fixed to one number', () {
    final deck = Deck.build(42);
    expect(deck.length, 60 + 23);
    for (final t in TalismanType.values) {
      for (final c in CardColor.values) {
        final n = [for (final g in deck)
              if (g.talisman == t && g.color == c) 1].length;
        expect(n, 4, reason: 'want 4 ${t.label}s of color $c');
      }
    }
    for (final g in deck) {
      if (g.talisman == null) continue;
      expect(g.number, g.talisman!.number,
          reason: '${g.talisman!.label} must be '
              'number ${g.talisman!.number}');
    }
  });

  test('turn start waits for an explicit draw', () {
    final e = game(1);
    expect(e.phase, Phase.drawing);
    expect(e.acting, 0);
    final pile = e.drawPile.length;
    // The engine no longer advances itself.
    expect(e.pendingCard, isNull);
    expect(e.drawPile.length, pile);
  });

  test('a pass during the first draw is ignored: the draw is mandatory', () {
    final e = game(1);
    e.apply(const PassCmd(), byPlayer: 0);
    // Rulebook p. 5: each turn you must draw at least one card. Passing
    // without drawing is not a legal move.
    expect(e.phase, Phase.drawing);
    expect(e.current, 0);
    expect(
        e.events.where((ev) => ev.type == EventType.pass && ev.player == 0),
        isEmpty);
  });

  test('draw, place, then pass leads to the row choice', () {
    final e = game(1);
    e.apply(const DrawCmd(), byPlayer: 0);
    expect(e.phase, Phase.placing);
    e.apply(const PlaceCmd(NewRowPlacement()), byPlayer: 0);
    expect(e.phase, Phase.continuing);
    expect(e.forest.rows.length, 1);
    e.apply(const PassCmd(), byPlayer: 0);
    expect(e.phase, Phase.choosingRow);
    expect(e.acting, 0);
  });

  test('continue draw draws the next card immediately', () {
    final e = game(1);
    e.apply(const DrawCmd(), byPlayer: 0);
    e.apply(const PlaceCmd(NewRowPlacement()), byPlayer: 0);
    expect(e.phase, Phase.continuing);
    final pile = e.drawPile.length;
    // Push your luck: the next card is drawn at once (seed 1's second
    // draw is a playable Flower), not deferred to a second decision.
    e.apply(const ContinueCmd(), byPlayer: 0);
    expect(e.drawPile.length, pile - 1);
    expect(e.phase, Phase.placing);
    expect(e.pendingCard, isNotNull);
  });

  test('pass is ignored while a card is awaiting placement', () {
    final e = game(1);
    e.apply(const DrawCmd(), byPlayer: 0);
    expect(e.phase, Phase.placing);
    e.apply(const PassCmd(), byPlayer: 0);
    expect(e.phase, Phase.placing);
    expect(e.pendingCard, isNotNull);
  });

  test('draw and continue are ignored outside their phases', () {
    final e = game(1);
    e.apply(const DrawCmd(), byPlayer: 0);
    final pile = e.drawPile.length;
    // In placing: neither the draw nor a continue is accepted.
    e.apply(const DrawCmd(), byPlayer: 0);
    e.apply(const ContinueCmd(), byPlayer: 0);
    expect(e.phase, Phase.placing);
    expect(e.drawPile.length, pile);
  });

  test('commands from the wrong player are ignored', () {
    final e = game(1);
    final pile = e.drawPile.length;
    e.apply(const DrawCmd(), byPlayer: 1);
    expect(e.phase, Phase.drawing);
    expect(e.drawPile.length, pile);
  });

  test('bust on the draw discards the card and ends the turn', () {
    final e = game(40);
    final pile = e.drawPile.length;
    e.apply(const DrawCmd(), byPlayer: 0);
    // Bust: the card is discarded, pickups find nothing, the turn ends.
    expect(e.phase, Phase.drawing);
    expect(e.current, 1);
    expect(e.drawPile.length, pile - 1);
    expect(e.discardPile, hasLength(1));
    expect(e.events.any((ev) =>
        ev.player == 0 &&
        (ev.type == EventType.bust ||
            (ev.type == EventType.cloak && ev.detail == 'discarded'))),
        isTrue);
  });

  test('a full bot game terminates with winners', () {
    final e = GameEngine(
        players: [
          Player(id: 0, name: 'Bot 0', isBot: true, skill: BotSkill.skilled),
          Player(id: 1, name: 'Bot 1', isBot: true, skill: BotSkill.skilled),
          Player(id: 2, name: 'Bot 2', isBot: true, skill: BotSkill.skilled),
        ],
        seed: 1);
    final rngs = [
      for (var i = 0; i < e.players.length; i++) Random(1000 + i),
    ];
    var cmds = 0;
    while (!e.over) {
      if (++cmds > 20000) {
        fail('game did not terminate after $cmds commands '
            '(phase=${e.phase}, current=${e.current})');
      }
      final me = e.acting!;
      e.apply(Bot.decide(e, me, e.players[me].skill!, rngs[me]),
          byPlayer: me);
    }
    expect(e.winners, isNotEmpty);
  });

  List<Player> four() => [
        Player(id: 0, name: 'You'),
        Player(id: 1, name: 'Bot 1', isBot: true, skill: BotSkill.skilled),
        Player(id: 2, name: 'Bot 2', isBot: true, skill: BotSkill.skilled),
        Player(id: 3, name: 'Bot 3', isBot: true, skill: BotSkill.skilled),
      ];

  /// A 4-player game whose draw pile is empty and whose discard pile holds
  /// 12 copies of each of three different numbers (ids 24-59: Mushrooms,
  /// Ravens, Flowers). The next draw triggers the reshuffle.
  GameEngine reshuffled() {
    final e = GameEngine(players: four(), seed: 3);
    e.drawPile.clear();
    for (var id = 24; id < 60; id++) {
      e.discardPile.add(e.cardById(id)!);
    }
    e.draw();
    return e;
  }

  test('reshuffle mixes the discard pile instead of sorting by number', () {
    final e = reshuffled();
    expect(e.depletions, 1);
    // Reconstruct the full reshuffled draw order: the remaining pile
    // (bottom to top), then the card just drawn.
    final drawn = e.events
        .firstWhere((ev) => ev.type == EventType.draw)
        .card!;
    final nums = [...e.drawPile.reversed, drawn]
        .map((c) => c.number!)
        .toList();
    final counts = <int, int>{};
    for (final n in nums) {
      counts[n] = (counts[n] ?? 0) + 1;
    }
    expect(counts, {3: 12, 4: 12, 5: 12},
        reason: 'the reshuffled pile must be a permutation of the discards');
    // The old code sorted the pile by card id, so draws came out in
    // number order (all 3s, then all 4s, then all 5s) and the top of the
    // pile was predictable. A real shuffle must not.
    var run = 1;
    var maxRun = 1;
    for (var i = 1; i < nums.length; i++) {
      run = nums[i] == nums[i - 1] ? run + 1 : 1;
      if (run > maxRun) maxRun = run;
    }
    expect(maxRun, lessThan(8));
    var monotone = true;
    for (var i = 1; i < nums.length; i++) {
      if (nums[i] < nums[i - 1]) {
        monotone = false;
        break;
      }
    }
    expect(monotone, isFalse,
        reason: 'the draw order must not be sorted by number');
  });

  test('reshuffle is deterministic for the same seed', () {
    final a = reshuffled();
    final b = reshuffled();
    final orderA = [...a.drawPile.reversed];
    final orderB = [...b.drawPile.reversed];
    expect(orderA.map((c) => c.id), orderB.map((c) => c.id));
  });
}
