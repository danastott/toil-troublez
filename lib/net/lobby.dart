import 'package:flutter/foundation.dart';

import '../game/engine.dart';
import '../session/local_session.dart';

/// One seat in the lobby.
class LobbySeat {
  const LobbySeat({
    required this.id,
    required this.name,
    required this.isHost,
    this.isBot = false,
    this.skill,
    this.connected = true,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool isBot;
  final BotSkill? skill;
  final bool connected;

  LobbySeat copyWith({
    String? name,
    bool? isBot,
    BotSkill? skill,
    bool? connected,
  }) =>
      LobbySeat(
        id: id,
        name: name ?? this.name,
        isHost: isHost,
        isBot: isBot ?? this.isBot,
        skill: skill ?? this.skill,
        connected: connected ?? this.connected,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'host': isHost,
        'bot': isBot,
        'skill': isBot ? skill?.name : null,
        'connected': connected,
      };

  static LobbySeat fromJson(Map<String, Object?> j) => LobbySeat(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Player',
        isHost: j['host'] as bool? ?? false,
        isBot: j['bot'] as bool? ?? false,
        skill: _parseSkill(j['skill']),
        connected: j['connected'] as bool? ?? true,
      );

  static BotSkill? _parseSkill(Object? v) {
    if (v is! String) return null;
    for (final s in BotSkill.values) {
      if (s.name == v) return s;
    }
    return null;
  }

  @override
  String toString() =>
      '$name${isBot ? ' (bot)' : ''}${isHost ? ' (host)' : ''}';
}

/// A snapshot of the whole lobby.
class LobbyInfo {
  const LobbyInfo({
    required this.hostName,
    required this.seats,
    required this.port,
    this.started = false,
  });

  final String hostName;
  final List<LobbySeat> seats;
  final int port;
  final bool started;

  bool get canStart => seats.length >= minPlayers && !started;

  /// The game takes 2-6 players.
  static const int minPlayers = 2;
  static const int maxPlayers = 6;

  LobbyInfo copyWith({
    String? hostName,
    List<LobbySeat>? seats,
    int? port,
    bool? started,
  }) =>
      LobbyInfo(
        hostName: hostName ?? this.hostName,
        seats: seats ?? this.seats,
        port: port ?? this.port,
        started: started ?? this.started,
      );

  Map<String, Object?> toJson() => {
        'host': hostName,
        'port': port,
        'started': started,
        'players': seats.length,
        'seats': [for (final s in seats) s.toJson()],
      };

  static LobbyInfo fromJson(Map<String, Object?> j) {
    final seatsJson = (j['seats'] as List?)?.cast<Map<Object?, Object?>>() ??
        const [];
    return LobbyInfo(
      hostName: j['host'] as String? ?? 'A nearby host',
      port: j['port'] as int? ?? 0,
      started: j['started'] as bool? ?? false,
      seats: [for (final s in seatsJson) LobbySeat.fromJson(s.cast<String, Object?>())],
    );
  }
}

/// The lobby, from the device's point of view. Both the host and a joining
/// client drive their UI through this interface.
abstract class LobbyController extends ChangeNotifier {
  /// The current lobby state, or null before the first update.
  LobbyInfo? get lobby;

  /// The live game session, once the host starts the game.
  GameSession? get table;

  bool get isHost;

  /// True while a connection action (join, leave) is in flight.
  bool get isBusy;

  /// Whether the underlying connection is alive (client) or the server is
  /// up (host).
  bool get connected;
  String? get errorMessage;

  void clearError();

  // Host-only operations; clients ignore them.
  void addBot();
  void removeSeat(String seatId);
  void setBotSkill(String seatId, BotSkill skill);
  void startGame();

  /// Leave the lobby (host: tears everything down; client: disconnects).
  Future<void> leave();
}