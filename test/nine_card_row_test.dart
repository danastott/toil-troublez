// Repro for "a row with 9 cards won't accept more cards".
//
// A full row is 5 Talismans + 3 Magicians (8 cards) plus a Cloak covering
// one of the Talismans — 9 visible cards. The rulebook (p. 13-14) says the
// hidden Talisman "may reset which cards can be played in that row", so the
// row must still accept: another Cloak (over any visible Talisman) and a
// duplicate of the hidden Talisman's type (when number and colour allow).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/game/cards.dart';
import 'package:toil_troublez/game/commands.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/game/rules.dart';
import 'package:toil_troublez/session/local_session.dart';
import 'package:toil_troublez/ui/screens/game.dart';
import 'package:toil_troublez/ui/theme.dart';

const _seed = 7;

LocalGameSession localSession() => LocalGameSession(
      players: [
        Player(id: 0, name: 'Me'),
        Player(id: 1, name: 'B', isBot: true, skill: BotSkill.skilled),
      ],
      mySeat: 0,
      seed: _seed,
      botDelayMs: 0,
    );

/// A full 9-card row: all five Talismans (Flower #5 cloaked), all three
/// Magicians, one Cloak. Sun/Moon/Star chosen so no two neighbours share a
/// background colour.
GameEngine nineCardRow(GameEngine e) {
  GameCard g(GameCard proto) => e.cardById(proto.id)!;
  final deck = Deck.build(_seed);
  GameCard tal(TalismanType t, CardColor c) => deck.firstWhere(
      (d) => d.isTalisman && d.talisman == t && d.color == c);
  GameCard mag(MagicianKind k, CardColor c) =>
      deck.firstWhere((d) => !d.isTalisman && !d.isCloak && d.magician == k && d.color == c);
  GameCard cloakOf(CardColor c) =>
      deck.firstWhere((d) => d.isCloak && d.color == c);

  // Neighbour colours: S M T S M(hidden) M T M — the hidden card is exempt
  // (Cloaks hide colour), so no adjacent pair collides.
  final row = [
    g(tal(TalismanType.toad, CardColor.sun)), // #1
    g(tal(TalismanType.crystal, CardColor.moon)), // #2
    g(tal(TalismanType.mushroom, CardColor.star)), // #3
    g(tal(TalismanType.raven, CardColor.sun)), // #4
    g(tal(TalismanType.flower, CardColor.moon)), // #5, cloaked
    g(mag(MagicianKind.vanish, CardColor.moon)),
    g(mag(MagicianKind.summon, CardColor.star)),
    g(mag(MagicianKind.poison, CardColor.moon)),
  ];
  final theCloak = g(cloakOf(CardColor.sun));
  e.forest.rows
    ..clear()
    ..add(row.map(ForestSlot.new).toList());
  e.forest.cloakCard(row[4], theCloak);
  e.drawPile.clear();
  return e;
}

/// The second Flower (#5, Sun) — a duplicate of the hidden type. The row's
/// right end is the Poison (Moon), so the colour rule allows it, and 5 > 4.
GameCard secondFlower(GameEngine e) {
  final proto = Deck.build(_seed).firstWhere(
      (d) => d.isTalisman && d.talisman == TalismanType.flower &&
          d.color == CardColor.sun);
  return e.cardById(proto.id)!;
}

/// A Cloak that is not the one covering the Flower.
GameCard spareCloak(GameEngine e) {
  for (final p in Deck.build(_seed).where((d) => d.isCloak)) {
    final c = e.cardById(p.id)!;
    final used = e.forest.rows.any((r) => r.any((s) => identical(s.cloak, c)));
    if (!used) return c;
  }
  throw StateError('no spare cloak');
}

/// A Toad (Moon) that is not the one in the row (its type is visible there).
GameCard secondToad(GameEngine e) {
  final rowToad = e.forest.rows[0][0].card;
  for (final p
      in Deck.build(_seed)
          .where((d) =>
              d.isTalisman && d.talisman == TalismanType.toad &&
              d.color == CardColor.moon)) {
    final c = e.cardById(p.id)!;
    if (!identical(c, rowToad)) return c;
  }
  throw StateError('no spare toad');
}

/// Puts [card] on top of the draw pile and makes player 0 draw it.
void drawForZero(GameEngine e, GameCard card) {
  e.drawPile.add(card);
  e.current = 0;
  e.phase = Phase.drawing;
  e.pendingCard = null;
  e.pendingOptions = const [];
  e.apply(const DrawCmd());
}

void main() {
  group('engine: a full 9-card row still accepts cards', () {
    test('a spare Cloak offers one placement per visible Talisman', () {
      final e = nineCardRow(localSession().engine);
      drawForZero(e, spareCloak(e));
      expect(e.phase, Phase.placing);
      final cloaks = e.pendingOptions.whereType<CloakPlacement>().toList();
      final rows = e.pendingOptions.whereType<RowPlacement>().toList();
      // No row placement at all (Cloaks only cover Talismans).
      expect(rows, isEmpty);
      // The hidden Flower is not a target; the other four are.
      expect(cloaks.length, 4);
      final targets = {for (final o in cloaks) o.targetId};
      expect(targets, contains(e.forest.rows[0][0].card.id));
      expect(targets, isNot(contains(e.forest.rows[0][4].card.id)));
    });

    test('a duplicate of the hidden Talisman type can be played back in', () {
      final e = nineCardRow(localSession().engine);
      drawForZero(e, secondFlower(e));
      expect(e.phase, Phase.placing,
          reason: 'the hidden #5 "resets" the row (rulebook p. 14)');
      final opts = e.pendingOptions
          .whereType<RowPlacement>()
          .where((o) => o.row == 0)
          .toList();
      // Right end: 5 > 4 (Raven) and Sun != Star (Poison).
      expect(opts, contains(const RowPlacement(0, PlaceSide.right)));
      // Left end is blocked: 5 is not < 1 (the visible Toad).
      expect(opts, isNot(contains(const RowPlacement(0, PlaceSide.left))));
      // And the placement actually succeeds.
      e.apply(const PlaceCmd(RowPlacement(0, PlaceSide.right)));
      expect(e.forest.rows[0].length, 9);
      expect(e.phase, Phase.continuing);
    });

    test('a duplicate of a VISIBLE Talisman type cannot enter the row', () {
      final e = nineCardRow(localSession().engine);
      drawForZero(e, secondToad(e));
      final inRow0 = e.pendingOptions
          .whereType<RowPlacement>()
          .where((o) => o.row == 0)
          .toList();
      expect(inRow0, isEmpty,
          reason: 'the Toad is visible in the row: one of each per row');
      expect(e.phase, Phase.placing,
          reason: 'it can still open a new row');
    });
  });

  group('UI: tapping a full 9-card row adds the card', () {
    testWidgets('tapping the right end of the 9-card row places a duplicate',
        (tester) async {
      final s = localSession();
      final e = s.engine;
      nineCardRow(e);
      final flower = secondFlower(e);
      drawForZero(e, flower);
      s.start();
      await tester.pumpWidget(
        MaterialApp(
          theme: TNTTheme.build(),
          home: GameScreen(session: s, ownsSession: true, revealPauseMs: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The glowing right drop slot is offered for the full row.
      final drop = find.byKey(const ValueKey('tnt-drop-0R'));
      expect(drop, findsOneWidget,
          reason: 'a 9-card row still shows a placement target');
      await tester.tap(drop);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(e.phase, Phase.continuing);
      expect(e.forest.rows[0].length, 9,
          reason: 'the 10th visible card (9 slots + Cloak) was added');
      expect(e.forest.rows[0].last.card.id, flower.id);
    });
  });
}