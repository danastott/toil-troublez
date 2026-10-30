import 'engine.dart';

/// Human names for bots, keyed by skill level. Every name starts with the
/// skill's initial (Amateur, Skilled, Master), so a bot's level is readable
/// at a glance in the player list without cluttering the interface.
class BotNames {
  BotNames._();

  static const List<String> _amateur = [
    'Alice', 'Angus', 'Ada', 'Arlo', 'Amara',
    'Aiden', 'Atticus', 'Astrid', 'Anselm', 'Aurelia',
  ];
  static const List<String> _skilled = [
    'Silas', 'Stella', 'Soren', 'Sage', 'Sebastian',
    'Simone', 'Stefan', 'Sabine', 'Sable', 'Sylvie',
  ];
  static const List<String> _master = [
    'Marcus', 'Mara', 'Milo', 'Maren', 'Miles',
    'Monica', 'Maddox', 'Marisol', 'Mortimer', 'Millicent',
  ];

  static const Map<BotSkill, List<String>> _pools = {
    BotSkill.amateur: _amateur,
    BotSkill.skilled: _skilled,
    BotSkill.master: _master,
  };

  /// The name for a bot of [skill] at seat [index]: deterministic, and
  /// distinct from [taken] (human players and other bots in the lobby).
  static String pick(BotSkill skill, int index, Set<String> taken) {
    final pool = _pools[skill]!;
    final start = index % pool.length;
    for (var k = 0; k < pool.length; k++) {
      final name = pool[(start + k) % pool.length];
      if (!taken.contains(name)) return name;
    }
    return pool[start];
  }
}
