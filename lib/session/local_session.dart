import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/bot.dart';
import '../game/commands.dart';
import '../game/engine.dart';

/// A single device's view of one game, in any mode (solo, pass & play, host,
/// join). The game screen depends only on this interface.
abstract class GameSession extends ChangeNotifier {
  GameEngine get engine;

  /// The seat this device controls, or -1 for pass & play (the device
  /// operates whichever seat is acting).
  int get mySeat;

  bool get isPassAndPlay => mySeat < 0;

  /// The seat the engine is waiting on right now, or -1.
  int get activeSeat => engine.acting ?? -1;

  /// Whether this device may send a command right now.
  bool get canAct;

  /// Whether this device drives the game (applies commands to the real
  /// engine and steps it). Solo, pass & play and host are authorities; a
  /// client is not.
  bool get isAuthority;

  /// The last rejected command, if any.
  String? get errorMessage;

  void clearError();

  /// Send a command. Local sessions apply it; networked sessions send it to
  /// the host, which validates and broadcasts it.
  void submit(GameCommand cmd);

  bool get connected;

  /// Leave the game (and, for lobby-based sessions, tear the lobby down).
  Future<void> leave();

  @override
  void dispose();
}

/// A fully local game: solo against bots, or pass & play around one device.
class LocalGameSession extends GameSession {
  LocalGameSession({
    required List<Player> players,
    this.mySeat = 0,
    this.botDelayMs = 700,
    this.seed,
  }) : _rngs = [
          for (var i = 0; i < players.length; i++)
            Random(players[i].name.hashCode * 31 + i * 7)
        ],
        engine = GameEngine(
          players: List.of(players),
          seed: seed ?? Random().nextInt(1 << 30),
        );

  @override
  final GameEngine engine;

  /// The seat this device controls, or -1 for pass & play.
  @override
  final int mySeat;

  final int botDelayMs;
  final int? seed;
  final List<Random> _rngs;

  Timer? _botTimer;
  String? _error;
  bool _disposed = false;
  bool _started = false;
  /// Invoked after every command applied on this device, with the seat it
  /// came from. The host lobby uses this to relay commands to clients.
  void Function(int by, GameCommand cmd)? onCommand;

  /// Apply a command as [seat] (used by the host to apply client commands).
  void applyAs(int seat, GameCommand cmd) {
    if (_disposed || engine.over) return;
    engine.apply(cmd, byPlayer: seat);
    onCommand?.call(seat, cmd);
    _notify();
  }


  @override
  bool get isAuthority => true;

  @override
  bool get canAct =>
      !engine.over && (isPassAndPlay || engine.acting == mySeat);

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

  /// Kicks off the game: announces the starting player and drives the
  /// first bot move, if any. Call once, after construction.
  void start() {
    if (_started) return;
    _started = true;
    _notify();
  }

  @override
  void submit(GameCommand cmd) {
    if (_disposed || engine.over) return;
    if (!canAct) {
      _error = 'Not your move yet.';
      notifyListeners();
      return;
    }
    applyAs(isPassAndPlay ? engine.acting! : mySeat, cmd);
  }

  void _notify() {
    notifyListeners();
    _driveBots();
  }

  void _driveBots() {
    _botTimer?.cancel();
    _botTimer = null;
    final seat = engine.acting;
    if (engine.over || seat == null) return;
    final player = engine.players[seat];
    if (!player.isBot || player.skill == null) return;
    // A little per-seat jitter keeps bots from moving in lockstep.
    final delay = botDelayMs + (seat * 173) % 280;
    _botTimer = Timer(Duration(milliseconds: delay), () {
      if (_disposed || engine.over || engine.acting != seat) return;
      GameCommand cmd;
      try {
        cmd = Bot.decide(engine, seat, player.skill!, _rngs[seat]);
      } catch (_) {
        cmd = const PassCmd();
      }
      applyAs(seat, cmd);
    });
  }

  @override
  Future<void> leave() async {
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _botTimer?.cancel();
    super.dispose();
  }
}