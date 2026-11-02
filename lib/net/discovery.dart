import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'lobby.dart';

/// Wire constants shared by host and clients.
class Net {
  static const String tag = 'toil-and-troublez';
  static const int protocol = 1;
  static const int discoveryPort = 47920;
  static const int wsPort = 47921;
  static const int maxNameLen = 24;

  static String clampName(String raw, {String fallback = 'Player'}) {
    var n = raw.trim().replaceAll(RegExp(r'[\r\n]'), ' ');
    if (n.length > maxNameLen) n = n.substring(0, maxNameLen);
    return n.isEmpty ? fallback : n;
  }

  /// The tagged UDP payload describing a lobby (or an empty probe).
  static Uint8List encodeLobby({
    required String host,
    required int port,
    required int players,
    required bool started,
  }) =>
      utf8.encode(
          '$tag ${jsonEncode({
        'tag': tag,
        'v': protocol,
        'host': host,
        'port': port,
        'players': players,
        'started': started,
      })}');
}

/// A host seen on the LAN (from the join screen).
class DiscoveredTable {
  const DiscoveredTable({
    required this.hostName,
    required this.address,
    required this.port,
    required this.players,
    required this.started,
  });

  final String hostName;
  final String address;
  final int port;
  final int players;
  final bool started;

  String get title =>
      started
          ? '$hostName (in game)'
          : '$hostName ($players player${players == 1 ? '' : 's'})';
}

/// Answers discovery probes on our behalf: the host runs one and re-broadcasts
/// its current lobby so the join screen shows live player counts.
class DiscoveryResponder {
  DiscoveryResponder({
    required this.hostName,
    required this.seatsProvider,
    this.port = Net.wsPort,
    this.discoveryPort = Net.discoveryPort,
  });

  final String hostName;

  /// The WebSocket port this table plays on (advertised to joiners).
  final int port;
  final int discoveryPort;
  final List<LobbySeat> Function() seatsProvider;

  RawDatagramSocket? _socket;

  /// True once the SDK reports the socket dead (a failed send closes it
  /// from inside the SDK); the next [broadcast] rebinds.
  bool _socketDead = false;

  /// Set by [stop] so a bind in flight does not resurrect the socket.
  bool _stopped = false;
  Timer? _timer;
  void Function(DiscoveredTable table)? _onTableFound;

  /// Called when we see another host's table (useful for the join screen,
  /// which is what the host also shows while it waits).
  void onTableFound(void Function(DiscoveredTable) f) => _onTableFound = f;

  Future<void> start() async {
    if (_socket != null) return;
    await _ensureSocket();
    // The timer runs even if the bind failed: broadcast() retries the
    // bind, so a port that was busy at startup is picked up later.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => broadcast());
    broadcast();
  }

  /// Binds the discovery socket, or null if the port cannot be bound.
  Future<RawDatagramSocket?> _bind() async {
    try {
      return await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// A bind in flight, so concurrent callers share one socket.
  Future<void>? _binding;

  /// (Re)binds the discovery socket. A bind failure is not fatal: the
  /// socket stays null and the next [broadcast] retries.
  Future<void> _ensureSocket() {
    if (_socket != null && !_socketDead) {
      return Future<void>.value();
    }
    return _binding ??= _bindSocket();
  }

  Future<void> _bindSocket() async {
    _socketDead = false;
    final bound = await _bind();
    _binding = null;
    if (bound == null) return;
    if (_stopped) {
      try {
        bound.close();
      } catch (_) {
        // Already closed.
      }
      return;
    }
    bound.broadcastEnabled = true;
    bound.multicastLoopback = true;
    bound.listen(
      (event) {
        if (event == RawSocketEvent.closed) {
          _socketDead = true;
          return;
        }
        if (event != RawSocketEvent.read) return;
        final d = bound.receive();
        if (d == null) return;
        _handle(d);
      },
      onError: (Object _) {
        // A failed send (no route on a dead interface) also arrives here;
        // the SDK has already closed the socket.
        _socketDead = true;
      },
    );
    _socket = bound;
  }

  /// Runs a UDP [send] in a zone that absorbs its async failure report.
  /// The SDK never throws from [RawDatagramSocket.send]: an unroutable
  /// destination is reported to the zone *after* the call has returned,
  /// so a plain try/catch cannot catch it. Left uncontained it escapes as
  /// an uncaught error (failing tests, spaming the app's error handler).
  /// The socket dies either way — the handler marks it dead (if it is
  /// still the current one) so the next broadcast rebinds.
  void _safeSend(RawDatagramSocket socket, void Function() send) {
    runZonedGuarded(
      send,
      (Object _, StackTrace _) {
        if (_socket != socket) return; // Superseded by a rebind; keep it.
        _socketDead = true;
        try {
          socket.close();
        } catch (_) {
          // The SDK already closed it.
        }
        _socket = null;
      },
    );
  }

  void _handle(Datagram d) {
    final str = utf8.decode(d.data, allowMalformed: true);
    final i = str.indexOf(' ');
    if (i < 0 || str.substring(0, i) != Net.tag) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(str.substring(i + 1));
    } catch (_) {
      // Not one of ours.
      return;
    }
    if (decoded is! Map) return;
    final j = decoded.cast<String, Object?>();
    final host = j['host'] as String? ?? '';
    if (host.isEmpty) {
      // A probe from a join screen. Its socket listens on an ephemeral
      // port, so a broadcast to the fixed port would never reach it: the
      // only way to be found is to answer the probe directly.
      if (d.address.address == '0.0.0.0') return; // Unanswerable.
      final s = _socket;
      if (s == null) return;
      _safeSend(s, () => s.send(_payload(), d.address, d.port));
      return;
    }
    if (host == hostName) return;
    final port = j['port'] as int?;
    if (port == null || port <= 0) return;
    _onTableFound?.call(DiscoveredTable(
      hostName: host,
      address: d.address.address,
      port: port,
      players: j['players'] as int? ?? 0,
      started: j['started'] as bool? ?? false,
    ));
  }

  /// The tagged payload describing our current lobby.
  Uint8List _payload() => Net.encodeLobby(
        host: hostName,
        port: port,
        players: seatsProvider().length,
        started: false,
      );

  /// Re-broadcast the current lobby snapshot.
  void broadcast() {
    final s = _socket;
    if (s == null || _socketDead) {
      unawaited(_ensureSocket());
      return;
    }
    final payload = _payload();
    // Loopback first: a second app on this device is answered via its
    // probe, but the same-device smoke path (join screen scanning while a
    // host runs here) must survive even if the LAN broadcast is unroutable.
    _safeSend(
        s, () => s.send(payload, InternetAddress('127.0.0.1'), discoveryPort));
    _safeSend(
        s, () => s.send(payload, InternetAddress('255.255.255.255'), discoveryPort));
  }

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    try {
      _socket?.close();
    } catch (_) {
      // Already closed.
    }
    _socket = null;
  }
}

/// The join-screen scanner: probes candidate broadcast addresses for hosts.
class TableDiscovery {
  RawDatagramSocket? _socket;

  /// True once the SDK reports the socket dead (a failed send closes it
  /// from inside the SDK); the next probe round rebinds.
  bool _socketDead = false;
  /// Candidates whose last probe could not be routed (dead or VPN
  /// interface), with epoch millis. Retried after [_noRouteCooldown].
  final Map<String, int> _noRoute = {};

  /// Set by [stop] so a bind in flight does not resurrect the socket.
  bool _stopped = false;
  Timer? _probeTimer;
  final Map<String, DiscoveredTable> _tables = {};
  final StreamController<DiscoveredTable> _found =
      StreamController<DiscoveredTable>.broadcast();
  /// Epoch millis of the last accepted reply per table key; drives expiry.
  final Map<String, int> _lastSeen = {};
  /// Emitted whenever the visible set of tables changes, including
  /// removals by [_sweepStale]. The join screen rebuilds on this.
  final StreamController<void> _changed =
      StreamController<void>.broadcast();
  final List<String> _candidates;
  List<String> _local = const [];

  TableDiscovery({
    List<String>? candidates,
    this.discoveryPort = Net.discoveryPort,
    this.staleAfter = const Duration(seconds: 8),
  }) : _candidates = candidates ??
          [
            '255.255.255.255',
            // A host on this same device answers its probe on loopback;
            // the reply is a unicast to our ephemeral port.
            '127.0.0.1',
          ];

  /// The UDP port hosts listen on for probes (injectable for tests).
  final int discoveryPort;

  /// How long a host may stay silent before its entry is dropped. Without
  /// this, a host that leaves the network or crashes would sit in the
  /// join list forever.
  final Duration staleAfter;

  /// /24 broadcast guesses for each local interface, so we probe the right
  /// subnet even when the default gateways differ.
  static Future<List<String>> _localSubnetBroadcasts() async {
    try {
      final ifaces = await NetworkInterface.list(includeLoopback: false);
      return ifaces
          .map((iface) {
            for (final a in iface.addresses) {
              if (a.type != InternetAddressType.IPv4) continue;
              final parts = a.address.split('.');
              if (parts.length == 4) {
                return '${parts[0]}.${parts[1]}.${parts[2]}.255';
              }
            }
            return '255.255.255.255';
          })
          .where((b) => b != '255.255.255.255')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Starts probing; tables arrive on [found]. Call [stop] when done.
  Future<void> start({
    Duration probeInterval = const Duration(milliseconds: 800),
  }) async {
    if (_socket != null) return;
    _local = await _localSubnetBroadcasts();
    _probeTimer =
        Timer.periodic(probeInterval, (_) => unawaited(_sendProbes()));
    unawaited(_sendProbes());
  }

  /// Binds the probe socket (ephemeral port), or null on failure.
  Future<RawDatagramSocket?> _bind() async {
    try {
      return await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// A bind in flight, so concurrent callers share one socket.
  Future<void>? _binding;

  /// (Re)binds the probe socket. A bind failure is not fatal: the next
  /// probe round retries.
  Future<void> _ensureSocket() {
    if (_socket != null && !_socketDead) {
      return Future<void>.value();
    }
    return _binding ??= _bindSocket();
  }

  Future<void> _bindSocket() async {
    _socketDead = false;
    final bound = await _bind();
    _binding = null;
    if (bound == null) return;
    if (_stopped) {
      try {
        bound.close();
      } catch (_) {
        // Already closed.
      }
      return;
    }
    // Probes are broadcasts: without SO_BROADCAST the sends fail and no
    // host on the LAN would ever hear us.
    bound.broadcastEnabled = true;
    bound.multicastLoopback = true;
    bound.listen(
      (event) {
        if (event == RawSocketEvent.closed) {
          _socketDead = true;
          return;
        }
        if (event != RawSocketEvent.read) return;
        final d = bound.receive();
        if (d == null) return;
        _handle(d);
      },
      onError: (Object _) {
        // A failed send (no route on a dead interface) also arrives here;
        // the SDK has already closed the socket.
        _socketDead = true;
        _socket = null;
      },
    );
    _socket = bound;
  }

  /// How long a candidate whose probe could not be routed is skipped:
  /// its interface is down (VPN, virtual), and probing it again only
  /// kills the socket again. An interface that recovers is retried after
  /// the cooldown.
  static const Duration _noRouteCooldown = Duration(seconds: 30);

  /// One probe round: one datagram to each candidate that is worth
  /// probing. A candidate that cannot be routed is recorded in
  /// [_noRoute] and the round stops; the socket is rebound on the next
  /// round.
  Future<void> _sendProbes() async {
    _sweepStale();
    await _ensureSocket();
    if (_socket == null) return;
    final payload = Net.encodeLobby(
        host: '', port: 0, players: 0, started: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in [..._candidates, ..._local]) {
      final failed = _noRoute[c];
      if (failed != null && now - failed < _noRouteCooldown.inMilliseconds) {
        continue;
      }
      InternetAddress addr;
      try {
        addr = InternetAddress(c);
      } catch (_) {
        continue;
      }
      final s = _socket;
      if (s == null) return;
      var sent = 0;
      runZonedGuarded(
        () {
          sent = s.send(payload, addr, discoveryPort);
        },
        // Absorbs the SDK's async failure report for this send; the
        // return value below handles the bookkeeping synchronously.
        (Object _, StackTrace _) {},
      );
      if (sent == 0) {
        // Unroutable candidate (dead/VPN interface) or a socket that just
        // died: skip this candidate for a while, and the next round
        // rebinds before probing the rest.
        _noRoute[c] = now;
        _socketDead = true;
        try {
          s.close();
        } catch (_) {
          // The SDK already closed it.
        }
        _socket = null;
        break;
      }
    }
  }

  void _handle(Datagram d) {
    final str = utf8.decode(d.data, allowMalformed: true);
    final i = str.indexOf(' ');
    if (i < 0 || str.substring(0, i) != Net.tag) return;
    try {
      final j = jsonDecode(str.substring(i + 1)) as Map<String, dynamic>;
      if ((j['v'] as int? ?? 0) != Net.protocol) return;
      final host = j['host'] as String? ?? '';
      if (host.isEmpty) return;
      final port = (j['port'] as int?) ?? Net.wsPort;
      final key = '$host:$port';
      final table = DiscoveredTable(
        hostName: host,
        address: d.address.address,
        port: port,
        players: j['players'] as int? ?? 0,
        started: j['started'] as bool? ?? false,
      );
      // Every accepted reply is a liveness signal, whether or not the
      // snapshot changed.
      _lastSeen[key] = DateTime.now().millisecondsSinceEpoch;
      // Hosts re-answer every probe, so refresh live player counts and
      // the started flag instead of keeping the first sighting.
      final known = _tables[key];
      if (known == null ||
          known.players != table.players ||
          known.started != table.started) {
        _tables[key] = table;
        _found.add(table);
        _changed.add(null);
      }
    } catch (_) {
      // Not one of ours.
    }
  }

  List<DiscoveredTable> get tables => _tables.values.toList()
        ..sort((a, b) =>
            a.hostName.toLowerCase().compareTo(b.hostName.toLowerCase()));

  Stream<DiscoveredTable> get found => _found.stream;

  /// Emitted whenever the visible set of tables changes (add, update,
  /// or removal).
  Stream<void> get changed => _changed.stream;

  /// Drops tables silent for [staleAfter]. Runs with every probe round,
  /// so a dead host leaves the list within one probe interval of going
  /// stale.
  void _sweepStale() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - staleAfter.inMilliseconds;
    final stale = _lastSeen.entries.where((e) => e.value < cutoff).toList();
    for (final e in stale) {
      _tables.remove(e.key);
      _lastSeen.remove(e.key);
      _changed.add(null);
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _probeTimer?.cancel();
    _probeTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    if (!_found.isClosed) await _found.close();
    if (!_changed.isClosed) await _changed.close();
  }
}
