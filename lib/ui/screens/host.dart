import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../net/host_lobby.dart';
import '../../net/lobby.dart';
import '../../session/local_session.dart';
import '../app_state.dart';
import '../theme.dart';
import 'game.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late final HostLobby _host;
  bool _pushedGame = false;
  GameSession? _lastTable;

  @override
  void initState() {
    super.initState();
    final name = AppName.read(context);
    _host = HostLobby(hostName: name.isEmpty ? 'Host' : name);
    _host.addListener(_onHost);
    _host.start();
  }

  void _onHost() {
    final table = _host.table;
    if (table != null) {
      if (table != _lastTable) {
        _lastTable = table;
        table.addListener(_onHost);
      }
      if (!_pushedGame && mounted) {
        _pushedGame = true;
        final t = table;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameScreen(session: t, ownsSession: false),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _host.removeListener(_onHost);
    _lastTable?.removeListener(_onHost);
    unawaited(_host.leave());
    super.dispose();
  }

  void _leave() {
    unawaited(_host.leave());
    if (mounted) Navigator.of(context).pop();
  }

  Widget _seatRow(LobbySeat s, int number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Material(
        color: TNTTheme.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: s.isHost
                  ? TNTTheme.gold.withValues(alpha: 0.7)
                  : TNTTheme.goldSoft.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor:
                    TNTTheme.gold.withValues(alpha: s.isBot ? 0.3 : 0.6),
                child: Text(
                  '$number',
                  style: const TextStyle(
                      fontFamily: TNTTheme.fontDisplay,
                      fontSize: 12,
                      color: TNTTheme.ink),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontUi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TNTTheme.parchment,
                  ),
                ),
              ),
              if (s.isBot) ...[
                for (final sk in BotSkill.values)
                  GestureDetector(
                    onTap: () => _host.setBotSkill(s.id, sk),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: s.skill == sk
                            ? TNTTheme.gold.withValues(alpha: 0.35)
                            : TNTTheme.deepTealDark.withValues(alpha: 0.6),
                        border: Border.all(
                            color: s.skill == sk
                                ? TNTTheme.gold
                                : TNTTheme.goldSoft.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        sk.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontFamily: TNTTheme.fontUi,
                            fontSize: 11,
                            color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.person_remove, size: 18),
                  color: Colors.white54,
                  onPressed: () => _host.removeSeat(s.id),
                ),
              ] else if (s.isHost)
                const Text(
                  'you',
                  style: TextStyle(
                      fontFamily: TNTTheme.fontSerif,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lobby = _host.lobby;
    final table = _host.table;
    return TntScaffold(
      appBar: AppBar(title: const Text('Host a Game')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_host.errorMessage != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _host.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: TNTTheme.fontUi,
                            fontSize: 13,
                            color: Colors.redAccent),
                      ),
                    ),
                  ),
                if (lobby == null) ...[
                  const SizedBox(height: 26),
                  const CircularProgressIndicator(color: TNTTheme.goldSoft),
                  const SizedBox(height: 18),
                  Text(
                    'Opening the table…',
                    style: const TextStyle(
                      fontFamily: TNTTheme.fontTitle,
                      fontSize: 16,
                      color: TNTTheme.parchment,
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Players at the table',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: TNTTheme.fontTitle,
                            fontSize: 17,
                            color: TNTTheme.parchment,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: TNTTheme.gold.withValues(alpha: 0.2),
                          border: Border.all(
                              color: TNTTheme.goldSoft.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '${lobby.seats.length}/${LobbyInfo.maxPlayers}',
                          style: const TextStyle(
                            fontFamily: TNTTheme.fontDisplay,
                            fontSize: 14,
                            color: TNTTheme.goldSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < lobby.seats.length; i++)
                    _seatRow(lobby.seats[i], i + 1),
                  if (lobby.seats.length < LobbyInfo.maxPlayers)
                    TextButton.icon(
                      onPressed: () => _host.addBot(),
                      icon: const Icon(Icons.smart_toy, size: 18),
                      label: const Text('Add a bot',
                          style: TextStyle(fontFamily: TNTTheme.fontUi)),
                    ),
                  const SizedBox(height: 16),
                  if (!lobby.started)
                    ElevatedButton(
                      onPressed: lobby.canStart ? () => _host.startGame() : null,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(190, 48)),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(
                          fontFamily: TNTTheme.fontTitle,
                          fontSize: 15,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else
                    Text(
                      table == null || !table.engine.over
                          ? 'The game is in progress on the game screen.'
                          : 'The quest has ended.',
                      style: const TextStyle(
                        fontFamily: TNTTheme.fontSerif,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _leave,
                    child: const Text(
                      'Leave Table',
                      style: TextStyle(
                        fontFamily: TNTTheme.fontUi,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Friends on this network: open Join a Game and pick '
                    '${lobby.hostName} (port ${lobby.port}).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TNTTheme.fontSerif,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}