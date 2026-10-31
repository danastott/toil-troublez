import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../game/engine.dart';

/// The mid-game save: the engine's full state plus which seat this device
/// will resume as.
class GameSave {
  GameSave(this.engineJson, this.mySeat, this.savedAt);

  /// Decoded [GameEngine.toJson] payload.
  final Map<String, Object?> engineJson;

  /// The seat this device resumes as (or -1 for pass & play).
  final int mySeat;

  final DateTime savedAt;

  static const String _fileName = 'tnt-save.json';

  static Future<File?> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// The current save, or null if none (or it is unreadable/corrupt).
  static Future<GameSave?> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, Object?>;
      return GameSave(
        j['engine']! as Map<String, Object?>,
        (j['mySeat'] as int?) ?? 0,
        DateTime.parse(j['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// The save file's last-modified time, or null if there is no save.
  /// Used by the home screen to notice save-file changes without a
  /// file-watcher.
  static Future<DateTime?> mtime() async {
    final f = await _file();
    if (f == null || !await f.exists()) return null;
    return (await f.stat()).modified;
  }

  Future<void> write() async {
    final f = await _file();
    if (f == null) return;
    await f.writeAsString(jsonEncode({
      'engine': engineJson,
      'mySeat': mySeat,
      'savedAt': savedAt.toIso8601String(),
    }));
  }

  /// Deletes the save file, if any.
  static Future<void> clear() async {
    final f = await _file();
    if (f != null && await f.exists()) await f.delete();
  }

  /// Restores the engine this save was written from.
  GameEngine engine() => GameEngine.fromSave(engineJson);
}
