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
}
