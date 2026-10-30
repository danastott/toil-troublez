import 'package:flutter/material.dart';

import '../../game/cards.dart';
import '../app_state.dart';
import '../icons.dart';
import '../theme.dart';
import 'host.dart';
import 'join.dart';
import 'pass_play.dart';
import 'rules.dart';
import 'solo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController? _name;
  ValueNotifier<String>? _nameNotifier;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  void _go(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    _nameNotifier ??= AppName.of(context);
    _name ??= TextEditingController(text: _nameNotifier!.value);
    return TntScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final t in TalismanType.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: TalismanIcon(
                          type: t,
                          size: 24,
                          color: TNTTheme.goldSoft.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Toil & Troublez',
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontDisplay,
                    fontSize: 44,
                    color: TNTTheme.goldSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The witching hour is nigh. Seek the Talismans of the '
                  'Enchanted Forest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontStyle: FontStyle.italic,
                    fontSize: 13.5,
                    color: TNTTheme.parchment.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _name!,
                    onChanged: (v) => _nameNotifier!.value = v.trim(),
                    style: const TextStyle(
                      fontFamily: TNTTheme.fontUi,
                      fontSize: 16,
                      color: TNTTheme.goldSoft,
                    ),
                    cursorColor: TNTTheme.goldSoft,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      hintText: 'A wandering magician',
                      hintStyle: TextStyle(
                        fontFamily: TNTTheme.fontUi,
                        color: TNTTheme.goldSoft,
                      ),
                      prefixIcon:
                          Icon(Icons.auto_awesome, color: TNTTheme.goldSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                MenuTile(
                  icon: Icons.person,
                  title: 'Single Player',
                  subtitle: 'Face 1–5 bots — choose their skill',
                  onTap: () => _go(const SoloScreen()),
                ),
                MenuTile(
                  icon: Icons.swap_horiz,
                  title: 'Pass & Play',
                  subtitle: '2–6 magicians around one device',
                  onTap: () => _go(const PassAndPlayScreen()),
                ),
                MenuTile(
                  icon: Icons.router,
                  title: 'Host a Game',
                  subtitle: 'Open a table for friends on this network',
                  onTap: () => _go(const HostScreen()),
                ),
                MenuTile(
                  icon: Icons.wifi,
                  title: 'Join a Game',
                  subtitle: 'Find a table on this network',
                  onTap: () => _go(const JoinScreen()),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _go(const RulesScreen()),
                  child: Text(
                    'How to play',
                    style: TextStyle(
                      fontFamily: TNTTheme.fontUi,
                      fontSize: 13,
                      color:
                          TNTTheme.goldSoft.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}