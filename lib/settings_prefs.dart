import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence key for the card reveal pause.
const String revealPauseKey = 'revealPauseMs';

/// The reveal pauses offered on the settings screen, in milliseconds.
const List<int> revealPauseOptions = [100, 250, 500, 750, 1000];

/// The reveal pause used until (or unless) a player picks another.
const int defaultRevealPauseMs = 250;

/// How long a drawn card is shown face-up before it is played into the
/// forest. App-wide, edited on the settings screen and read by the game
/// screen.
final ValueNotifier<int> revealPauseMs = ValueNotifier<int>(
  defaultRevealPauseMs,
);

/// A short label for a pause value, e.g. 250 -> '0.25s'.
String revealPauseLabel(int ms) {
  if (ms % 1000 == 0) return '${ms ~/ 1000}s';
  final text = (ms / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return '${text}s';
}

/// The reveal pause saved in a previous launch, or the default.
Future<int> loadRevealPauseMs() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt(revealPauseKey);
  return saved != null && revealPauseOptions.contains(saved)
      ? saved
      : defaultRevealPauseMs;
}

/// Remember the reveal pause for the next launch.
Future<void> saveRevealPauseMs(int ms) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(revealPauseKey, ms);
}
