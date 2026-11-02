import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toil_troublez/settings_prefs.dart';

void main() {
  test('an empty store yields the default reveal pause', () async {
    SharedPreferences.setMockInitialValues(const {});
    expect(await loadRevealPauseMs(), defaultRevealPauseMs);
    expect(defaultRevealPauseMs, 250);
  });

  test('a saved reveal pause is read back', () async {
    SharedPreferences.setMockInitialValues(const {});
    await saveRevealPauseMs(750);
    expect(await loadRevealPauseMs(), 750);
  });

  test('an unsupported stored value falls back to the default', () async {
    SharedPreferences.setMockInitialValues({revealPauseKey: 42});
    expect(await loadRevealPauseMs(), defaultRevealPauseMs);
  });

  test('pause labels read in seconds', () {
    expect(revealPauseOptions.map(revealPauseLabel),
        ['0.1s', '0.25s', '0.5s', '0.75s', '1s']);
  });
}
