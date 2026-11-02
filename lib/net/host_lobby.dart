import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../game/commands.dart';
import '../game/engine.dart';
import '../game/names.dart';
import '../session/local_session.dart';
import 'discovery.dart';
import 'lobby.dart';

class _Client {
  _Client(this.socket);

  final WebSocket socket;
  LobbySeat seat = const LobbySeat(id: '', name: 'Player', isHost: false);
}

/// The host: runs the authoritative game, serves joining clients over
/// WebSocket (dart:io, like the cover_your_assets reference), and
/// advertises itself on the LAN via UDP discovery.
class HostLobby extends LobbyController {
  HostLobby({
    required String hostName,
    int port = Net.wsPort,
    int discoveryPort = Net.discoveryPort,
  })  : _hostName = Net.clampName(hostName),
        _initialPort = port,
        _port = port,
        // ignore: prefer_initializing_formals
        _discoveryPort = discoveryPort;

  final String _hostName;
  final List<LobbySeat> _seats = [];
  final List<_Client> _clients = [];
  final int _initialPort;
  int _port;
  final int _discoveryPort;
  int _nextId = 1;
  HttpServer? _server;
  DiscoveryResponder? _discovery;
  LocalGameSession? _session;
  bool _started = false;
  String? _error;

  String get hostName => _hostName;
  int get port => _port;

  @override
  bool get isHost => true;

  @override
  bool get isBusy => false;

  @override
  bool get connected => _server != null;

  @override
  String? get errorMessage => _error;

  @override
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  LobbyInfo get lobbyInfo => LobbyInfo(
        hostName: _hostName,
        port: _port,
        started: _started,
        seats: List.of(_seats),
      );

  @override
  LobbyInfo? get lobby => _seats.isEmpty ? null : lobbyInfo;

  @override
  GameSession? get table => _session;

  /// Opens the WebSocket port and starts advertising the lobby. If the
  /// requested port is taken, it scans up through a nine-port window —
  /// whichever port wins is the one advertised to joiners, so a fallback
  /// port works as well as the default.
  Future<void> start() async {
    _seats.add(
        const LobbySeat(id: 'host', name: 'Host', isHost: true));
    _seats.first = _seats.first.copyWith(name: _hostName);
    var tryPort = _initialPort;
    var firstPort = tryPort;
    HttpServer? server;
    Object? bindError;
    for (var attempt = 0; attempt < 9 && server == null; attempt++) {
      // IPv4 first, then the IPv6 wildcard (dual-stack on macOS): on
      // IPv6-only networks the IPv4 bind alone would fail even when a
      // free port exists.
      for (final addr in [
        InternetAddress.anyIPv4,
        InternetAddress.anyIPv6,
      ]) {
        try {
          server = await HttpServer.bind(addr, tryPort);
          break;
        } catch (e) {
          bindError ??= e;
        }
      }
      tryPort++;
    }
    if (server == null) {
      final msg =
          bindError is SocketException ? bindError.osError?.message : null;
      final denied = msg != null &&
          (msg.toLowerCase().contains('permitted') ||
              msg.toLowerCase().contains('permission'));
      _error = denied
          ? 'The device is not letting the app open the game port (ports '
              '$firstPort to ${firstPort + 8}): $msg. Reinstall the app '
              'from a fresh build and try again on a Wi-Fi network.'
          : 'Could not open the game port: ports $firstPort to '
              '${firstPort + 8} are busy or blocked'
              '${msg == null ? '' : ' ($msg)'}. Another program (often '
              'another run of this app) is probably holding them — '
              'close it and try again.';
      notifyListeners();
      return;
    }
    _server = server;
    _port = server.port;
    server.listen(_handleRequest);
    _discovery = DiscoveryResponder(
      hostName: _hostName,
      port: _port,
      seatsProvider: () => List.of(_seats),
      discoveryPort: _discoveryPort,
    );
    await _discovery!.start();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Lobby mutations (host only)
  // ------------------------------------------------------------------

  @override
  void addBot() {
    if (_started || _seats.length >= LobbyInfo.maxPlayers) return;
    final bots = _seats.where((s) => s.isBot).length;
    final taken = {for (final s in _seats) s.name};
    _seats.add(LobbySeat(
      id: 'bot${_nextId++}',
      name: BotNames.pick(BotSkill.amateur, bots, taken),
      isHost: false,
      isBot: true,
      skill: BotSkill.amateur,
    ));
    _syncLobby();
  }

  @override
  void removeSeat(String seatId) {
    if (seatId == 'host') return;
    final i = _seats.indexWhere((s) => s.id == seatId);
    if (i < 0) return;
    _seats.removeAt(i);
    _syncLobby();
  }

  @override
  void setBotSkill(String seatId, BotSkill skill) {
    final i = _seats.indexWhere((s) => s.id == seatId);
    if (i < 0 || !_seats[i].isBot) return;
    var seat = _seats[i];
    if (seat.skill == skill) return;
    if (seat.name.isNotEmpty &&
        seat.name[0].toLowerCase() != skill.name[0]) {
      // Keep the name's initial in step with the skill.
      final taken = {for (final s in _seats) if (s.id != seatId) s.name};
      seat = seat.copyWith(name: BotNames.pick(skill, i, taken));
    }
    _seats[i] = seat.copyWith(skill: skill);
    _syncLobby();
  }

  @override
  void startGame() {
    if (_started ||
        _seats.length < LobbyInfo.minPlayers ||
        _seats.length > LobbyInfo.maxPlayers) {
      return;
    }
    final players = <Player>[];
    for (var i = 0; i < _seats.length; i++) {
      final s = _seats[i];
      players.add(s.isBot
          ? Player(
              id: i,
              name: s.name,
              isBot: true,
              skill: s.skill ?? BotSkill.amateur)
          : Player(id: i, name: s.name));
    }
    _session = LocalGameSession(players: players, mySeat: 0);
    _session!.onCommand = (by, cmd) => _broadcastCmd(by, cmd);
    _started = true;
    _session!.start();
    _discovery?.stop();
    final startMsg = jsonEncode({
      'type': 'start',
      'players': [
        for (final p in players)
          {
            'name': p.name,
            'bot': p.isBot,
            'skill': p.skill?.name,
          }
      ],
      'seed': _session!.engine.seed,
    });
    for (final c in _clients) {
      _send(c, startMsg);
    }
    _syncLobby();
  }

  @override
  Future<void> leave() async {
    await _discovery?.stop();
    for (final c in _clients) {
      // Fire-and-forget: never await a peer that may never answer the close
      // handshake, or teardown could hang forever.
      try {
        c.socket.close();
      } catch (_) {}
    }
    _session?.dispose();
    _session = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _seats.clear();
    _started = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Client connections
  // ------------------------------------------------------------------

  void _handleRequest(HttpRequest request) {
    // Any non-upgrade request gets a 400.
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.close();
      return;
    }
    WebSocketTransformer.upgrade(request).then(_handleConnect).catchError((
      Object e,
    ) {
      try {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
      } catch (_) {}
    });
  }

  void _handleConnect(WebSocket socket) {
    if (_started || _seats.length >= LobbyInfo.maxPlayers) {
      try {
        _sendRaw(
          socket,
          jsonEncode({
            'type': 'error',
            'message': _started
                ? 'That table is already in a game.'
                : 'That table is full.',
          }),
        );
        socket.close();
      } catch (_) {}
      return;
    }
    final client = _Client(socket);
    client.seat = LobbySeat(
        id: 'p${_nextId++}',
        name: 'Player ${_seats.length + 1}',
        isHost: false);
    _clients.add(client);
    _seats.add(client.seat);
    _sendRaw(socket, jsonEncode({
      'type': 'welcome',
      'you': client.seat.id,
      'lobby': lobbyInfo.toJson(),
    }));
    _syncLobby();
    socket.listen(
      (raw) => _handleMessage(client, raw),
      onDone: () => _handleDisconnect(client),
      onError: (_) => _handleDisconnect(client),
      cancelOnError: true,
    );
  }

  int _seatIndex(_Client client) =>
      _seats.indexWhere((s) => s.id == client.seat.id);

  void _handleMessage(_Client client, Object? raw) {
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
      case 'join':
        final name = Net.clampName((m['name'] as String?) ?? '');
        final i = _seatIndex(client);
        if (i >= 0 && name != client.seat.name) {
          _seats[i] = client.seat.copyWith(name: name);
          _syncLobby();
        }
      case 'cmd':
        final seat = _seatIndex(client);
        final s = _session;
        if (seat < 0 || s == null) return;
        final cj = m['cmd'];
        if (cj is! Map) return;
        try {
          final cmd = GameCommand.fromJson(cj.cast<String, Object?>());
          s.applyAs(seat, cmd);
          _broadcastCmd(seat, cmd);
        } catch (_) {}
      case 'ping':
        // Keep-alive: no reply needed.
      default:
        // Unknown message type: ignore.
    }
  }

  void _broadcastCmd(int by, GameCommand cmd) {
    final msg = jsonEncode({'type': 'cmd', 'by': by, 'cmd': cmd.toJson()});
    for (final c in _clients) {
      _send(c, msg);
    }
  }

  void _handleDisconnect(_Client client) {
    _clients.remove(client);
    final i = _seatIndex(client);
    if (i >= 0) _seats.removeAt(i);
    _syncLobby();
  }

  void _send(_Client c, String message) {
    try {
      c.socket.add(message);
    } catch (_) {}
  }

  void _sendRaw(WebSocket socket, String message) {
    try {
      socket.add(message);
    } catch (_) {}
  }

  void _syncLobby() {
    final msg = jsonEncode({'type': 'lobby', 'lobby': lobbyInfo.toJson()});
    for (final c in _clients) {
      _send(c, msg);
    }
    _discovery?.broadcast();
    notifyListeners();
  }
}