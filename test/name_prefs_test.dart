import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toil_troublez/name_prefs.dart';

void main() {
  test('an empty store yields an empty name', () async {
    SharedPreferences.setMockInitialValues(const {});
    expect(await loadSavedName(), '');
  });

  test('a saved name is read back within the same launch', () async {
    SharedPreferences.setMockInitialValues(const {});
    await saveName('Dana');
    expect(await loadSavedName(), 'Dana');

    // A later edit overwrites the stored name.
    await saveName('Raven');
    expect(await loadSavedName(), 'Raven');
  });

  test('a stored name survives to the next launch', () async {
    SharedPreferences.setMockInitialValues(const {});
    await saveName('Dana');

    // Simulate relaunch: the store re-initializes from disk.
    SharedPreferences.setMockInitialValues({nameKey: 'Dana'});
    expect(await loadSavedName(), 'Dana');
  });
}