import 'cards.dart';
import 'rules.dart';

/// A player decision sent to the engine (and over the network).
sealed class GameCommand {
  const GameCommand();

  Map<String, Object?> toJson();

  static GameCommand fromJson(Map<String, Object?> j) {
    switch (j['t']) {
      case 'draw':
        return const DrawCmd();
      case 'continue':
        return const ContinueCmd();
      case 'pass':
        return const PassCmd();
      case 'place':
        return PlaceCmd(PlacementOptionJson.fromJson(j['o']! as Map<String, Object?>));
      case 'pickRow':
        return PickRowCmd(j['row'] as int);
      case 'pick':
        final o = j['o']! as Map<String, Object?>;
        return PickCmd(PickOption(o['row'] as int,
            (o['side'] as String) == 'l' ? PlaceSide.left : PlaceSide.right));
      case 'vanishType':
        return VanishTypeCmd(TalismanType.values[j['type'] as int]);
      case 'victimDiscard':
        return VictimDiscardCmd(j['player'] as int, j['card'] as int);
      case 'summon':
        return SummonCmd(j['from'] as int, j['card'] as int);
      case 'poison':
        return PoisonCmd(j['card'] as int);
    }
    throw FormatException('unknown command: ${j['t']}');
  }

  @override
  String toString() => 'cmd(${toJson()})';
}

class DrawCmd extends GameCommand {
  const DrawCmd();
  @override
  Map<String, Object?> toJson() => const {'t': 'draw'};
}

class ContinueCmd extends GameCommand {
  const ContinueCmd();
  @override
  Map<String, Object?> toJson() => const {'t': 'continue'};
}

class PassCmd extends GameCommand {
  const PassCmd();
  @override
  Map<String, Object?> toJson() => const {'t': 'pass'};
}

class PlaceCmd extends GameCommand {
  const PlaceCmd(this.option);
  final PlacementOption option;
  @override
  Map<String, Object?> toJson() => {'t': 'place', 'o': option.toJson()};
}

class PickRowCmd extends GameCommand {
  const PickRowCmd(this.row);
  final int row;
  @override
  Map<String, Object?> toJson() => {'t': 'pickRow', 'row': row};
}

class PickCmd extends GameCommand {
  const PickCmd(this.option);
  final PickOption option;
  @override
  Map<String, Object?> toJson() => {
        't': 'pick',
        'o': option.toJson(),
      };
}

class VanishTypeCmd extends GameCommand {
  const VanishTypeCmd(this.type);
  final TalismanType type;
  @override
  Map<String, Object?> toJson() => {'t': 'vanishType', 'type': type.index};
}

class VictimDiscardCmd extends GameCommand {
  const VictimDiscardCmd(this.player, this.card);
  final int player;
  final int card;
  @override
  Map<String, Object?> toJson() => {
        't': 'victimDiscard',
        'player': player,
        'card': card,
      };
}

class SummonCmd extends GameCommand {
  const SummonCmd(this.from, this.card);
  final int from;
  final int card;
  @override
  Map<String, Object?> toJson() => {
        't': 'summon',
        'from': from,
        'card': card,
      };
}

class PoisonCmd extends GameCommand {
  const PoisonCmd(this.card);
  final int card;
  @override
  Map<String, Object?> toJson() => {'t': 'poison', 'card': card};
}

// ---------------------------------------------------------------------------
// Placement option (de)serialization.
// ---------------------------------------------------------------------------

extension PlacementOptionJson on PlacementOption {
  Map<String, Object?> toJson() {
    if (this is NewRowPlacement) return const {'t': 'new'};
    if (this is CloakPlacement) {
      return {'t': 'cloak', 'id': (this as CloakPlacement).targetId};
    }
    final rp = this as RowPlacement;
    return {'t': 'row', 'row': rp.row, 'side': rp.side == PlaceSide.left ? 'l' : 'r'};
  }

  static PlacementOption fromJson(Map<String, Object?> j) {
    switch (j['t']) {
      case 'new':
        return const NewRowPlacement();
      case 'cloak':
        return CloakPlacement(j['id'] as int);
      case 'row':
        return RowPlacement(j['row'] as int,
            (j['side'] as String) == 'l' ? PlaceSide.left : PlaceSide.right);
    }
    throw FormatException('unknown placement: ${j['t']}');
  }
}

extension PickOptionJson on PickOption {
  Map<String, Object?> toJson() => {
        't': 'row',
        'row': row,
        'side': side == PlaceSide.left ? 'l' : 'r',
      };

  static PickOption fromJson(Map<String, Object?> j) => PickOption(
      j['row'] as int, (j['side'] as String) == 'l' ? PlaceSide.left : PlaceSide.right);
}