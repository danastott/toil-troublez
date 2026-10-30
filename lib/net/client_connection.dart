import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../game/commands.dart';
import '../game/engine.dart';
import '../session/local_session.dart';
import 'discovery.dart';
import 'lobby.dart';

/// A player's seat in a remote table, from the client's point of view.
class ClientGameSession extends GameSession {
  ClientGameSession({
    required this.engine,
    required this.mySeat,
    required this.sendCommand,
  });

  @override
  final GameEngine engine;

  @override
  final int mySeat;

  /// Where to ship commands (usually the open client connection).
  final void Function(GameCommand cmd) sendCommand;

  String? _error;
  bool _disposed = false;

  @override
  bool get isAuthority => false;

  @override
  bool get canAct => !engine.over && engine.acting == mySeat;

  @override
  String? get errorMessage => _error;

  @override
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  bool get connected => true;

  /// The client never applies commands itself; it sends them to the host,
  /// which validates and broadcasts them.
  @override
  void submit(GameCommand cmd) {
    if (_disposed || engine.over) return;
    if (!canAct) {
      _error = 'Not your turn yet.';
      notifyListeners();
      return;
    }
    sendCommand(cmd);
  }

  /// Apply a command broadcast by the host ([by] is the seat that played it).
  void applyFromHost(int by, GameCommand cmd) {
    if (_disposed) return;
    engine.apply(cmd, byPlayer: by);
    notifyListeners();
  }

  /// Wakes the client's engine after a 'start' from the host; the opening
  /// decision then waits on the first player like any other.
  void start() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  Future<void> leave() async => dispose();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Joining client: connects to a host, mirrors the lobby, and plays through
/// [table] once the game starts.
class ClientConnection extends LobbyController {
  ClientConnection({
    required String address,
    required this._port,
    required String myName,
  })  : _hostAddress = address,
        _me = Net.clampName(myName) {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_channel != null) _send({'type': 'ping'});
    });
  }

  final String _hostAddress;
  final int _port;
  final String _me;

  WebSocketChannel? _channel;
  Timer? _timer;
  String? _mySeatId;
  LobbyInfo? _lobby;
  ClientGameSession? _session;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  @override
  bool get isHost => false;

  @override
  bool get isBusy => _busy;

  @override
  bool get connected => _channel != null;

  @override
  String? get errorMessage => _error;

  @override
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  LobbyInfo? get lobby => _lobby;

  @override
  GameSession? get table => _session;

  /// The seat index this device plays, or -1.
  int get mySeatIndex {
    final l = _lobby;
    if (l == null || _mySeatId == null) return -1;
    final i = l.seats.indexWhere((s) => s.id == _mySeatId);
    return i;
  }

  Future<void> connect() async {
    _busy = true;
    notifyListeners();
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse('ws://$_hostAddress:$_port/'));
    } catch (_) {
      _busy = false;
      _error = 'Could not reach the host.';
      notifyListeners();
      return;
    }
    _channel = channel;
    channel.stream.listen(
      _onMessage,
      onDone: _fail,
      onError: (Object _) => _fail('Connection lost.'),
    );
    _send({
      'type': 'join',
      'name': _me,
    });
  }

  void _fail([String? message]) {
    if (_disposed) return;
    _error = message ?? 'Connection lost.';
    _channel = null;
    notifyListeners();
  }

  void _send(Object o) {
    final c = _channel;
    if (c == null) return;
    try {
      c.sink.add(jsonEncode(o));
    } catch (_) {}
  }

  void _onMessage(Object? raw) {
    if (_disposed) return;
    final bytes =
        raw is List<int> ? raw : raw is String ? utf8.encode(raw) : null;
    if (bytes == null) return;
    final Object decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final m = decoded.cast<String, Object?>();
    switch (m['type']) {
      case 'welcome':
        _busy = false;
        _mySeatId = m['you'] as String?;
        _lobby = LobbyInfo.fromJson((m['lobby'] as Map).cast<String, Object?>());
        notifyListeners();
      case 'lobby':
        _lobby = LobbyInfo.fromJson((m['lobby'] as Map).cast<String, Object?>());
        notifyListeners();
      case 'start':
        _busy = false;
        final players = <Player>[];
        var i = 0;
        for (final p in (m['players'] as List)) {
          final jm = (p as Map).cast<String, Object?>();
          final isBot = jm['bot'] as bool? ?? false;
          players.add(Player(
            id: i,
            name: jm['name'] as String? ?? 'Player',
            isBot: isBot,
            skill: isBot ? BotSkill.values.byName(jm['skill'] as String? ?? 'amateur') : null,
          ));
          i++;
        }
        final seed = m['seed'] as int? ?? 0;
        final session = ClientGameSession(
          engine: GameEngine(players: players, seed: seed),
          mySeat: mySeatIndex,
          sendCommand: (cmd) => _send({'type': 'cmd', 'cmd': cmd.toJson()}),
        );
        session.start();
        _session = session;
        notifyListeners();
      case 'cmd':
        final s = _session;
        if (s == null) return;
        final cj = m['cmd'];
        if (cj is! Map) return;
        try {
          s.applyFromHost(m['by'] as int? ?? 0, GameCommand.fromJson(cj.cast<String, Object?>()));
        } catch (_) {}
      case 'error':
        _error = m['message'] as String? ?? 'The host refused the connection.';
        _busy = false;
        notifyListeners();
      default:
    }
  }

  @override
  void removeSeat(String seatId) {
    // Clients cannot remove seats.
  }

  @override
  void setBotSkill(String seatId, BotSkill skill) {
    // Clients cannot configure bots.
  }

  @override
  void addBot() {
    // Clients cannot add bots.
  }

  @override
  void startGame() {
    // The host starts the game.
  }

  /// Disconnect and drop any client-side session.
  @override
  Future<void> leave() async {
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _session?.dispose();
    _session = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    super.dispose();
  }
}