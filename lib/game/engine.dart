import 'dart:math';

import 'cards.dart';
import 'commands.dart';
import 'rules.dart';

/// A player at the table.
class Player {
  Player({required this.id, required this.name, this.isBot = false, this.skill});

  final int id;
  String name;
  bool isBot;
  BotSkill? skill;

  /// Live Talisman cards, kept sorted face up by number. Completed
  /// Collections become markers, tracked in [collections].
  final List<GameCard> trove = [];
  int collections = 0;

  int get score => collections * 10 + trove.length;
}

/// What the engine is currently waiting for.
enum Phase {
  drawing, // the current player draws a card; passing is not an option
  placing, // the current player places the drawn card
  continuing, // the current player chooses to draw again or pass
  choosingRow, // the current player chooses a row to collect
  picking, // the next player in clockwise order picks up an outside card
  resolving, // a Master Magician action awaits a decision
  ended,
}

/// Events, surfaced to the UI for animation and narration.
enum EventType {
  draw,
  place,
  cloak,
  bust,
  pass,
  rowCollect,
  pickup,
  vanish,
  summon,
  poison,
  collection,
  reshuffle,
  deckEmpty,
  turn,
  gameOver,
}

class GameEvent {
  GameEvent(this.type,
      {this.player, this.card, this.row, this.detail, this.other});

  final EventType type;
  final int? player; // player index
  final GameCard? card;
  final int? row;
  final String? detail;

  /// A second player the event concerns (e.g. the Vanish holder when a
  /// victim discards, or the source player of a Summon), or null.
  final int? other;
}

class GameEngine {
  GameEngine({required List<Player> players, required int seed})
      : players = players,
        seed = seed,
        current = Random(seed + 77).nextInt(players.length) {
    assert(players.length >= 2 && players.length <= 6);
    _cards = Deck.build(seed);
    _byId = {for (final c in _cards) c.id: c};
    drawPile = List.of(_cards);
  }

  /// Private: builds only the deck; [GameEngine.fromSave] fills in the
  /// remaining state.
  GameEngine._(List<Player> players, int seed)
      : players = players,
        seed = seed,
        current = 0 {
    _cards = Deck.build(seed);
    _byId = {for (final c in _cards) c.id: c};
    drawPile = List.of(_cards);
  }

  final int seed;
  final List<Player> players;
  late final List<GameCard> _cards;
  late final Map<int, GameCard> _byId;
  late List<GameCard> drawPile;
  final List<GameCard> discardPile = [];
  final Forest forest = Forest();
  int depletions = 0;

  /// 2-3 players end on the first depletion, 4-5 after one reshuffle,
  /// 6 after two.
  int get maxReshuffles =>
      players.length <= 3 ? 0 : players.length <= 5 ? 1 : 2;

  int current;
  Phase phase = Phase.drawing;

  // Placement of the just-drawn card.
  GameCard? pendingCard;
  List<PlacementOption> pendingOptions = const [];

  // Pick-up phase.
  int _pickupIdx = 0;
  List<PickOption> pendingPicks = const [];

  // Master Magician resolution.
  Resolution? resolution;

  final List<GameEvent> events = [];
  List<int> winners = const [];

  /// Resolves a card by its stable id. The deck is shuffled, so this is the
  /// only safe id lookup.
  GameCard? cardById(int id) => _byId[id];

  /// The player index whose decision the engine awaits, if any.
  int? get acting {
    switch (phase) {
      case Phase.drawing:
      case Phase.placing:
      case Phase.continuing:
      case Phase.choosingRow:
        return current;
      case Phase.picking:
        return _pickupIdx;
      case Phase.resolving:
        return resolution?.actingPlayer;
      default:
        return null;
    }
  }

  bool get over => phase == Phase.ended;

  void _emit(GameEvent e) => events.add(e);

  // ---------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------

  /// Applies a player command. Commands from a player who is not the one
  /// awaiting are ignored.
  void apply(GameCommand command, {int? byPlayer}) {
    if (over) return;
    if (byPlayer != null && acting != byPlayer) return;
    switch (command) {
      case DrawCmd():
        draw();
      case ContinueCmd():
        continueDraw();
      case PassCmd():
        pass();
      case PlaceCmd(:final option):
        place(option);
      case PickRowCmd(:final row):
        pickRow(row);
      case PickCmd(:final option):
        pick(option);
      case VanishTypeCmd(:final type):
        chooseVanishType(type);
      case VictimDiscardCmd(:final player, :final card):
        chooseVictimDiscard(player, card);
      case SummonCmd(:final from, :final card):
        chooseSummon(from, card);
      case PoisonCmd(:final card):
        choosePoisonDiscard(card);
    }
  }

  // ---------------------------------------------------------------------
  // Turn
  // ---------------------------------------------------------------------

  /// The current player draws the next card. If the card cannot be
  /// placed, they bust: the card is discarded, pickups begin, and the
  /// turn ends.
  void draw() {
    if (phase != Phase.drawing) return;
    _doDraw();
  }

  void _doDraw() {
    if (drawPile.isEmpty) {
      if (discardPile.isNotEmpty && depletions < maxReshuffles) {
        drawPile.addAll(discardPile);
        Deck.reshuffle(drawPile, seed, depletions);
        depletions++;
        _emit(GameEvent(EventType.reshuffle, player: current));
      } else {
        // The draw pile is exhausted for the final time: complete the
        // remaining steps of this turn, then the game ends.
        _ending = true;
        _emit(GameEvent(EventType.deckEmpty, player: current));
        if (forest.isEmpty) {
          beginPickups();
        } else {
          phase = Phase.choosingRow;
        }
        return;
      }
    }
    final card = drawPile.removeLast();
    _emit(GameEvent(EventType.draw, player: current, card: card));
    if (!Rules.isPlayable(forest, card)) {
      // A card that cannot be played ends the turn immediately.
      discardPile.add(card);
      _emit(GameEvent(
        card.isCloak ? EventType.cloak : EventType.bust,
        player: current,
        card: card,
        detail: 'discarded',
      ));
      beginPickups();
      return;
    }
    pendingCard = card;
    pendingOptions = Rules.placements(forest, card);
    phase = Phase.placing;
  }

  void place(PlacementOption option) {
    if (phase != Phase.placing || !pendingOptions.contains(option)) return;
    final card = pendingCard!;
    if (card.isCloak) {
      final target = _byId[(option as CloakPlacement).targetId]!;
      forest.cloakCard(target, card);
      _emit(GameEvent(EventType.cloak, player: current, card: card));
    } else if (option is NewRowPlacement) {
      forest.startRow(card);
      _emit(GameEvent(EventType.place, player: current, card: card));
    } else {
      final rp = option as RowPlacement;
      forest.placeAt(rp.row, rp.side, card);
      _emit(GameEvent(EventType.place,
          player: current, card: card, row: rp.row));
    }
    pendingCard = null;
    pendingOptions = const [];
    phase = Phase.continuing;
  }

  /// Ends the turn after at least one placement: the player stops pushing
  /// their luck. Passing without drawing is not allowed — the first card
  /// of a turn is mandatory (rulebook p. 5).
  void pass() {
    if (phase != Phase.continuing) return;
    _emit(GameEvent(EventType.pass, player: current));
    if (forest.isEmpty) {
      // Nothing to collect: the turn ends outright.
      endTurn();
    } else {
      phase = Phase.choosingRow;
    }
  }

  /// Push your luck: draw another card immediately after a placement.
  void continueDraw() {
    if (phase != Phase.continuing) return;
    _doDraw();
  }

  void pickRow(int row) {
    if (phase != Phase.choosingRow || row < 0 || row >= forest.rows.length) {
      return;
    }
    _emit(GameEvent(EventType.rowCollect, player: current, row: row));
    final actions = [
      for (final slot in forest.rows[row])
        if (slot.card.magician != null && !slot.card.isCloak) slot.card,
    ];
    resolution = Resolution(
      queue: actions,
      pickedCard: null,
      row: row,
      holder: current,
      mode: ResolutionMode.rowCollect,
    );
    _advanceResolution();
  }

  // ---------------------------------------------------------------------
  // Pick-up phase (step 4)
  // ---------------------------------------------------------------------

  void beginPickups() {
    _pickupIdx = (current + 1) % players.length;
    _advancePickup();
  }

  void _advancePickup() {
    if (_ending && forest.isEmpty) {
      endTurn();
      return;
    }
    if (_pickupIdx == current || forest.isEmpty) {
      endTurn();
      return;
    }
    pendingPicks = pickOptions(forest);
    if (pendingPicks.isEmpty) {
      endTurn();
      return;
    }
    phase = Phase.picking;
  }

  void pick(PickOption option) {
    if (phase != Phase.picking || !pendingPicks.contains(option)) return;
    final rowSlots = forest.rows[option.row];
    final slot = rowSlots.removeAt(
        option.side == PlaceSide.left ? 0 : rowSlots.length - 1);
    final card = slot.card;
    if (slot.cloak != null) discardPile.add(slot.cloak!);
    final taker = _pickupIdx;
    _emit(GameEvent(EventType.pickup, player: taker, card: card));
    if (card.isTalisman) {
      players[taker].trove.add(card);
      _sortTrove(taker);
      _completeCollections(taker);
      _pruneRows();
      _advanceAfterPick();
    } else {
      // A picked-up Master Magician resolves its action, then is discarded.
      resolution = Resolution(
        queue: [card],
        pickedCard: card,
        row: option.row,
        holder: taker,
        mode: ResolutionMode.pickup,
      );
      _advanceResolution();
    }
  }

  void _advanceAfterPick() {
    _pickupIdx = (_pickupIdx + 1) % players.length;
    _advancePickup();
  }

  void _pruneRows() {
    forest.rows.removeWhere((r) => r.isEmpty);
  }

  // ---------------------------------------------------------------------
  // Master Magician resolution
  // ---------------------------------------------------------------------

  void _advanceResolution() {
    final res = resolution;
    if (res == null) return;
    if (res.queue.isEmpty) {
      _finishResolution(res);
      return;
    }
    final card = res.queue.removeAt(0);
    final holder = res.holder;
    switch (card.magician!) {
      case MagicianKind.vanish:
        res.vanish = VanishState(holder: holder);
        _emit(GameEvent(EventType.vanish, player: holder, card: card));
        phase = Phase.resolving;
      case MagicianKind.summon:
        _emit(GameEvent(EventType.summon, player: holder, card: card));
        final targets = [
          for (var i = 0; i < players.length; i++)
            if (i != holder && players[i].trove.isNotEmpty) i,
        ];
        if (targets.isEmpty) {
          res.summonTarget = false;
          _advanceResolution();
        } else {
          res.summonTarget = true;
          phase = Phase.resolving;
        }
      case MagicianKind.poison:
        if (players[holder].trove.isEmpty) {
          res.poisonTarget = false;
          _advanceResolution();
        } else {
          res.poisonTarget = true;
          _emit(GameEvent(EventType.poison, player: holder, card: card));
          phase = Phase.resolving;
        }
      case MagicianKind.cloak:
        // Cloak powers only trigger on placement, never on pick-up.
        _advanceResolution();
    }
  }

  void _finishResolution(Resolution res) {
    final holder = res.holder;
    if (res.mode == ResolutionMode.rowCollect) {
      final rowSlots = List<ForestSlot>.of(forest.rows[res.row]);
      for (final slot in rowSlots) {
        if (slot.cloak != null) discardPile.add(slot.cloak!);
        if (slot.card.isTalisman) {
          players[holder].trove.add(slot.card);
        } else {
          discardPile.add(slot.card);
        }
      }
      forest.rows[res.row].clear();
      _pruneRows();
      _sortTrove(holder);
      _emit(GameEvent(EventType.rowCollect, player: holder, detail: 'collected'));
      _completeCollections(holder);
      resolution = null;
      beginPickups();
    } else {
      // A single card picked up from the Forest: discard it, keep going.
      if (res.pickedCard != null) discardPile.add(res.pickedCard!);
      resolution = null;
      _pruneRows();
      _advanceAfterPick();
    }
  }

  /// How many cards of each Talisman type sit in every Trove except
  /// [player]'s. Used to show what a Vanish would reach before it resolves.
  Map<TalismanType, int> troveCountsExcept(int player) {
    final counts = {for (final t in TalismanType.values) t: 0};
    for (var i = 0; i < players.length; i++) {
      if (i == player) continue;
      for (final c in players[i].trove) {
        if (c.isTalisman) counts[c.talisman!] = (counts[c.talisman!] ?? 0) + 1;
      }
    }
    return counts;
  }

  void chooseVanishType(TalismanType type) {
    final res = resolution;
    final v = res?.vanish;
    if (res == null || v == null || v.type != null || phase != Phase.resolving) {
      return;
    }
    v.type = type;
    v.victims = [
      for (var i = 0; i < players.length; i++)
        if (i != v.holder &&
            players[i].trove.any((c) => c.talisman == type))
          i,
    ];
    v.pos = 0;
    _emit(GameEvent(
        EventType.vanish, player: v.holder, detail: 'chose ${type.label}'));
    _advanceVictims(res);
  }

  void _advanceVictims(Resolution res) {
    final v = res.vanish!;
    if (v.pos >= v.victims.length) {
      res.vanish = null;
      _advanceResolution();
      return;
    }
    final victim = v.victims[v.pos];
    final matching =
        players[victim].trove.where((c) => c.talisman == v.type).toList();
    if (matching.length == 1) {
      players[victim].trove.remove(matching.first);
      discardPile.add(matching.first);
      _emit(GameEvent(EventType.vanish,
          player: victim,
          card: matching.first,
          other: v.holder,
          detail: 'discards'));
      v.pos++;
      _advanceVictims(res);
    } else {
      v.awaitingVictim = victim;
      phase = Phase.resolving;
    }
  }

  void chooseVictimDiscard(int playerId, int cardId) {
    final res = resolution;
    final v = res?.vanish;
    if (res == null ||
        v == null ||
        v.awaitingVictim != playerId ||
        phase != Phase.resolving) {
      return;
    }
    final card = _byId[cardId];
    final trove = players[playerId].trove;
    if (card == null || !trove.any((c) => c.id == cardId) || card.talisman != v.type) return;
    trove.removeWhere((c) => c.id == cardId);
    discardPile.add(card);
      _emit(GameEvent(EventType.vanish,
          player: playerId,
          card: card,
          other: res.holder,
          detail: 'discards'));
    v.pos++;
    v.awaitingVictim = null;
    _advanceVictims(res);
  }

  void chooseSummon(int fromPlayer, int cardId) {
    final res = resolution;
    if (res == null || !res.summonTarget || phase != Phase.resolving) return;
    final holder = res.holder;
    if (fromPlayer == holder ||
        fromPlayer < 0 ||
        fromPlayer >= players.length) {
      return;
    }
    final card = _byId[cardId];
    if (card == null || !card.isTalisman) {
      return;
    }
    final from = players[fromPlayer].trove;
    if (!from.any((c) => c.id == cardId)) return;
    from.removeWhere((c) => c.id == cardId);
    _sortTrove(fromPlayer);
    players[holder].trove.add(card);
    _sortTrove(holder);
    _emit(GameEvent(EventType.summon,
        player: holder,
        card: card,
        other: fromPlayer,
        detail: 'from ${players[fromPlayer].name}'));
    _completeCollections(holder);
    res.summonTarget = false;
    _advanceResolution();
  }

  void choosePoisonDiscard(int cardId) {
    final res = resolution;
    if (res == null || !res.poisonTarget || phase != Phase.resolving) return;
    final holder = res.holder;
    final trove = players[holder].trove;
    final card = _byId[cardId];
    if (card == null || !trove.any((c) => c.id == cardId)) return;
    trove.removeWhere((c) => c.id == cardId);
    discardPile.add(card);
    _sortTrove(holder);
    _emit(GameEvent(EventType.poison,
        player: holder, card: card, detail: 'discards'));
    res.poisonTarget = false;
    _advanceResolution();
  }

  // ---------------------------------------------------------------------
  // Collections & scoring
  // ---------------------------------------------------------------------

  void _sortTrove(int p) {
    players[p]
        .trove
        .sort((a, b) => a.number!.compareTo(b.number!));
  }

  /// Completes any Collections a player's Trove now contains. A Collection is
  /// one of each of the 5 Talismans or 4 of the same Talisman. Quads form
  /// first, then sets; repeats while the Trove still contains one.
  void _completeCollections(int p) {
    final pl = players[p];
    while (true) {
      final byType = <TalismanType, List<GameCard>>{
        for (final t in TalismanType.values)
          t: [for (final c in pl.trove) if (c.talisman == t) c],
      };
      var formed = false;
      for (final t in TalismanType.values) {
        final list = byType[t]!;
        if (list.length >= 4) {
          final quad = list.take(4).toList();
          for (final c in quad) {
            pl.trove.remove(c);
          }
          discardPile.addAll(quad.skip(1));
          pl.collections++;
          _emit(GameEvent(EventType.collection,
              player: p, card: quad.first, detail: '${t.label} x4'));
          formed = true;
          break;
        }
      }
      if (!formed && byType.values.every((l) => l.isNotEmpty)) {
        final set = byType.values.map((l) => l.first).toList();
        for (final c in set) {
          pl.trove.remove(c);
        }
        discardPile.addAll(set.skip(1));
        pl.collections++;
        _emit(GameEvent(EventType.collection,
            player: p, card: set.first, detail: 'full set'));
        formed = true;
      }
      if (!formed) break;
    }
  }

  // ---------------------------------------------------------------------
  // Turn & game end
  // ---------------------------------------------------------------------

  bool _ending = false;

  void endTurn() {
    if (_ending) {
      endGame();
      return;
    }
    current = (current + 1) % players.length;
    phase = Phase.drawing;
    _emit(GameEvent(EventType.turn, player: current));
  }

  void endGame() {
    phase = Phase.ended;
    var best = -1;
    for (final p in players) {
      if (p.score > best) {
        best = p.score;
      }
    }
    final top = <int>[];
    for (var i = 0; i < players.length; i++) {
      if (players[i].score == best) {
        top.add(i);
      }
    }
    if (top.length > 1) {
      var most = -1;
      for (final i in top) {
        if (players[i].collections > most) {
          most = players[i].collections;
        }
      }
      final tied = <int>[];
      for (final i in top) {
        if (players[i].collections == most) {
          tied.add(i);
        }
      }
      winners = tied;
    } else {
      winners = top;
    }
    _emit(GameEvent(EventType.gameOver));
  }

  // ---------------------------------------------------------------------
  // Save / restore
  // ---------------------------------------------------------------------

  /// Serializes the complete engine state for mid-game saves. Card
  /// references are stable ids; the deck is rebuilt from [seed] on
  /// restore.
  Map<String, Object?> toJson() => {
        'v': 1,
        'seed': seed,
        'current': current,
        'phase': phase.index,
        'depletions': depletions,
        'ending': _ending,
        'pendingCard': pendingCard?.id,
        'pendingOptions': [for (final o in pendingOptions) o.toSave()],
        'pickupIdx': _pickupIdx,
        'pendingPicks': [
          for (final p in pendingPicks) [p.row, p.side.index],
        ],
        'winners': [...winners],
        'drawPile': [for (final c in drawPile) c.id],
        'discardPile': [for (final c in discardPile) c.id],
        'forest': [
          for (final row in forest.rows)
            [for (final s in row) [s.card.id, s.cloak?.id]],
        ],
        'players': [
          for (final p in players)
            {
              'name': p.name,
              'bot': p.isBot,
              'skill': p.skill?.index,
              'trove': [for (final c in p.trove) c.id],
              'collections': p.collections,
            },
        ],
        'resolution': resolution?.toJson(),
      };

  /// Restores an engine from [toJson] output. The deck is deterministic
  /// in [seed]; the save carries the draw-pile order, forest and troves.
  factory GameEngine.fromSave(Map<String, Object?> j) {
    final playersJson = j['players']! as List;
    final players = [
      for (var i = 0; i < playersJson.length; i++)
        Player(
          id: i,
          name: (playersJson[i] as Map)['name'] as String,
          isBot: (playersJson[i] as Map)['bot'] as bool,
          skill: ((playersJson[i] as Map)['skill'] as int?) == null
              ? null
              : BotSkill.values[(playersJson[i] as Map)['skill'] as int],
        ),
    ];
    final e = GameEngine._(players, j['seed'] as int);
    final byId = e._byId;
    e.current = j['current'] as int;
    e.phase = Phase.values[j['phase'] as int];
    e.depletions = j['depletions'] as int;
    e._ending = j['ending'] as bool;
    final pc = j['pendingCard'] as int?;
    e.pendingCard = pc == null ? null : byId[pc];
    e.pendingOptions = [
      for (final m in (j['pendingOptions']! as List).cast<Map>())
        PlacementOption.fromSave(m),
    ];
    e._pickupIdx = j['pickupIdx'] as int;
    e.pendingPicks = [
      for (final m in (j['pendingPicks']! as List).cast<List>())
        PickOption(m[0] as int, PlaceSide.values[m[1] as int]),
    ];
    e.winners = List.of((j['winners']! as List).cast<int>());
    e.drawPile = [
      for (final id in (j['drawPile']! as List).cast<int>()) byId[id]!,
    ];
    e.discardPile.addAll([
      for (final id in (j['discardPile']! as List).cast<int>()) byId[id]!,
    ]);
    e.forest.rows
      ..clear()
      ..addAll([
        for (final row in (j['forest']! as List).cast<List>())
          [
            for (final m in row.cast<List>())
              ForestSlot(
                byId[m[0] as int]!,
                m[1] == null ? null : byId[m[1] as int]!,
              ),
          ],
      ]);
    for (var i = 0; i < e.players.length; i++) {
      final p = e.players[i];
      p.trove
        ..clear()
        ..addAll([
          for (final id in ((playersJson[i] as Map)['trove'] as List)
              .cast<int>())
            byId[id]!,
        ]);
      p.collections = (playersJson[i] as Map)['collections'] as int;
    }
    final r = j['resolution'] as Map?;
    if (r != null) e.resolution = Resolution.fromSave(r, byId);
    return e;
  }
}

/// In-flight Master Magician action resolution.
class Resolution {
  Resolution({
    required this.queue,
    required this.pickedCard,
    required this.row,
    required this.holder,
    required this.mode,
  });

  /// Action cards still to resolve, in row order (left to right).
  List<GameCard> queue;

  /// The single card picked up from the Forest (pickup mode); discarded
  /// once its action completes.
  GameCard? pickedCard;

  final int row;
  final int holder;
  final ResolutionMode mode;
  VanishState? vanish;
  bool summonTarget = false;
  bool poisonTarget = false;

  int? get actingPlayer {
    if (vanish != null) {
      if (vanish!.type == null) return holder;
      return vanish!.awaitingVictim;
    }
    if (summonTarget || poisonTarget) return holder;
    return null;
  }

  Map<String, Object?> toJson() => {
        'queue': [for (final c in queue) c.id],
        'pickedCard': pickedCard?.id,
        'row': row,
        'holder': holder,
        'mode': mode.index,
        'vanish': vanish?.toJson(),
        'summonTarget': summonTarget,
        'poisonTarget': poisonTarget,
      };

  factory Resolution.fromSave(Map m, Map<int, GameCard> byId) =>
      Resolution(
        queue: [
          for (final id in (m['queue'] as List).cast<int>()) byId[id]!,
        ],
        pickedCard: (m['pickedCard'] as int?) == null
            ? null
            : byId[m['pickedCard'] as int]!,
        row: m['row'] as int,
        holder: m['holder'] as int,
        mode: ResolutionMode.values[m['mode'] as int],
      )
        ..vanish = (m['vanish'] as Map?) == null
            ? null
            : VanishState.fromSave(m['vanish'] as Map)
        ..summonTarget = m['summonTarget'] as bool
        ..poisonTarget = m['poisonTarget'] as bool;
}

enum ResolutionMode { rowCollect, pickup }

class VanishState {
  VanishState({required this.holder});
  final int holder;
  TalismanType? type;
  List<int> victims = [];
  int pos = 0;
  int? awaitingVictim;

  Map<String, Object?> toJson() => {
        'holder': holder,
        'type': type?.index,
        'victims': [...victims],
        'pos': pos,
        'awaitingVictim': awaitingVictim,
      };

  factory VanishState.fromSave(Map m) => VanishState(
        holder: m['holder'] as int,
      )
        ..type = (m['type'] as int?) == null
            ? null
            : TalismanType.values[m['type'] as int]
        ..victims = List.of((m['victims'] as List).cast<int>())
        ..pos = m['pos'] as int
        ..awaitingVictim = m['awaitingVictim'] as int?;
}

/// Bot decision-making skill levels.
enum BotSkill { amateur, skilled, master }