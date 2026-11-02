import 'dart:async';

import 'package:flutter/material.dart';
import '../../game/cards.dart';
import '../../net/client_connection.dart';
import '../../net/discovery.dart';
import '../../session/local_session.dart';
import '../app_state.dart';
import '../icons.dart';
import '../theme.dart';
import 'game.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TableDiscovery _scan;
  ClientConnection? _conn;
  StreamSubscription<DiscoveredTable>? _sub;
  bool _pushedGame = false;
  GameSession? _lastTable;

  @override
  void initState() {
    super.initState();
    _scan = TableDiscovery();
    _scan.changed.listen((_) => setState(() {}));
    unawaited(_scan.start());
  }

  void _onConn() {
    final conn = _conn;
    final table = conn?.table;
    if (table != null) {
      if (table != _lastTable) {
        _lastTable = table;
        table.addListener(_onConn);
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

  Future<void> _join(DiscoveredTable t) async {
    final name = AppName.read(context);
    final conn = ClientConnection(
      address: t.address,
      port: t.port,
      myName: name.isEmpty ? 'Player' : name,
    );
    _conn = conn;
    conn.addListener(_onConn);
    setState(() {});
    await conn.connect();
  }

  void _leave() {
    final c = _conn;
    _conn = null;
    _lastTable?.removeListener(_onConn);
    _lastTable = null;
    _pushedGame = false;
    unawaited(c?.leave());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_scan.stop());
    _lastTable?.removeListener(_onConn);
    _conn?.removeListener(_onConn);
    unawaited(_conn?.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tables = _scan.tables;
    final conn = _conn;
    return TntScaffold(
      appBar: AppBar(title: const Text('Join a Game')),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(
                  conn == null
                      ? 'Scanning the network for open tables…'
                      : 'Connected to ${conn.lobby?.hostName ?? 'the host'}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (conn != null && conn.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    conn.errorMessage!,
                    style: const TextStyle(
                        fontFamily: TNTTheme.fontUi,
                        fontSize: 13,
                        color: Colors.redAccent),
                  ),
                ),
              Expanded(
                child: tables.isEmpty && conn == null
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: TNTTheme.goldSoft))
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 22),
                        itemCount: tables.length,
                        itemBuilder: (_, i) {
                          final t = tables[i];
                          final busy = conn?.isBusy ?? false;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 5),
                            child: Material(
                              color: TNTTheme.ink.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: t.started || busy || conn != null
                                    ? null
                                    : () => _join(t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: TNTTheme.goldSoft
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const ColorGlyph(
                                          color: CardColor.star,
                                          size: 15,
                                          tint: TNTTheme.goldSoft),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          t.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: TNTTheme.fontTitle,
                                            fontSize: 14,
                                            color: TNTTheme.parchment,
                                          ),
                                        ),
                                      ),
                                      if (t.started)
                                        const Text(
                                          'in game',
                                          style: TextStyle(
                                            fontFamily: TNTTheme.fontSerif,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                            color: Colors.white54,
                                          ),
                                        )
                                      else
                                        Text(
                                          '${t.players} seated',
                                          style: const TextStyle(
                                              fontFamily: TNTTheme.fontUi,
                                              fontSize: 12,
                                              color: Colors.white70),
                                        ),
                                      const SizedBox(width: 10),
                                      if (!t.started &&
                                          (conn == null || !busy))
                                        const Icon(Icons.play_arrow,
                                            size: 22, color: TNTTheme.gold),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              if (conn != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextButton(
                    onPressed: _leave,
                    child: const Text(
                      'Disconnect',
                      style: TextStyle(
                        fontFamily: TNTTheme.fontUi,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'A host opens its table with Host a Game.',
                    style: TextStyle(
                      fontFamily: TNTTheme.fontSerif,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}