import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/ui/icons.dart';
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

Future<void> pumpGame(
  WidgetTester tester,
  GameSession session, {
  double textScale = 1.0,
}) async {
  // Portrait phone viewport: the whole forest (rows + new-row zone) is
  // visible without scrolling.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  if (textScale != 1.0) {
    tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: TNTTheme.build(),
      home: GameScreen(session: session, ownsSession: true, revealPauseMs: 0),
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

  testWidgets('a drawn card flies from the deck into the face-up hand',
      (tester) async {
    final session = solo(1);
    await pumpGame(tester, session);

    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pump();

    // A draw animation is running from the deck's top card to the hand.
    final card = session.engine.pendingCard;
    expect(card, isNotNull);
    final flight = find.byKey(ValueKey('draw-${card!.id}'));
    expect(flight, findsOneWidget);

    // It lands face-up in the hand and the overlay clears.
    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(handCard(), findsOneWidget);
  });

  testWidgets('a card that cannot be played busts: stamp and banner',
      (tester) async {
    // Pump under a large device text scale: the stamp must stay on one
    // line even when the system scales text up.
    final session = solo(40);
    await pumpGame(tester, session, textScale: 1.3);

    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pump(); // Apply the draw.
    await tester.pump(const Duration(milliseconds: 600)); // Flip completes.

    // The busted card stays in the hand under a BUST stamp, the banner
    // explains it, and the turn passes on.
    expect(handCard(), findsOneWidget);
    expect(find.text('BUST'), findsOneWidget);
    expect(find.textContaining('Busted!'), findsOneWidget);
    // The stamp (padding 7 per side) fits the 78px card on one line,
    // even under the enlarged text scale.
    final stamp = tester.renderObject<RenderParagraph>(find.text('BUST'));
    final painter = TextPainter(
      text: stamp.text,
      textDirection: TextDirection.ltr,
      textScaler: stamp.textScaler,
    );
    painter.layout(maxWidth: 78.0 - 14.0);
    expect(painter.computeLineMetrics().length, 1);

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

  testWidgets('tapping a tree target flies the hand card into the forest',
      (tester) async {
    final session = solo(1);
    await pumpGame(tester, session);

    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    final card = session.engine.pendingCard!;

    // Tapping the glowing new-row outline plays the card there, and it
    // flies from the hand instead of teleporting.
    await tester.tap(find.byKey(const ValueKey('tnt-newrow-0')));
    await tester.pump();
    // The flight is promoted in the post-frame capture, which opens one
    // more frame for the overlay to build into.
    await tester.pump();

    final flight = find.byKey(ValueKey('fly${card.id}'));
    expect(flight, findsOneWidget);
    expect(session.engine.forest.rows.length, 1);

    await tester.pumpAndSettle();
    expect(flight, findsNothing);
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
    // A drag already moved the card on screen: no fly-in follows.
    await tester.pump();
    await tester.pump();
    final placed = session.engine.forest.rows[0].first.card;
    expect(find.byKey(ValueKey('fly${placed.id}')), findsNothing);
    await tester.pumpAndSettle();

    // The Summon landed at the left end of row 0; my turn continues.
    final row0 = session.engine.forest.rows[0];
    expect(row0.length, 2);
    expect(row0.first.card.magician, MagicianKind.summon);
    expect(row0.last.card.talisman, TalismanType.flower);
    expect(session.engine.phase, Phase.continuing);
    expect(find.byKey(const ValueKey('tnt-hand-empty')), findsOneWidget);
  });

  testWidgets('tapping a row-end drop slot flies the hand card in',
      (tester) async {
    final session = solo(353);
    await pumpGame(tester, session);

    // First draw: a Flower goes into a new row.
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

    // Push my luck: a Summon flips into the hand and both ends of row 0
    // show dashed drop slots.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    final card = session.engine.pendingCard!;
    expect(find.byKey(const ValueKey('tnt-drop-0L')), findsOneWidget);

    // Tapping the dashed slot plays the card there — and, like a tap on
    // any other tree target, the card flies in from the hand instead of
    // popping into place.
    await tester.tap(find.byKey(const ValueKey('tnt-drop-0L')));
    await tester.pump();
    await tester.pump(); // Post-frame capture promotes the flight.
    final flight = find.byKey(ValueKey('fly${card.id}'));
    expect(flight, findsOneWidget);

    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(session.engine.forest.rows[0].length, 2);
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

  testWidgets('a trove fans left to right by number, duplicates stacked',
      (tester) async {
    final session = solo(1);
    // Stuff a known hand into my trove: two Toads (#1), a Crystal (#2),
    // two Mushrooms (#3) and a Flower (#5), pulled out of the draw pile
    // by id so the game cannot also draw them.
    const ids = [0, 1, 12, 24, 25, 48];
    session.engine.drawPile.removeWhere((c) => ids.contains(c.id));
    for (final id in ids) {
      session.engine.players[0].trove.add(session.engine.cardById(id)!);
    }
    await pumpGame(tester, session);

    final troves = find.byKey(const ValueKey('tnt-troves'));
    expect(troves, findsOneWidget);
    final rects = <int, Rect>{};
    for (final el in find
        .descendant(of: troves, matching: find.byType(CardView))
        .evaluate()) {
      rects[(el.widget as CardView).card.id] =
          tester.getRect(find.byWidget(el.widget));
    }
    expect(rects, hasLength(6));
    // The numbers spread left to right: 1, 2, 3, then 5, and the fan is
    // wider than a single card.
    expect(rects[0]!.left, lessThan(rects[12]!.left));
    expect(rects[12]!.left, lessThan(rects[24]!.left));
    expect(rects[24]!.left, lessThan(rects[48]!.left));
    expect(rects[48]!.left - rects[0]!.left, greaterThan(rects[0]!.width));
    // Duplicates stack in place: the same column, with the later-picked
    // card fully visible on top and the older one peeking beneath it.
    expect(rects[1]!.left, moreOrLessEquals(rects[0]!.left, epsilon: 1));
    expect(rects[1]!.top, lessThan(rects[0]!.top));
    expect(rects[25]!.left, moreOrLessEquals(rects[24]!.left, epsilon: 1));
    expect(rects[25]!.top, lessThan(rects[24]!.top));
  });

  testWidgets('four players sit in two rows of trove boxes',
      (tester) async {
    final s = LocalGameSession(
      players: [
        Player(id: 0, name: 'You'),
        for (var i = 1; i < 4; i++)
          Player(id: i, name: 'Bot $i', isBot: true, skill: BotSkill.skilled),
      ],
      mySeat: 0,
      seed: 5,
      botDelayMs: 0,
    );
    s.start();
    await pumpGame(tester, s);
    Finder box(String name) => find.descendant(
        of: find.byKey(const ValueKey('tnt-troves')),
        matching: find.text(name));
    // Players 0 and 1 share the top row; 2 and 3 sit below them in the
    // second row, which keeps the same column widths.
    final top = tester.getCenter(box('You'));
    final beside = tester.getCenter(box('Bot 1'));
    final below = tester.getCenter(box('Bot 2'));
    expect(beside.dy, closeTo(top.dy, 2));
    expect(beside.dx, greaterThan(top.dx));
    expect(below.dy, greaterThan(top.dy + 20));
    expect(below.dx, closeTo(top.dx, 2));
  });

  testWidgets('a Cloak card wears a dark face and a plain name band',
      (tester) async {
    final cloak = Deck.build(0).firstWhere((c) => c.isCloak);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: CardView(card: cloak, width: 120)),
      ),
    );
    await tester.pump();
    expect(find.text('CLOAK'), findsOneWidget);
    expect(find.byType(ColorGlyph), findsNothing);
  });

  testWidgets('the log icon opens a dialog of the game transactions',
      (tester) async {
    final s = solo(1);
    await pumpGame(tester, s);
    // Draw and place my first card, then end the turn. After the pass the
    // engine waits on me to collect a row (none is complete yet), so the
    // history holds exactly my three moves: draw, place, pass.
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    await placeFirst(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Turn'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tnt-log')));
    await tester.pump();
    expect(find.text('Game Log'), findsOneWidget);

    // Seed 1: my first draw is a Poison, placed in a fresh row, then I
    // end the turn. Every transaction shows up in the log.
    expect(find.text('You draws a Poison'), findsOneWidget);
    expect(find.text('You opens a new row with a Poison'), findsOneWidget);
    expect(find.text('You passes'), findsOneWidget);

    // Newest first: the pass sits above the place, the place above the
    // draw.
    final passTop =
        tester.getTopLeft(find.text('You passes')).dy;
    final placeTop = tester
        .getTopLeft(find.text('You opens a new row with a Poison'))
        .dy;
    final drawTop = tester.getTopLeft(find.text('You draws a Poison')).dy;
    expect(passTop, lessThan(placeTop));
    expect(placeTop, lessThan(drawTop));
  });

  testWidgets('the log dialog copies and shares the full log',
      (tester) async {
    final s = solo(1);
    await pumpGame(tester, s);
    await tester.tap(find.byKey(const ValueKey('tnt-deck')));
    await tester.pumpAndSettle();
    await placeFirst(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Turn'));
    await tester.pumpAndSettle();

    // Capture clipboard writes and share-sheet calls.
    String? copied;
    String? shared;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method == 'share') {
        final args = call.arguments as Map<Object?, Object?>;
        shared = '${args['title']}\n${args['text']}';
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });

    await tester.tap(find.byKey(const ValueKey('tnt-log')));
    await tester.pump();

    await tester.tap(find.byTooltip('Copy log'));
    await tester.pump();
    expect(copied, isNotNull);
    expect(copied, startsWith('Toil & Troublez game log'));
    expect(copied, contains('Seed 1'));
    expect(copied, contains('Players: You, Bot 1, Bot 2'));
    // Numbered chronologically: draw (1) before pass (3).
    final lines = copied!.split('\n');
    expect(
        lines.indexOf('3  You passes'),
        greaterThan(lines.indexOf('1  You draws a Poison')));

    await tester.tap(find.byTooltip('Share log'));
    await tester.pumpAndSettle();
    expect(shared, isNotNull);
    expect(shared, contains('Toil & Troublez game log'));
    expect(shared, contains('Seed 1'));
  });
}
