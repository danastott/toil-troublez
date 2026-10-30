import 'dart:math';

import 'cards.dart';
import 'commands.dart';
import 'engine.dart';
import 'rules.dart';

/// Decides what a bot does at each decision point. Every heuristic is a pure
/// function of the engine state; [rng] gives each bot a stable personality.
class Bot {
  // TEMP(test-only): override the continue margin for both skilled & master.
  static double? testMarginOverride;
  static GameCommand decide(
      GameEngine e, int me, BotSkill skill, Random rng) {
    switch (e.phase) {
      case Phase.drawing:
        return const DrawCmd();
      case Phase.placing:
        return _place(e, me, skill, rng);
      case Phase.continuing:
        return _shouldContinue(e, me, skill, rng)
            ? const ContinueCmd()
            : const PassCmd();
      case Phase.choosingRow:
        return PickRowCmd(_pickRow(e, me, skill, rng));
      case Phase.picking:
        return PickCmd(_pickCard(e, me, skill, rng));
      case Phase.resolving:
        return _resolve(e, me, skill, rng);
      default:
        return const PassCmd();
    }
  }

  // ------------------------------------------------------------------
  // Placement (step 1)
  // ------------------------------------------------------------------

  /// Skilled occasionally makes a suboptimal choice ("slip"), Master never
  /// does. This is what qualitatively separates the two tiers.
  static double _slipChance(BotSkill skill) =>
      skill == BotSkill.skilled ? 0.15 : 0.0;

  static GameCommand _place(
      GameEngine e, int me, BotSkill skill, Random rng) {
    final options = e.pendingOptions;
    if (options.isEmpty) return const PassCmd();
    if (skill == BotSkill.amateur) {
      return PlaceCmd(options[rng.nextInt(options.length)]);
    }
    if (rng.nextDouble() < _slipChance(skill)) {
      return PlaceCmd(options[rng.nextInt(options.length)]);
    }
    var best = options.first;
    var bestScore = _placementScore(e, me, best);
    for (final opt in options.skip(1)) {
      var s = _placementScore(e, me, opt);
      if (s > bestScore) {
        bestScore = s;
        best = opt;
      }
    }
    return PlaceCmd(best);
  }

  /// Value of placing the pending card with [opt].
  static double _placementScore(GameEngine e, int me, PlacementOption opt) {
    final card = e.pendingCard!;
    final forest = e.forest;
    final trove = e.players[me].trove;
    if (opt is CloakPlacement) {
      final target = e.cardById(opt.targetId);
      if (target == null) return 2.0;
      return 2.0 + 10.0 * _collectionDelta(trove, [target]);
    }
    final rowIdx = opt is RowPlacement ? opt.row : -1;
    final rowCards = rowIdx >= 0
        ? [for (final s in forest.rows[rowIdx]) s.card]
        : <GameCard>[];
    if (!card.isTalisman) {
      // Placed magicians fire when the row is collected (presumably by us).
      return 1.0 + _magicianValueFor(e, me, card);
    }
    final after = [...rowCards, card];
    var score =
        after.where((c) => c.isTalisman).length.toDouble() +
            10.0 * _collectionDelta(trove, after);
    if (rowIdx >= 0) {
      // Keep building one row: pushes earlier placements toward the middle,
      // away from the pick-up phase.
      final own = after
          .where((c) => identical(c, card) || trove.any((t) => t.id == c.id))
          .length;
      score += own * 0.4;
    } else {
      score -= 0.2; // a fresh short row is the most exposed
    }
    return score;
  }

  // ------------------------------------------------------------------
  // Continue or pass (step 2)
  // ------------------------------------------------------------------

  static bool _shouldContinue(
      GameEngine e, int me, BotSkill skill, Random rng) {
    final remaining = e.drawPile;
    double pSafe;
    if (remaining.isEmpty) {
      pSafe = 0;
    } else {
      var ok = 0;
      for (final c in remaining) {
        if (Rules.isPlayable(e.forest, c)) ok++;
      }
      pSafe = ok / remaining.length;
    }
    if (pSafe <= 0) return false;
    final passValue = _bestRowValue(e, me, skill);
    switch (skill) {
      case BotSkill.amateur:
        // Pushes whenever it feels like it can, and busts a lot.
        return pSafe > 0.25 && rng.nextDouble() < 0.5;
      case BotSkill.skilled:
        // Conservative EV play with a wide safety margin: it rarely busts but
        // passes early, and (unlike Master) it only counts marks, so it cannot
        // anticipate a 10-mark Collection.
        return pSafe * (passValue + 1.0) > passValue + 0.8;
      case BotSkill.master:
        // Margin tuned to peak the win-rate sweep (~0.55): pushes while tempo
        // is worth it, backs off as bust risk climbs, and (via collection-
        // aware row value) sees the bonus a near-complete Collection is worth.
        return pSafe * (passValue + 1.0) > passValue + 0.55;
    }
  }

  static double _bestRowValue(GameEngine e, int me, BotSkill skill) {
    var best = 0.0;
    for (var r = 0; r < e.forest.rows.length; r++) {
      final v = _rowValue(e, me, r, skill);
      if (v > best) best = v;
    }
    return best;
  }

  /// Value of passing on row [r] and collecting it. Master sees the
  /// collection bonuses; Skilled only counts marks, so it cannot anticipate a
  /// 10-mark Collection and plays a level below Master.
  static double _rowValue(GameEngine e, int me, int r, BotSkill skill) {
    final rowCards = e.forest.rowCards(r);
    final trove = e.players[me].trove;
    final talismans = rowCards.where((c) => c.isTalisman).toList();
    var v = talismans.length.toDouble();
    if (skill == BotSkill.master) {
      v += 10.0 * _collectionDelta(trove, rowCards);
      for (final c in rowCards) {
        if (c.magician != null && !c.isCloak) {
          v += 0.3 + _magicianValueFor(e, me, c) * 0.3;
        }
      }
    }
    if (skill != BotSkill.amateur) {
      // Outside cards may be stolen during the pick-up phase.
      v -= 0.1 * talismans.length * (e.players.length - 1);
    }
    return v;
  }

  static int _pickRow(
      GameEngine e, int me, BotSkill skill, Random rng) {
    final rows = e.forest.rows;
    if (rows.isEmpty) return 0;
    if (skill == BotSkill.amateur) {
      if (rng.nextDouble() < 0.25) {
        return rng.nextInt(rows.length);
      }
      // Amateur just wants the biggest row.
      var best = 0;
      for (var r = 1; r < rows.length; r++) {
        if (rows[r].length > rows[best].length) best = r;
      }
      return best;
    }
    if (rng.nextDouble() < _slipChance(skill)) {
      return rng.nextInt(rows.length);
    }
    var best = 0;
    var bestV = _rowValue(e, me, 0, skill);
    for (var r = 1; r < rows.length; r++) {
      final v = _rowValue(e, me, r, skill);
      if (v > bestV) {
        bestV = v;
        best = r;
      }
    }
    return best;
  }

  // ------------------------------------------------------------------
  // Pick-up phase (step 4)
  // ------------------------------------------------------------------

  static PickOption _pickCard(
      GameEngine e, int me, BotSkill skill, Random rng) {
    final options = e.pendingPicks;
    if (options.isEmpty) return const PickOption(0, PlaceSide.left);
    if (skill == BotSkill.amateur) {
      return options[rng.nextInt(options.length)];
    }
    if (rng.nextDouble() < _slipChance(skill)) {
      return options[rng.nextInt(options.length)];
    }
    var best = options.first;
    var bestScore = -1e9;
    for (final opt in options) {
      final s = _pickupScore(e, me, opt);
      if (s > bestScore) {
        bestScore = s;
        best = opt;
      }
    }
    return best;
  }

  static double _pickupScore(GameEngine e, int me, PickOption opt) {
    final row = e.forest.rows[opt.row];
    final slot = row[opt.side == PlaceSide.left ? 0 : row.length - 1];
    final card = slot.card;
    final trove = e.players[me].trove;
    if (slot.isCloaked) {
      // The covered Talisman's type is hidden; worth its mark only.
      return 1.0;
    }
    if (card.isTalisman) {
      return 1.0 + 10.0 * _collectionDelta(trove, [card]);
    }
    switch (card.magician!) {
      case MagicianKind.vanish:
        // Vanish has no fixed type: score by how many opponents hold the
        // most common type.
        var bestType = 0;
        for (final t in TalismanType.values) {
          var n = 0;
          for (var i = 0; i < e.players.length; i++) {
            if (i != me &&
                e.players[i].trove.any((c) => c.talisman == t)) {
              n++;
            }
          }
          if (n > bestType) bestType = n;
        }
        return 0.3 * bestType;
      case MagicianKind.summon:
        var steal = 0.0;
        for (var i = 0; i < e.players.length; i++) {
          if (i == me) continue;
          for (final c in e.players[i].trove) {
            final s = 1.0 + 10.0 * _collectionDelta(trove, [c]);
            if (s > steal) steal = s;
          }
        }
        return steal;
      case MagicianKind.poison:
        // Must discard one of my own: -1 mark, slightly better if I can
        // dump from a large pile.
        final counts = _countsByType(trove);
        final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
        return -1.0 + (maxCount >= 2 ? 0.3 : 0.0);
      case MagicianKind.cloak:
        return 0.0;
    }
  }

  // ------------------------------------------------------------------
  // Master Magician resolution
  // ------------------------------------------------------------------

  static GameCommand _resolve(
      GameEngine e, int me, BotSkill skill, Random rng) {
    final res = e.resolution!;
    final v = res.vanish;
    if (v != null) {
      if (v.type == null && res.actingPlayer == me) {
        // Choose the type to Vanish.
        if (skill == BotSkill.amateur) {
          return VanishTypeCmd(TalismanType.values[rng.nextInt(5)]);
        }
        var best = TalismanType.toad;
        var bestScore = -1.0;
        for (final t in TalismanType.values) {
          var s = 0.0;
          for (final victim in v.victims) {
            final n = e.players[victim]
                .trove
                .where((c) => c.talisman == t)
                .length;
            if (n > 0) {
              s += n;
              if (n == 3) s += 1.5; // break a near-quad
            }
          }
          if (s > bestScore) {
            bestScore = s;
            best = t;
          }
        }
        return VanishTypeCmd(best);
      }
      if (v.awaitingVictim == me) {
        final matching =
            e.players[me].trove.where((c) => c.talisman == v.type).toList();
        if (matching.isEmpty) return const PassCmd();
        GameCard chosen;
        if (skill == BotSkill.amateur) {
          chosen = matching[rng.nextInt(matching.length)];
        } else {
          final counts = _countsByType(e.players[me].trove);
          var bestCount = 1 << 30;
          chosen = matching.first;
          for (final c in matching) {
            final n = counts[c.talisman!]!;
            if (n < bestCount) {
              bestCount = n;
              chosen = c;
            }
          }
        }
        return VictimDiscardCmd(me, chosen.id);
      }
    }
    if (res.summonTarget && res.actingPlayer == me) {
      final holder = res.holder;
      final options = <(int, GameCard)>[
        for (var i = 0; i < e.players.length; i++)
          if (i != holder)
            for (final c in e.players[i].trove)
              if (c.isTalisman)
                (i, c),
      ];
      if (options.isEmpty) {
        // Engine should not wait on an empty target set; be safe.
        return const PassCmd();
      }
      if (skill == BotSkill.amateur) {
        final pick = options[rng.nextInt(options.length)];
        return SummonCmd(pick.$1, pick.$2.id);
      }
      final trove = e.players[holder].trove;
      var best = options.first;
      var bestScore = -1e9;
      for (final (player, card) in options) {
        var s = 1.0 + 10.0 * _collectionDelta(trove, [card]);
        if (skill == BotSkill.master) {
          // Also value breaking a near-quad of the victim's.
          final counts = _countsByType(e.players[player].trove);
          if (counts[card.talisman!] == 3) s += 1.5;
        }
        if (s > bestScore) {
          bestScore = s;
          best = (player, card);
        }
      }
      return SummonCmd(best.$1, best.$2.id);
    }
    if (res.poisonTarget && res.actingPlayer == me) {
      final trove = e.players[me].trove;
      if (trove.isEmpty) return const PassCmd();
      if (skill == BotSkill.amateur) {
        return PoisonCmd(trove[rng.nextInt(trove.length)].id);
      }
      final counts = _countsByType(trove);
      var chosen = trove.first;
      var bestKey = (counts[chosen.talisman!]!, -chosen.number!);
      for (final c in trove) {
        final key = (counts[c.talisman!]!, -c.number!);
        if (key.$1 < bestKey.$1 ||
            (key.$1 == bestKey.$1 && key.$2 > bestKey.$2)) {
          bestKey = key;
          chosen = c;
        }
      }
      return PoisonCmd(chosen.id);
    }
    return const PassCmd();
  }

  // ------------------------------------------------------------------
  // Shared helpers
  // ------------------------------------------------------------------

  static Map<TalismanType, int> _countsByType(List<GameCard> cards) {
    final m = <TalismanType, int>{
      for (final t in TalismanType.values)
        t: 0,
    };
    for (final c in cards) {
      if (c.talisman != null) m[c.talisman!] = (m[c.talisman!] ?? 0) + 1;
    }
    return m;
  }

  /// How many Collections this multiset of Talismans would complete
  /// (quads first, then full sets), mirroring the engine.
  static int _collectionsOf(Map<TalismanType, int> counts) {
    final c = Map<TalismanType, int>.from(counts);
    var total = 0;
    while (true) {
      var formed = false;
      for (final t in TalismanType.values) {
        if (c[t]! >= 4) {
          c[t] = c[t]! - 4;
          total++;
          formed = true;
          break;
        }
      }
      if (!formed && c.values.every((n) => n > 0)) {
        for (final t in TalismanType.values) {
          c[t] = c[t]! - 1;
        }
        total++;
        formed = true;
      }
      if (!formed) break;
    }
    return total;
  }

  /// Collections gained when [extra] is added to [trove].
  static int _collectionDelta(List<GameCard> trove, List<GameCard> extra) {
    return _collectionsOf(_countsByType([...trove, ...extra])) -
        _collectionsOf(_countsByType(trove));
  }

  /// What a placed (row-collected) Magician is worth to [me].
  static double _magicianValueFor(GameEngine e, int me, GameCard card) {
    final kind = card.magician!;
    if (kind == MagicianKind.cloak) return 0;
    if (kind == MagicianKind.poison) {
      return e.players[me].trove.isEmpty ? 0.0 : -1.0;
    }
    if (kind == MagicianKind.vanish) {
      var bestType = 0.0;
      for (final t in TalismanType.values) {
        var n = 0.0;
        for (var i = 0; i < e.players.length; i++) {
          if (i == me) continue;
          n += e.players[i].trove.where((c) => c.talisman == t).length;
        }
        if (n > bestType) bestType = n;
      }
      return 0.3 * bestType;
    }
    // Summon: the best steal available.
    final trove = e.players[me].trove;
    var steal = 0.0;
    for (var i = 0; i < e.players.length; i++) {
      if (i == me) continue;
      for (final c in e.players[i].trove) {
        final s = 1.0 + 10.0 * _collectionDelta(trove, [c]);
        if (s > steal) steal = s;
      }
    }
    return steal;
  }
}