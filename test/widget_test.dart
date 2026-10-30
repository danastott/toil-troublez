import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:toil_troublez/main.dart';

void main() {
  testWidgets('home screen shows all four modes and the rules link',
      (tester) async {
    await tester.pumpWidget(const TntApp());
    await tester.pump();

    expect(find.text('Single Player'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);
    expect(find.text('Host a Game'), findsOneWidget);
    expect(find.text('Join a Game'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);

    // Rules page opens and shows sections.
    await tester.ensureVisible(find.text('How to play'));
    await tester.tap(find.text('How to play'));
    await tester.pumpAndSettle();
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('SCORING'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
  });

  testWidgets('solo: begin the quest renders the game board', (tester) async {
    await tester.pumpWidget(const TntApp());
    await tester.pump();

    await tester.tap(find.text('Single Player'));
    await tester.pumpAndSettle();
    expect(find.text('Begin the Quest'), findsOneWidget);

    await tester.tap(find.text('Begin the Quest'));
    await tester.pumpAndSettle();

    // The board is up: forest, troves and the prompt banner, with one
    // panel per player. The exact prompt text depends on the random
    // opening hand, so assert the structure instead.
    expect(find.byKey(const ValueKey('tnt-forest')), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-troves')), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-prompt')), findsOneWidget);
    expect(find.text('Player'), findsWidgets);
    // Solo's default is two Skilled bots; names follow the skill's initial.
    expect(find.text('Stella'), findsWidgets);
    expect(find.text('Soren'), findsWidgets);
  });

  testWidgets('pass & play: start, veil, reveal', (tester) async {
    await tester.pumpWidget(const TntApp());
    await tester.pump();

    await tester.tap(find.text('Pass & Play'));
    await tester.pumpAndSettle();
    expect(find.text('Pass the Device'), findsOneWidget);

    await tester.tap(find.text('Pass the Device'));
    await tester.pumpAndSettle();

    // The pass veil hides the board until the acting player reveals.
    expect(find.text('The Witching Hour Passes'), findsOneWidget);
    await tester.tap(find.textContaining('reveal'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tnt-forest')), findsOneWidget);
    expect(find.byKey(const ValueKey('tnt-troves')), findsOneWidget);
  });
}
