import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../session/local_session.dart';
import '../app_state.dart';
import '../theme.dart';
import 'game.dart';

class PassAndPlayScreen extends StatefulWidget {
  const PassAndPlayScreen({super.key});

  @override
  State<PassAndPlayScreen> createState() => _PassAndPlayScreenState();
}

class _PassAndPlayScreenState extends State<PassAndPlayScreen> {
  int _seats = 2;
  late final List<TextEditingController> _names = List.generate(
      6, (i) => TextEditingController(text: 'Magician ${i + 1}'));

  @override
  void dispose() {
    for (final n in _names) {
      n.dispose();
    }
    super.dispose();
  }

  void _start() {
    final players = <Player>[
      for (var i = 0; i < _seats; i++)
        Player(
          id: i,
          name: _names[i].text.trim().isEmpty
              ? 'Magician ${i + 1}'
              : _names[i].text.trim(),
        ),
    ];
    final session = LocalGameSession(
      players: players,
      mySeat: -1,
      saveGame: true,
    );
    session.start();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TntScaffold(
      appBar: AppBar(title: const Text('Pass & Play')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gather the magicians',
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontTitle,
                    fontSize: 19,
                    color: TNTTheme.parchment,
                  ),
                ),
                const SizedBox(height: 20),
                CountStepper(
                  label: 'Magicians',
                  value: _seats,
                  min: 2,
                  max: 6,
                  onChange: (v) => setState(() => _seats = v),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _seats; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _names[i],
                        decoration: InputDecoration(
                          labelText: 'Magician ${i + 1}',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _start,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(190, 50),
                  ),
                  child: const Text(
                    'Pass the Device',
                    style: TextStyle(
                      fontFamily: TNTTheme.fontTitle,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'When a new turn begins, the device is passed to that '
                  'player, who taps to reveal their hand.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.white70,
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
