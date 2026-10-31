import 'package:flutter/material.dart';

import '../../game/cards.dart';
import '../../session/local_session.dart';
import '../../session/save.dart';
import '../app_state.dart';
import '../icons.dart';
import '../theme.dart';
import 'game.dart';
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
  GameSave? _save;
  DateTime? _lastSeenMtime;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refreshSave();
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  /// Re-reads the save file (on startup and whenever [mtime] changed).
  void _refreshSave() {
    GameSave.load().then((s) async {
      if (!mounted) return;
      setState(() => _save = s);
      _lastSeenMtime = s == null ? null : await GameSave.mtime();
    });
  }

  /// Home sits at the bottom of the stack, so a pop back to it re-runs
  /// [build]: diff the save file's mtime to catch games that ended since
  /// the last load.
  void _checkSaveChanged() {
    if (_checking) return;
    _checking = true;
    GameSave.mtime().then((mt) {
      _checking = false;
      if (!mounted) return;
      if (mt == null
          ? _save != null
          : (_save == null || mt != _lastSeenMtime)) {
        _refreshSave();
      }
    });
  }

  void _continue() {
    final save = _save;
    if (save == null) return;
    final session = LocalGameSession.fromSave(save, mySeat: save.mySeat);
    session.start();
    _go(GameScreen(session: session));
  }

  void _forget() {
    GameSave.clear();
    setState(() => _save = null);
  }

  String _saveSubtitle() {
    final names = (_save!.engineJson['players']! as List)
        .map((p) => (p as Map)['name'] as String)
        .join(' · ');
    final d = DateTime.now().difference(_save!.savedAt);
    final when = d.inMinutes < 1
        ? 'just now'
        : d.inMinutes < 60
            ? '${d.inMinutes} min ago'
            : d.inHours < 24
                ? '${d.inHours} h ago'
                : '${d.inDays} d ago';
    return '$names — saved $when';
  }

  void _go(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    _nameNotifier ??= AppName.of(context);
    _checkSaveChanged();
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
                if (_save != null) ...[
                  MenuTile(
                    icon: Icons.play_circle_outline,
                    title: 'Continue Last Game',
                    subtitle: _saveSubtitle(),
                    onTap: _continue,
                  ),
                  TextButton(
                    onPressed: _forget,
                    child: Text(
                      'Forget it',
                      style: TextStyle(
                        fontFamily: TNTTheme.fontUi,
                        fontSize: 12.5,
                        color: TNTTheme.goldSoft.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
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