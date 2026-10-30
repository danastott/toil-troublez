import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/names.dart';
import '../../session/local_session.dart';
import '../app_state.dart';
import '../theme.dart';
import 'game.dart';

class SoloScreen extends StatefulWidget {
  const SoloScreen({super.key});

  @override
  State<SoloScreen> createState() => _SoloScreenState();
}

class _SoloScreenState extends State<SoloScreen> {
  BotSkill _skill = BotSkill.skilled;
  int _bots = 2;

  List<Player> _players() {
    final name = AppName.read(context);
    final myName = name.isEmpty ? 'Player' : name;
    final taken = <String>{myName};
    return [
      Player(id: 0, name: myName),
      for (var i = 1; i <= _bots; i++)
        _bot(i, taken),
    ];
  }

  Player _bot(int i, Set<String> taken) {
    final name = BotNames.pick(_skill, i, taken);
    taken.add(name);
    return Player(id: i, name: name, isBot: true, skill: _skill);
  }

  void _start() {
    final session = LocalGameSession(players: _players(), mySeat: 0);
    session.start();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TntScaffold(
      appBar: AppBar(title: const Text('Single Player')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Who will oppose you?',
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontTitle,
                    fontSize: 19,
                    color: TNTTheme.parchment,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (final s in BotSkill.values)
                      SkillTile(
                        skill: s,
                        selected: s == _skill,
                        onTap: () => setState(() => _skill = s),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                CountStepper(
                  label: 'Bots at the table',
                  value: _bots,
                  min: 1,
                  max: 5,
                  onChange: (v) => setState(() => _bots = v),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_bots ${_bots == 1 ? 'bot' : 'bots'} will circle the '
                  'forest with you, playing as ${_skill.name} magicians.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontStyle: FontStyle.italic,
                    fontSize: 12.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _start,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(190, 50),
                  ),
                  child: const Text(
                    'Begin the Quest',
                    style: TextStyle(
                      fontFamily: TNTTheme.fontTitle,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
