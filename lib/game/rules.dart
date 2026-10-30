import 'cards.dart';

/// Which end of a row a card is placed on.
enum PlaceSide { left, right }

/// A visible card in a row, optionally covered by a Cloak.
class ForestSlot {
  ForestSlot(this.card, [this.cloak]);

  final GameCard card;

  /// The Cloak card covering [card], if any. A cloaked card's color and
  /// number are hidden and impose no placement constraints.
  GameCard? cloak;

  bool get isCloaked => cloak != null;
}

/// The Enchanted Forest: at most three horizontal rows. Rows are
/// independent of each other.
class Forest {
  final List<List<ForestSlot>> rows;

  Forest([List<List<ForestSlot>>? rows]) : rows = rows ?? [];

  bool get isEmpty => rows.every((r) => r.isEmpty);

  /// Every visible card currently in the Forest, including cloaked ones.
  List<GameCard> get allCards =>
      [for (final row in rows) for (final slot in row) slot.card];

  bool get hasTalisman => rows.any((row) => row.any((s) => s.card.isTalisman));

  /// Talismans in the Forest that are not already cloaked (valid Cloak
  /// targets).
  List<GameCard> get cloakTargets => [
        for (final row in rows)
          for (final slot in row)
            if (slot.card.isTalisman && !slot.isCloaked) slot.card,
      ];

  List<GameCard> rowCards(int row) => [for (final slot in rows[row]) slot.card];

  void placeAt(int row, PlaceSide side, GameCard card) {
    rows[row]
        .insert(side == PlaceSide.left ? 0 : rows[row].length, ForestSlot(card));
  }

  void startRow(GameCard card) => rows.add([ForestSlot(card)]);

  /// Removes a slot from a row and returns it.
  ForestSlot? takeAt(int row, PlaceSide side) =>
      rows[row].removeAt(side == PlaceSide.left ? 0 : rows[row].length);

  /// Covers [target] with the Cloak card.
  void cloakCard(GameCard target, GameCard cloakCard) {
    for (final row in rows) {
      for (final slot in row) {
        if (identical(slot.card, target) && slot.cloak == null) {
          slot.cloak = cloakCard;
          return;
        }
      }
    }
  }
}

/// All placement choices for one drawn card.
sealed class PlacementOption {
  const PlacementOption();
}

/// Place into an existing row at one end.
class RowPlacement extends PlacementOption {
  const RowPlacement(this.row, this.side);
  final int row;
  final PlaceSide side;

  @override
  bool operator ==(Object other) =>
      other is RowPlacement && other.row == row && other.side == side;
  @override
  int get hashCode => Object.hash(row, side);
}

/// Place on a new row (only when fewer than three rows exist).
class NewRowPlacement extends PlacementOption {
  const NewRowPlacement();

  @override
  bool operator ==(Object other) => other is NewRowPlacement;
  @override
  int get hashCode => runtimeType.hashCode;
}

/// Cover a Talisman with the Cloak.
class CloakPlacement extends PlacementOption {
  const CloakPlacement(this.targetId);
  final int targetId;

  @override
  bool operator ==(Object other) =>
      other is CloakPlacement && other.targetId == targetId;
  @override
  int get hashCode => targetId.hashCode;
}

/// Placement rules for the Enchanted Forest.
class Rules {
  static const int maxRows = 3;

  /// Validates placing [card] at [side] of row [row].
  ///
  ///  - A row holds at most one of each Talisman type and one of each
  ///    Vanish, Summon and Poison.
  ///  - Talisman numbers ascend left to right (gaps allowed), compared
  ///    against every uncloaked Talisman in the row.
  ///  - Adjacent cards may not share a background color (Cloaks are
  ///    exempt; a cloaked card hides its color).
  ///  - Cloaked cards are hidden: they impose no constraints at all, so a
  ///    row of cloaked cards accepts any card.
  static bool canPlaceInRow(
      Forest forest, int row, PlaceSide side, GameCard card) {
    if (card.isCloak) return false; // Cloaks only cover Talismans.
    final slots = forest.rows[row];
    for (final slot in slots) {
      if (!slot.isCloaked && slot.card.rowKey == card.rowKey) return false;
    }
    if (slots.isEmpty) return true;
    final edge = side == PlaceSide.left ? slots.first : slots.last;
    if (!edge.isCloaked && edge.card.color == card.color) return false;
    if (card.isTalisman) {
      final n = card.number!;
      for (final slot in slots) {
        if (slot.card.isTalisman && !slot.isCloaked) {
          final other = slot.card.number!;
          if (side == PlaceSide.left && n >= other) return false;
          if (side == PlaceSide.right && n <= other) return false;
        }
      }
    }
    return true;
  }

  /// Every legal placement for [card] in [forest].
  static List<PlacementOption> placements(Forest forest, GameCard card) {
    if (card.isCloak) {
      return [
        for (final target in forest.cloakTargets) CloakPlacement(target.id),
      ];
    }
    final options = <PlacementOption>[];
    for (var r = 0; r < forest.rows.length; r++) {
      if (canPlaceInRow(forest, r, PlaceSide.left, card)) {
        options.add(RowPlacement(r, PlaceSide.left));
      }
      if (canPlaceInRow(forest, r, PlaceSide.right, card)) {
        options.add(RowPlacement(r, PlaceSide.right));
      }
    }
    if (forest.rows.length < maxRows) {
      options.add(const NewRowPlacement());
    }
    return options;
  }

  /// Whether [card] can be placed anywhere at all.
  static bool isPlayable(Forest forest, GameCard card) =>
      placements(forest, card).isNotEmpty;
}

/// A choice of which outside card a player takes during the pick-up phase.
class PickOption {
  const PickOption(this.row, this.side);
  final int row;
  final PlaceSide side;

  @override
  bool operator ==(Object other) =>
      other is PickOption && other.row == row && other.side == side;
  @override
  int get hashCode => Object.hash(row, side);
}

/// Outside slots (either end of any row) that hold a card. A single-card row
/// offers only one pick.
List<PickOption> pickOptions(Forest forest) {
  final options = <PickOption>[];
  for (var r = 0; r < forest.rows.length; r++) {
    final row = forest.rows[r];
    if (row.isEmpty) continue;
    options.add(PickOption(r, PlaceSide.left));
    if (row.length > 1) options.add(PickOption(r, PlaceSide.right));
  }
  return options;
}
