import 'package:flutter/material.dart';

import 'name_prefs.dart';
import 'settings_prefs.dart';
import 'ui/app_state.dart';
import 'ui/screens/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TntApp.playerName.value = await loadSavedName();
  TntApp.playerName.addListener(
      () => saveName(TntApp.playerName.value));
  revealPauseMs.value = await loadRevealPauseMs();
  revealPauseMs.addListener(() => saveRevealPauseMs(revealPauseMs.value));
  runApp(const TntApp());
}

class TntApp extends StatelessWidget {
  const TntApp({super.key});

  static final ValueNotifier<String> playerName = ValueNotifier<String>('');

  @override
  Widget build(BuildContext context) {
    return AppName(
      notifier: playerName,
      child: MaterialApp(
        title: 'Toil & Troublez',
        debugShowCheckedModeBanner: false,
        theme: TNTTheme.build(),
        home: const HomeScreen(),
      ),
    );
  }
}