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
  });

  final String hostName;
  final int port;
  final List<LobbySeat> Function() seatsProvider;

  RawDatagramSocket? _socket;
  Timer? _timer;
  void Function(DiscoveredTable table)? _onTableFound;

  /// Called when we see another host's table (useful for the join screen,
  /// which is what the host also shows while it waits).
  void onTableFound(void Function(DiscoveredTable) f) => _onTableFound = f;

  Future<void> start() async {
    if (_socket != null) return;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        Net.discoveryPort,
        reuseAddress: true,
      );
    } catch (_) {
      _socket = null;
      return;
    }
    _socket!.broadcastEnabled = true;
    _socket!.multicastLoopback = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = _socket!.receive();
      if (d == null) return;
      _handle(d);
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => broadcast());
    broadcast();
  }

  void _handle(Datagram d) {
    final str = utf8.decode(d.data, allowMalformed: true);
    final i = str.indexOf(' ');
    if (i < 0 || str.substring(0, i) != Net.tag) return;
    try {
      final j = jsonDecode(str.substring(i + 1)) as Map<String, dynamic>;
      final host = j['host'] as String? ?? '';
      if (host.isEmpty || host == hostName) return;
      final port = j['port'] as int?;
      if (port == null || port <= 0) return;
      _onTableFound?.call(DiscoveredTable(
        hostName: host,
        address: d.address.address,
        port: port,
        players: j['players'] as int? ?? 0,
        started: j['started'] as bool? ?? false,
      ));
    } catch (_) {
      // Not one of ours.
    }
  }

  /// Re-broadcast the current lobby snapshot.
  void broadcast() {
    final s = _socket;
    if (s == null) return;
    final seats = seatsProvider();
    final payload = Net.encodeLobby(
        host: hostName, port: port, players: seats.length, started: false);
    try {
      s.send(payload, InternetAddress('255.255.255.255'), Net.discoveryPort);
      // Loopback so a second app on this device can find us (smoke testing).
      s.send(payload, InternetAddress('127.0.0.1'), Net.discoveryPort);
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> stop() async {
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
  Timer? _probeTimer;
  final Map<String, DiscoveredTable> _tables = {};
  final StreamController<DiscoveredTable> _found =
      StreamController<DiscoveredTable>.broadcast();
  final List<String> _candidates;
  List<String> _local = const [];

  TableDiscovery({List<String>? candidates})
      : _candidates = candidates ??
            [
              '255.255.255.255',
              '255.255.255.0',
            ];

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
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
    } catch (_) {
      _socket = null;
      return;
    }
    _socket!.multicastLoopback = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = _socket!.receive();
      if (d == null) return;
      _handle(d);
    });
    _sendProbes();
    _probeTimer = Timer.periodic(probeInterval, (_) => _sendProbes());
  }

  void _sendProbes() {
    final s = _socket;
    if (s == null) return;
    final payload = Net.encodeLobby(
        host: '', port: 0, players: 0, started: false);
    for (final c in [..._candidates, ..._local]) {
      InternetAddress addr;
      try {
        addr = InternetAddress(c);
      } catch (_) {
        continue;
      }
      try {
        s.send(payload, addr, Net.discoveryPort);
      } catch (_) {
        // Unreachable candidate.
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
      if (!_tables.containsKey(key)) {
        _tables[key] = table;
        _found.add(table);
      }
    } catch (_) {
      // Not one of ours.
    }
  }

  List<DiscoveredTable> get tables => _tables.values.toList()
        ..sort((a, b) =>
            a.hostName.toLowerCase().compareTo(b.hostName.toLowerCase()));

  Stream<DiscoveredTable> get found => _found.stream;

  Future<void> stop() async {
    _probeTimer?.cancel();
    _probeTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    if (!_found.isClosed) await _found.close();
  }
}