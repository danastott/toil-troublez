import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/game/bot.dart';
import 'package:toil_troublez/game/cards.dart';
import 'package:toil_troublez/game/engine.dart';
import 'package:toil_troublez/game/rules.dart';
import 'package:toil_troublez/session/local_session.dart';
import 'package:toil_troublez/ui/card_view.dart';
import 'package:toil_troublez/ui/screens/game.dart';
import 'package:toil_troublez/ui/theme.dart';

/// A solo game against two skilled bots with instant bot moves.
///
/// Seed 1: seat 0 moves first; its first draw is playable
/// (Poison, only a new-row placement is possible).
/// Seed 40: seat 0 moves first; its first draw busts.
GameSession solo(int seed) {
  final s = LocalGameSession(
    players: [
      Player(id: 0, name: 'You'),
      Player(id: 1, name: 'Bot 1', isBot: true, skill: BotSkill.skilled),
      Player(id: 2, name: 'Bot 2', isBot: true, skill: BotSkill.skilled),
    ],
    mySeat: 0,
    seed: seed,
    botDelayMs: 0,
  );
  s.start();
  return s;
}

Future<void> pumpGame(WidgetTester tester, GameSession session) async {
  // Portrait phone viewport: the whole forest (rows + new-row zone) is
  // visible without scrolling.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: TNTTheme.build(),
      home: GameScreen(session: session, ownsSession: true),
    ),
  );
  await tester.pumpAndSettle();
}

Finder handCard() => find.descendant(
      of: find.byKey(const ValueKey('tnt-hand')),
      matching: find.byType(CardView),
    );

/// Taps the first placement the engine offers for the card in hand.
Future<void> placeFirst(WidgetTester tester, GameSession session) async {
  final opt = session.engine.pendingOptions.first;
  late final Key key;
  if (opt is RowPlacement) {
    key = ValueKey(
        'tnt-drop-${opt.row}${opt.side == PlaceSide.left ? 'L' : 'R'}');
  } else if (opt is NewRowPlacement) {
    key = ValueKey('tnt-newrow-${session.engine.forest.rows.length}');
  } else if (opt is CloakPlacement) {
    key = ValueKey('tnt-tile-${opt.targetId}');
  } else {
    throw StateError('unknown placement ${opt.runtimeType}');
  }
  await tester.tap(find.byKey(key));
}

void main() {
  testWidgets('tapping the deck flips the card; dragging places it',
      (tester) async {
    final session = solo(1);
    await pumpGame(tester, session);

    // My turn: the face-down deck is active and the hand is empty. The
    // first draw is mandatory — there is no pass on the draw (rulebook
    // p. 5) — so no turn button is up yet.
    expect(find.text('Your turn: touch the deck to draw.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-deck')), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-hand-empty')), findsOneWidget);
    expect(find.text('Pass'), findsNothing);
    expect(find.text('End Turn'), findsNothing);

    // Tap the deck: the top card flips over into my hand.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    expect(handCard(), findsOneWidget);
    expect(find.text('BUST'), findsNothing);
    // A card outline target is shown for each empty row while a new row
    // may start.
    expect(find.byKey(const ValueKey('tnt-newrow-0')), findsOneWidget);

    // Drag the card from the hand onto the first empty row.
    final from = tester.getCenter(handCard());
    final to = tester.getCenter(find.byKey(const ValueKey('tnt-newrow-0')));
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();

    // The card was placed: the hand is empty again and I choose whether to
    // push my luck or end the turn.
    expect(session.engine.phase, Phase.continuing);
    expect(session.engine.forest.rows.length, 1);
    expect(find.byKey(const ValueKey('tnt-hand-empty')), findsOneWidget);
    expect(find.text('End Turn'), findsOneWidget);
  });

  testWidgets('a card that cannot be played busts: stamp and banner',
      (tester) async {
    final session = solo(40);
    await pumpGame(tester, session);

    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pump(); // Apply the draw.
    await tester.pump(const Duration(milliseconds: 600)); // Flip completes.

    // The busted card stays in the hand under a BUST stamp, the banner
    // explains it, and the turn passes on.
    expect(handCard(), findsOneWidget);
    expect(find.text('BUST'), findsOneWidget);
    expect(find.textContaining('Busted!'), findsOneWidget);

    // After a moment the stamp lifts and the hand empties out.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    expect(find.text('BUST'), findsNothing);
    // (Seed 40 busts on a Cloak, which the engine narrates as a cloak
    // discard; an unplayable talisman would be a bust event.)
    expect(session.engine.events
            .any((ev) =>
                ev.player == 0 &&
                (ev.type == EventType.bust ||
                    (ev.type == EventType.cloak &&
                        ev.detail == 'discarded'))),
        isTrue);
  });

  testWidgets('a second draw can be dropped onto an existing row end',
      (tester) async {
    final session = solo(353);
    await pumpGame(tester, session);

    // First draw: a Flower goes into a new row.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    var from = tester.getCenter(handCard());
    var to = tester.getCenter(find.byKey(const ValueKey('tnt-newrow-0')));
    var g = await tester.startGesture(from);
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pumpAndSettle();
    expect(session.engine.phase, Phase.continuing);

    // Push my luck: a Summon flips into the hand, and both ends of row 0
    // show as card-outline drop targets.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    expect(session.engine.pendingCard, isNotNull);
    expect(find.byKey(const ValueKey('tnt-drop-0L')), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-drop-0R')), findsOneWidget);

    from = tester.getCenter(handCard());
    to = tester.getCenter(find.byKey(const ValueKey('tnt-drop-0L')));
    g = await tester.startGesture(from);
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pumpAndSettle();

    // The Summon landed at the left end of row 0; my turn continues.
    final row0 = session.engine.forest.rows[0];
    expect(row0.length, 2);
    expect(row0.first.card.magician, MagicianKind.summon);
    expect(row0.last.card.talisman, TalismanType.flower);
    expect(session.engine.phase, Phase.continuing);
    expect(find.byKey(const ValueKey('tnt-hand-empty')), findsOneWidget);
  });

  testWidgets('a drawn Cloak covers a glowing talisman with a tap',
      (tester) async {
    final session = solo(13);
    await pumpGame(tester, session);

    // First draw: a Mushroom goes into a new row.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    final from = tester.getCenter(handCard());
    final to = tester.getCenter(find.byKey(const ValueKey('tnt-newrow-0')));
    final g = await tester.startGesture(from);
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pumpAndSettle();
    expect(session.engine.phase, Phase.continuing);

    // Push my luck: a Cloak. The row-end Talisman is the only cloak
    // target and glows.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    expect(session.engine.pendingCard?.isCloak, isTrue);
    final target = find.byKey(const ValueKey('tnt-tile-46'));
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(session.engine.forest.rows[0].first.isCloaked, isTrue);
    expect(session.engine.phase, Phase.continuing);

    // Still my turn: end it and let the bots play on.
    await tester.tap(find.text('End Turn'));
    await tester.pumpAndSettle();
    expect(session.engine.over || session.engine.acting == 0, isTrue);
  });

  testWidgets('a bust sequence calls out PICK A CARD when my pick comes up',
      (tester) async {
    final session = solo(3);
    await pumpGame(tester, session);
    final callout = find.text('PICK A CARD — tap a glowing card');

    // Seed 3: I keep drawing and bust on the seventh draw.
    for (var i = 0; i < 10; i++) {
      final phase = session.engine.phase;
      if (phase != Phase.drawing && phase != Phase.continuing) break;
      await tester.tap(find.byKey(const ValueKey('tnt-deck')));
      await tester.pumpAndSettle();
      if (session.engine.phase == Phase.picking) break; // busted
      await placeFirst(tester, session);
      await tester.pumpAndSettle();
    }

    // The bust ended the turn. The bots may still be picking, or my pick may
    // already be up; the callout must only show once it is my turn.
    expect(session.engine.phase, Phase.picking);
    if (session.engine.acting != 0) {
      expect(callout, findsNothing);
    }

    // The bots pick up and play on; a picked-up Master Magician leaves a
    // card only I can take. The callout appears under the forest rows.
    await tester.pumpAndSettle();
    expect(session.engine.phase, Phase.picking);
    expect(session.engine.acting, 0);
    expect(callout, findsOneWidget);

    // Take the glowing end card the engine offers. A picked-up Master
    // Magician can extend the chain so it may land on me again; keep
    // taking until it does not.
    var pickGuard = 0;
    while (session.engine.phase == Phase.picking &&
        session.engine.acting == 0 &&
        pickGuard++ < 20) {
      final pick = session.engine.pendingPicks.first;
      final row = session.engine.forest.rows[pick.row];
      final id =
          row.elementAt(pick.side == PlaceSide.left ? 0 : row.length - 1).card.id;
      await tester.tap(find.byKey(ValueKey('tnt-tile-$id')));
      await tester.pumpAndSettle();
    }
    expect(callout, findsNothing);

    // Finish the game, auto-answering any decision of mine (a picked-up
    // Master Magician may need one) so the engine never stalls on me.
    final answers = Random();
    var guard = 0;
    while (!session.engine.over && guard++ < 300) {
      if (session.engine.acting != 0) {
        await tester.pumpAndSettle();
        continue;
      }
      final cmd = Bot.decide(session.engine, 0, BotSkill.skilled, answers);
      session.submit(cmd);
      await tester.pumpAndSettle();
    }
    expect(session.engine.over || session.engine.acting != 0, isTrue);
  });
}
