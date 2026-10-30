import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loaded automatically before every test file.
///
/// Widget tests render with the Ahem placeholder font (squares, exactly one
/// em per character) unless the app's fonts are registered. Load them up
/// front in every suite so text metrics are the real ones and layout
/// assertions are deterministic.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    // rootBundle (and asset loading in general) needs the binding, even in
    // pure-Dart suites that never pump a widget.
    TestWidgetsFlutterBinding.ensureInitialized();
    final loaders = <FontLoader>[
      FontLoader('Rye')
        ..addFont(rootBundle.load('assets/fonts/Rye-Regular.ttf')),
      FontLoader('Cinzel Decorative')
        ..addFont(rootBundle.load('assets/fonts/CinzelDecorative-Bold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/CinzelDecorative-Black.ttf')),
      FontLoader('Fraunces')
        ..addFont(rootBundle.load('assets/fonts/Fraunces-400.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Fraunces-600.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Fraunces-700.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Fraunces-900.ttf')),
      FontLoader('Nunito Sans')
        ..addFont(rootBundle.load('assets/fonts/NunitoSans-400.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NunitoSans-600.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NunitoSans-700.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NunitoSans-800.ttf')),
    ];
    for (final loader in loaders) {
      await loader.load();
    }
  });
  await testMain();
}
