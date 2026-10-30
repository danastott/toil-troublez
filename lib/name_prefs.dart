import 'package:shared_preferences/shared_preferences.dart';

/// Persistence key for the player name, kept across app launches.
const String nameKey = 'playerName';

/// The name saved in a previous launch, or '' if none.
Future<String> loadSavedName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(nameKey) ?? '';
}

/// Remember the player name for the next launch.
Future<void> saveName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(nameKey, name);
}
