import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cards.dart';
import '../../game/commands.dart';
import '../../game/engine.dart';
import '../../game/rules.dart';
import '../../session/local_session.dart';
import '../app_state.dart';
import '../card_view.dart';
import '../icons.dart';
import '../theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.session,
    this.ownsSession = false,
  });

  final GameSession session;
  final bool ownsSession;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Pass & play: the seat that has been revealed on this device, or null
  /// while the "pass the device" interstitial is showing.
  int? _revealed;
  int _lastActing = -2;

  /// Engine events already processed by [_scanEvents].
  int _lastEventCount = 0;

  // Fly-to-destination animations for Vanish / Summon: the moved card
  // ghosts from its last seen spot and flies to its new home while the
  // real tree updates underneath.
  final Map<int, GlobalKey> _cardKeys = {};
  final Map<int, GlobalKey> _troveBoxKeys = {};
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _overlayKey = GlobalKey();
  final Map<int, Offset> _cardCenters = {};
  final Map<int, Offset> _troveCenters = {};
  Offset? _deckCenter;
  final Set<int> _flyingCards = {};
  final List<_Flight> _flights = [];

  GlobalKey _keyForCard(int id) => _cardKeys.putIfAbsent(id, () => GlobalKey());

  GlobalKey _keyForTrove(int player) =>
      _troveBoxKeys.putIfAbsent(player, () => GlobalKey());

  /// My most recently busted card, shown in the hand with a stamp until
  /// the timer expires.
  GameCard? _bustCard;
  Timer? _bustTimer;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _lastActing = widget.session.engine.acting ?? -1;
    _lastEventCount = widget.session.engine.events.length;
  }

  void _onSession() {
    final acting = widget.session.engine.acting ?? -1;
    if (acting != _lastActing) {
      _lastActing = acting;
      if (widget.session.isPassAndPlay) _revealed = null;
    }
    _scanEvents();
    if (mounted) setState(() {});
  }

  /// Watches new engine events and stamps the hand when I bust.
  void _scanEvents() {
    final events = _e.events;
    final n = events.length;
    if (n <= _lastEventCount) {
      _lastEventCount = n;
      return;
    }
    for (final ev in events.sublist(_lastEventCount, n)) {
      if (ev.type == EventType.vanish || ev.type == EventType.summon) {
        _spawnFlight(ev);
      }
      final mine =
          widget.session.isPassAndPlay || ev.player == widget.session.mySeat;
      if (!mine) continue;
      final busted =
          ev.type == EventType.bust ||
          (ev.type == EventType.cloak && ev.detail == 'discarded');
      if (busted && ev.card != null) {
        _bustCard = ev.card;
        _bustTimer?.cancel();
        _bustTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _bustCard = null);
        });
      }
    }
    _lastEventCount = n;
  }

  /// Makes a moved card (Vanish discard, Summon theft) fly from its last
  /// seen spot to its new home instead of teleporting.
  void _spawnFlight(GameEvent ev) {
    final card = ev.card;
    // Detail-less vanish/summon events only announce the action; the
    // card actually moves with a detail ('discards' / 'from ...').
    if (card == null || ev.detail == null || _flyingCards.contains(card.id)) {
      return;
    }
    final from = _cardCenters[card.id];
    final to = ev.type == EventType.summon
        ? _troveCenters[ev.player]
        : _deckCenter;
    if (from == null || to == null) return;
    _flyingCards.add(card.id);
    _flights.add(_Flight(card: card, from: from, to: to));
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _flyingCards.remove(card.id);
        _flights.removeWhere((f) => f.card.id == card.id);
      });
    });
  }

  /// Records each rendered trove card's and each trove box's center,
  /// relative to the flight overlay, so a flight can start exactly where
  /// the card currently sits.
  void _captureCenters() {
    if (!mounted) return;
    final root =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || !root.attached) return;
    final origin = root.localToGlobal(Offset.zero);
    void note(GlobalKey key, void Function(Offset) set) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      set(box.localToGlobal(box.size.center(Offset.zero)) - origin);
    }

    _cardCenters.clear();
    _troveCenters.clear();
    for (final e in _cardKeys.entries) {
      note(e.value, (o) => _cardCenters[e.key] = o);
    }
    for (final e in _troveBoxKeys.entries) {
      note(e.value, (o) => _troveCenters[e.key] = o);
    }
    _deckCenter = null;
    note(_deckKey, (o) => _deckCenter = o);
  }

  @override
  void dispose() {
    _bustTimer?.cancel();
    widget.session.removeListener(_onSession);
    if (widget.ownsSession) widget.session.dispose();
    super.dispose();
  }

  GameEngine get _e => widget.session.engine;
  bool get _canAct => widget.session.canAct;

  void _send(GameCommand c) {
    if (_canAct) widget.session.submit(c);
  }

  bool get _showPassVeil =>
      widget.session.isPassAndPlay && !_e.over && _revealed != _e.acting;

  // ------------------------------------------------------------------
  // Board
  // ------------------------------------------------------------------

  Set<int> get _placeEnds {
    final s = <int>{};
    for (final o in _e.pendingOptions) {
      if (o is RowPlacement) s.add(o.row * 2 + o.side.index);
    }
    return s;
  }

  Set<int> get _pickEnds {
    final s = <int>{};
    if (_e.phase == Phase.picking) {
      for (final o in pickOptions(_e.forest)) {
        s.add(o.row * 2 + o.side.index);
      }
    }
    return s;
  }

  Set<int> get _cloakTargets {
    final s = <int>{};
    for (final o in _e.pendingOptions) {
      if (o is CloakPlacement) s.add(o.targetId);
    }
    return s;
  }

  bool get _newRowOpen =>
      _e.phase == Phase.placing &&
      _e.pendingOptions.any((o) => o is NewRowPlacement);

  Widget _rowTile(ForestSlot slot, int row, int i, int len,
      {required double width}) {
    final placing = _e.phase == Phase.placing && _canAct;
    final picking = _e.phase == Phase.picking && _canAct;
    final isLeft = i == 0;
    final isRight = i == len - 1;
    final endKey = (isLeft || isRight)
        ? row * 2 + (isRight && len > 1 ? 1 : 0)
        : null;
    final endTappable =
        endKey != null &&
        ((placing && _placeEnds.contains(endKey)) ||
            (picking && _pickEnds.contains(endKey)));
    final side = (isRight && len > 1) ? PlaceSide.right : PlaceSide.left;
    final cloakTap =
        placing &&
        _e.pendingCard?.isCloak == true &&
        _cloakTargets.contains(slot.card.id);
    final tile = _CardTile(
      key: ValueKey('tnt-tile-${slot.card.id}'),
      card: slot.card,
      cloak: slot.cloak,
      width: width,
      glow: endTappable || cloakTap,
      onTap: endTappable
          ? () {
              if (placing) {
                _send(PlaceCmd(RowPlacement(row, side)));
              } else {
                _send(PickCmd(PickOption(row, side)));
              }
            }
          : cloakTap
          ? () => _send(PlaceCmd(CloakPlacement(slot.card.id)))
          : null,
    );
    if (!cloakTap) return tile;
    // A Cloak in hand can also be dragged onto a glowing Talisman.
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => _send(PlaceCmd(CloakPlacement(slot.card.id))),
      builder: (context, candidate, _) => _CardTile(
        key: ValueKey('tnt-tile-${slot.card.id}'),
        card: slot.card,
        cloak: slot.cloak,
        width: width,
        glow: cloakTap || candidate.isNotEmpty,
        onTap: () => _send(PlaceCmd(CloakPlacement(slot.card.id))),
      ),
    );
  }

  Widget _forestRow(int rowIndex) {
    final rows = _e.forest.rows;
    final present = rowIndex < rows.length && rows[rowIndex].isNotEmpty;
    final choosing = _e.phase == Phase.choosingRow && _canAct;
    final newOpen = !present && _newRowOpen;
    PlacementOption? leftDrop;
    PlacementOption? rightDrop;
    if (present && _e.phase == Phase.placing && _canAct) {
      for (final o in _e.pendingOptions) {
        if (o is RowPlacement && o.row == rowIndex) {
          if (o.side == PlaceSide.left) {
            leftDrop = o;
          } else {
            rightDrop = o;
          }
        }
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: choosing && present ? () => _send(PickRowCmd(rowIndex)) : null,
      child: Container(
        height: 74,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: TNTTheme.ink.withValues(
            alpha: (choosing && present) || newOpen ? 0.35 : 0.2,
          ),
          border: Border.all(
            color: (choosing && present) || newOpen
                ? TNTTheme.gold.withValues(alpha: 0.9)
                : TNTTheme.goldSoft.withValues(alpha: 0.25),
            width: (choosing && present) || newOpen ? 2 : 1,
          ),
        ),
        child: present
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final n = rows[rowIndex].length;
                  final slots =
                      (leftDrop != null ? 1 : 0) + (rightDrop != null ? 1 : 0);
                  // Rows can grow well past six tiles; shrink the tiles to
                  // fit the row instead of overflowing. Each tile costs its
                  // width plus 4px of _CardTile padding.
                  final w = math.max(
                    12.0,
                    math.min(
                      52.0,
                      (constraints.maxWidth - slots * 44.0 - 4.0 * n) / n,
                    ),
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leftDrop != null)
                        _DropSlot(
                          key: ValueKey('tnt-drop-${rowIndex}L'),
                          onAccept: () => _send(PlaceCmd(leftDrop!)),
                        ),
                      for (var i = 0; i < n; i++)
                        _rowTile(
                          rows[rowIndex][i],
                          rowIndex,
                          i,
                          n,
                          width: w,
                        ),
                      if (rightDrop != null)
                        _DropSlot(
                          key: ValueKey('tnt-drop-${rowIndex}R'),
                          onAccept: () => _send(PlaceCmd(rightDrop!)),
                        ),
                    ],
                  );
                },
              )
            : _newRowSlot(
                rowIndex: rowIndex,
                open: newOpen,
                choosing: choosing,
              ),
      ),
    );
  }

  /// An empty row: a drop (or tap) target while a new row may start,
  /// otherwise a quiet placeholder.
  Widget _newRowSlot({
    required int rowIndex,
    required bool open,
    required bool choosing,
  }) {
    if (!open) {
      return Center(
        child: Text(
          choosing ? '— empty row —' : '',
          style: const TextStyle(
            fontFamily: TNTTheme.fontSerif,
            fontStyle: FontStyle.italic,
            fontSize: 12,
            color: Colors.white38,
          ),
        ),
      );
    }
    void accept() => _send(const PlaceCmd(NewRowPlacement()));
    return GestureDetector(
      key: ValueKey('tnt-newrow-$rowIndex'),
      behavior: HitTestBehavior.opaque,
      onTap: accept,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (_) => accept(),
        builder: (context, candidate, _) {
          final hot = candidate.isNotEmpty;
          return Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: TNTTheme.gold.withValues(alpha: hot ? 0.3 : 0.10),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: TNTTheme.gold.withValues(alpha: hot ? 1 : 0.6),
                  width: hot ? 2.4 : 1.5,
                ),
                child: hot
                    ? const Center(
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: TNTTheme.goldSoft,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _forest() {
    return Column(
      key: const ValueKey('tnt-forest'),
      children: [for (var r = 0; r < 3; r++) _forestRow(r)],
    );
  }

  // ------------------------------------------------------------------
  // Hand: deck, drawn card, turn actions
  // ------------------------------------------------------------------

  bool get _myDrawTurn =>
      _canAct && (_e.phase == Phase.drawing || _e.phase == Phase.continuing);

  void _sendDraw() {
    if (_e.phase == Phase.drawing) _send(const DrawCmd());
    if (_e.phase == Phase.continuing) _send(const ContinueCmd());
  }

  /// The bottom bar: the pass / end-turn button on the left, my drawn card
  /// in the middle, and the face-down deck on the right.
  Widget _handBar() {
    final e = _e;
    GameCard? card;
    var busted = false;
    if (e.phase == Phase.placing && _canAct) card = e.pendingCard;
    if (card == null && _bustCard != null) {
      card = _bustCard;
      busted = true;
    }
    return Container(
      key: const ValueKey('tnt-hand'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: TNTTheme.deepTealDark.withValues(alpha: 0.45),
      child: Row(
        children: [
          _handActions(),
          const SizedBox(width: 10),
          Expanded(
            child: Center(
              child: card != null ? _hand(card, busted: busted) : _handEmpty(),
            ),
          ),
          const SizedBox(width: 12),
          _deck(),
        ],
      ),
    );
  }

  Widget _deck() {
    final e = _e;
    final count = e.drawPile.length;
    final active = _myDrawTurn;
    const w = 54.0;
    return GestureDetector(
      key: const ValueKey('tnt-deck'),
      behavior: HitTestBehavior.opaque,
      onTap: active ? _sendDraw : null,
      child: SizedBox(
        key: _deckKey,
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: w,
              height: w / 0.72 + 10,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (count >= 3)
                    Positioned(left: 6, top: 7, child: CardBack(width: w)),
                  if (count >= 2)
                    Positioned(left: 3, top: 3.5, child: CardBack(width: w)),
                  Positioned(
                    child: _DeckTop(count: count, active: active),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              active
                  ? (e.phase == Phase.continuing ? 'Draw again' : 'Draw')
                  : '$count cards',
              style: TextStyle(
                fontFamily: TNTTheme.fontUi,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active
                    ? TNTTheme.goldSoft
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// My drawn card: it flips face-down to face-up on arrival, drags onto a
  /// valid drop slot, and carries a BUST stamp when it cannot be played.
  Widget _hand(GameCard card, {required bool busted}) {
    final canDrag = !busted && _e.phase == Phase.placing && _canAct;
    final core = _FlipReveal(card: card, width: 78, busted: busted);
    if (!canDrag) return core;
    return Draggable<int>(
      data: card.id,
      feedback: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: CardView(card: card, width: 84),
      ),
      childWhenDragging: _handEmpty(),
      child: core,
    );
  }

  Widget _handEmpty() {
    const w = 78.0;
    return SizedBox(
      key: const ValueKey('tnt-hand-empty'),
      width: w,
      height: w / 0.72,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: TNTTheme.goldSoft.withValues(alpha: 0.35),
          width: 1.5,
          radius: 7,
        ),
        child: const Center(
          child: Text(
            'Draw a card',
            style: TextStyle(
              fontFamily: TNTTheme.fontSerif,
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }

  Widget _handActions() {
    final e = _e;
    return SizedBox(
      key: const ValueKey('tnt-turn-actions'),
      width: 92,
      child: _canAct && e.phase == Phase.continuing
          ? _GoldButton(
              label: 'End Turn',
              onTap: () => _send(const PassCmd()),
            )
          : null,
    );
  }

  /// The bust banner, shown while [_bustCard] is live.
  Widget _bustBanner() {
    final card = _bustCard;
    if (card == null) return const SizedBox.shrink();
    // The banner is purely informational and sits over the top forest row;
    // let taps pass through so it never blocks a pickup.
    return Positioned(
      top: 84,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: const Color(0xFF7A2222),
            borderRadius: BorderRadius.circular(12),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                card.isCloak
                    ? 'Busted! The Cloak is discarded — nothing to cloak. Your turn ends.'
                    : 'Busted! ${card.toString()} can\u2019t be played and is discarded. Your turn ends.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TNTTheme.fontTitle,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ------------------------------------------------------------------
  // Troves
  // ------------------------------------------------------------------

  /// Trove cards that are currently tappable for [phase] prompts.
  bool _troveTapTarget(GameCard c, int player) {
    final res = _e.resolution;
    if (res == null || _e.phase != Phase.resolving || !_canAct) return false;
    if (res.poisonTarget && player == res.holder) return true;
    if (res.summonTarget && player != res.holder) {
      final holder = _e.players[res.holder];
      final inHolderTrove = holder.trove.any((h) => identical(h, c));
      if (inHolderTrove) return false;
      return true;
    }
    if (res.vanish != null) {
      final v = res.vanish!;
      if (v.type != null && v.awaitingVictim == player) {
        return c.talisman == v.type;
      }
    }
    return false;
  }

  Widget _trove(int player) {
    final p = _e.players[player];
    final active = _e.acting == player && !_e.over;
    final cards = p.trove;
    return Container(
      key: _keyForTrove(player),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: TNTTheme.ink.withValues(alpha: active ? 0.6 : 0.35),
        border: Border.all(
          color: active
              ? TNTTheme.gold
              : TNTTheme.goldSoft.withValues(alpha: 0.3),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TNTTheme.fontTitle,
                    fontSize: 10,
                    color: active ? TNTTheme.goldSoft : TNTTheme.parchmentDark,
                  ),
                ),
              ),
              Text(
                '${p.score}',
                style: const TextStyle(
                  fontFamily: TNTTheme.fontDisplay,
                  fontSize: 11,
                  color: TNTTheme.gold,
                ),
              ),
            ],
          ),
          if (p.collections > 0)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${p.collections}× collection',
                style: const TextStyle(
                  fontFamily: TNTTheme.fontUi,
                  fontSize: 9,
                  color: TNTTheme.goldSoft,
                ),
              ),
            ),
          // The trove is a bottom-aligned card stack, like a fan of deck
          // cards: the latest card on top, the rest peeking beneath.
          Align(
            alignment: Alignment.bottomCenter,
            child: _troveStack(cards, player),
          ),
        ],
      ),
    );
  }

  /// A deck-style vertical stack: each card offsets a little lower, the
  /// top (last) card fully visible. Spreading compresses once the stack
  /// grows past eight cards.
  Widget _troveStack(List<GameCard> cards, int player) {
    const w = 37.0;
    final h = w / 0.72;
    final steps = cards.length - 1;
    final step = steps <= 0 ? 0.0 : h * 0.42 * (steps > 7 ? 7.0 / steps : 1.0);
    if (cards.isEmpty) {
      return const SizedBox(
        width: 37,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'empty',
            style: TextStyle(
              fontFamily: TNTTheme.fontSerif,
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: w,
      height: h + steps * step,
      child: Stack(
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              top: (cards.length - 1 - i) * step,
              left: 0,
              child: Opacity(
                opacity: _flyingCards.contains(cards[i].id) ? 0 : 1,
                child: _CardTile(
                  key: _keyForCard(cards[i].id),
                  card: cards[i],
                  width: w,
                  glow: _troveTapTarget(cards[i], player),
                  onTap: _troveTapTarget(cards[i], player)
                      ? () => _troveTap(cards[i], player)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _troveTap(GameCard c, int player) {
    final res = _e.resolution;
    if (res == null) return;
    if (res.poisonTarget) {
      _send(PoisonCmd(c.id));
    } else if (res.summonTarget) {
      _send(SummonCmd(player, c.id));
    } else if (res.vanish != null &&
        res.vanish!.type == c.talisman &&
        res.vanish!.awaitingVictim == player) {
      _send(VictimDiscardCmd(player, c.id));
    }
  }

  Widget _troves() {
    return ConstrainedBox(
      key: const ValueKey('tnt-troves'),
      constraints: const BoxConstraints(minHeight: 76),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [for (final p in _e.players) Expanded(child: _trove(p.id))],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Score bar
  // ------------------------------------------------------------------

  Widget _scoreBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: TNTTheme.deepTealDark.withValues(alpha: 0.85),
      child: Row(
        children: [
          for (final p in _e.players)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _e.acting == p.id && !_e.over
                      ? TNTTheme.gold.withValues(alpha: 0.35)
                      : Colors.transparent,
                  border: Border.all(
                    color: _e.acting == p.id && !_e.over
                        ? TNTTheme.gold
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      p.name.length > 9 ? '${p.name.substring(0, 9)}…' : p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TNTTheme.fontTitle,
                        fontSize: 10,
                        color: TNTTheme.parchment,
                      ),
                    ),
                    Text(
                      '${p.score} pts',
                      style: const TextStyle(
                        fontFamily: TNTTheme.fontDisplay,
                        fontSize: 10,
                        color: TNTTheme.goldSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Prompt
  // ------------------------------------------------------------------

  String _promptTitle() {
    final e = _e;
    final actor = e.acting;
    if (e.over) return 'The quest has ended.';
    if (actor == null) return 'Resolving the magic…';
    final name = e.players[actor].name;
    final mine =
        e.acting == widget.session.mySeat || widget.session.isPassAndPlay;
    switch (e.phase) {
      case Phase.drawing:
        return mine
            ? 'Your turn: touch the deck to draw.'
            : '$name is drawing…';
      case Phase.placing:
        final c = e.pendingCard;
        final where = c?.isCloak ?? false
            ? 'Drag it onto a glowing Talisman — or tap one.'
            : 'Drag it to a glowing outline in the forest — or tap one.';
        return c == null
            ? 'Place your card.'
            : '${mine ? 'Your' : '$name\'s'} card: ${c.toString()}.\n$where';
      case Phase.continuing:
        return '${mine ? 'Push your luck' : '$name decides'} — touch the deck to draw again, or end the turn.';
      case Phase.choosingRow:
        return '${mine ? 'Take a row' : '$name takes a row'} from the forest.';
      case Phase.picking:
        return '${mine ? 'Take one card' : '$name takes one card'} from the forest.';
      case Phase.resolving:
        return _resolutionTitle();
      case Phase.ended:
        return '';
    }
  }

  String _resolutionTitle() {
    final e = _e;
    final res = e.resolution;
    if (res == null) return 'Resolving the magic…';
    final holderName = e.players[res.holder].name;
    final mine =
        e.acting == widget.session.mySeat || widget.session.isPassAndPlay;
    if (res.vanish != null) {
      final v = res.vanish!;
      final who = mine ? 'Your' : '$holderName\'s';
      if (v.type == null) {
        return '$who Vanish: choose which Talisman vanishes.';
      }
      final t = v.type!;
      final total = e.troveCountsExcept(v.holder)[t] ?? 0;
      final totalLine = '$who Vanish: '
          '$total ${t.label}${total == 1 ? '' : 's'} in opponents\' Troves';
      final victimIdx = v.awaitingVictim;
      if (victimIdx != null) {
        final victim = e.players[victimIdx];
        return '${victim.name} must discard a ${t.label} — tap a glowing card.\n'
            '$totalLine';
      }
      final next = v.victims[v.pos.clamp(0, v.victims.length - 1)];
      return '$totalLine.\nWaiting for ${e.players[next].name}…';
    }
    if (res.summonTarget) {
      return '${mine ? 'Your' : '$holderName\'s'} Summon: tap a card in another player\'s trove.';
    }
    if (res.poisonTarget) {
      return '${mine ? 'Your' : '$holderName\'s'} Poison: tap one of your own cards to discard.';
    }
    return 'Resolving the magic…';
  }

  /// One selection chip for a Vanish: the Talisman icon, its number and
  /// name, and how many of them sit in the opponents' Troves.
  Widget _vanishChip(GameEngine e, int holder, TalismanType t) {
    final count = e.troveCountsExcept(holder)[t] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: TNTTheme.deepTeal,
      ),
      child: Column(
        children: [
          TalismanIcon(
            type: t,
            size: 18,
            color: TNTTheme.parchment,
          ),
          Text(
            '${t.number} ${t.label}',
            style: const TextStyle(
              fontFamily: TNTTheme.fontUi,
              fontSize: 8,
              color: TNTTheme.parchment,
            ),
          ),
          Text(
            '× $count',
            style: TextStyle(
              fontFamily: TNTTheme.fontUi,
              fontSize: 9,
              color: count > 0
                  ? TNTTheme.gold
                  : TNTTheme.parchment.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prompt() {
    final e = _e;
    final res = e.resolution;
    final waiting = e.acting != null && !_canAct && !e.players[e.acting!].isBot;
    final botWaiting = e.acting != null && _e.players[e.acting!].isBot;
    // A pickup I must make gets a loud gold callout in place of the quiet
    // prompt: players missed the pickup before.
    if (e.phase == Phase.picking && _canAct) {
      return Padding(
        key: const ValueKey('tnt-prompt'),
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Material(
          color: TNTTheme.gold,
          borderRadius: BorderRadius.circular(12),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text(
                'PICK A CARD — tap a glowing card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TNTTheme.fontTitle,
                  fontSize: 14,
                  letterSpacing: 1,
                  color: TNTTheme.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('tnt-prompt'),
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: TNTTheme.parchment.withValues(alpha: 0.94),
        border: Border.all(color: TNTTheme.goldSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (botWaiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TNTTheme.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Waiting for ${e.players[e.acting!].name}…',
                      style: const TextStyle(
                        fontFamily: TNTTheme.fontSerif,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: TNTTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Waiting for ${e.players[e.acting!].name}…',
                style: const TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
          Text(
            _promptTitle(),
            style: const TextStyle(
              fontFamily: TNTTheme.fontSerif,
              fontSize: 13,
              color: TNTTheme.ink,
              height: 1.3,
            ),
          ),
          if (e.phase == Phase.resolving &&
              _canAct &&
              res != null &&
              res.vanish != null &&
              res.vanish!.type == null) ...[
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final t in TalismanType.values)
                    GestureDetector(
                      onTap: () => _send(VanishTypeCmd(t)),
                      child: _vanishChip(e, res.holder, t),
                    ),
                ],
              ),
            ),
          ],
          if (e.phase == Phase.resolving &&
              _canAct &&
              res != null &&
              res.vanish != null &&
              res.vanish!.type != null &&
              res.vanish!.awaitingVictim == widget.session.mySeat)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Tap a glowing card in your trove below.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontUi,
                  fontSize: 11,
                  color: TNTTheme.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Overlays
  // ------------------------------------------------------------------

  Widget _passVeil() {
    final actor = _e.acting!;
    final name = _e.players[actor].name;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: TNTTheme.deepTeal,
              border: Border.all(color: TNTTheme.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The Witching Hour Passes',
                  style: TextStyle(
                    fontFamily: TNTTheme.fontTitle,
                    fontSize: 18,
                    color: TNTTheme.goldSoft,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pass the device to $name',
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontSize: 15,
                    color: TNTTheme.parchment,
                  ),
                ),
                const SizedBox(height: 18),
                _GoldButton(
                  label: "I'm $name — reveal",
                  onTap: () => setState(() => _revealed = actor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final ranked = [..._e.players]..sort((a, b) => b.score.compareTo(a.score));
    final top = ranked.first.score;
    final winners = ranked
        .where((p) => p.score == top)
        .map((p) => p.name)
        .toList();
    final myScore = widget.session.mySeat >= 0
        ? _e.players[widget.session.mySeat].score
        : null;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: TNTTheme.parchment,
              border: Border.all(color: TNTTheme.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Midnight Falls',
                  style: TextStyle(
                    fontFamily: TNTTheme.fontTitle,
                    fontSize: 22,
                    color: TNTTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  winners.length == 1
                      ? '$winners.first prevails!'
                      : '${winners.join(' and ')} prevail in a tie!',
                  style: const TextStyle(
                    fontFamily: TNTTheme.fontSerif,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    color: TNTTheme.ink,
                  ),
                ),
                const SizedBox(height: 14),
                for (final p in ranked)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          p.score == top ? Icons.star : Icons.star_border,
                          size: 18,
                          color: p.score == top
                              ? TNTTheme.gold
                              : TNTTheme.parchmentDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.name}${p.id == widget.session.mySeat ? ' (you)' : ''}',
                            style: const TextStyle(
                              fontFamily: TNTTheme.fontTitle,
                              fontSize: 13,
                              color: TNTTheme.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${p.score} pts · ${p.collections}× collection',
                          style: const TextStyle(
                            fontFamily: TNTTheme.fontUi,
                            fontSize: 12,
                            color: TNTTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (myScore != null && myScore != top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Next time, bolder.',
                      style: const TextStyle(
                        fontFamily: TNTTheme.fontSerif,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: TNTTheme.ink,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.ownsSession) ...[
                      _GoldButton(
                        label: 'Play Again',
                        onTap: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                    _GoldButton(
                      label: 'Exit',
                      onTap: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final err = widget.session.errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureCenters());
    return TntScaffold(
      appBar: AppBar(
        title: const Text('Toil & Troublez'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (widget.ownsSession) {
                widget.session.leave();
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _scoreBar(),
                Expanded(child: SingleChildScrollView(child: _forest())),
                _prompt(),
                _handBar(),
                _troves(),
              ],
            ),
            if (err != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Material(
                  color: const Color(0xFF7A2222),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.session.clearError(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        err,
                        style: const TextStyle(
                          fontFamily: TNTTheme.fontUi,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_bustCard != null) _bustBanner(),
            if (_e.over) _results(),
            if (_showPassVeil) _passVeil(),
            Positioned.fill(
              child: IgnorePointer(
                key: _overlayKey,
                child: Stack(
                  children: [
                    for (final f in _flights)
                      TweenAnimationBuilder<Offset>(
                        key: ValueKey('fly${f.card.id}'),
                        tween: Tween<Offset>(begin: f.from, end: f.to),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          final d = (f.from - f.to).distance;
                          final t = d == 0 ? 1.0 : (f.from - value).distance / d;
                          final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
                          return Positioned(
                            left: value.dx - 18.5,
                            top: value.dy - 25.7,
                            child: Opacity(
                              opacity: fade,
                              child: CardView(card: f.card, width: 37),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Card tile
// ----------------------------------------------------------------------

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.card,
    this.cloak,
    this.width = 52,
    this.glow = false,
    this.onTap,
  });

  final GameCard card;
  final GameCard? cloak;
  final double width;
  final bool glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: CardView(
        card: card,
        cloak: cloak,
        width: width,
        glow: glow,
      ),
    );
    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, child: tile);
  }
}

// ----------------------------------------------------------------------
// Gilded button
// ----------------------------------------------------------------------

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TNTTheme.gold,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TNTTheme.fontTitle,
              fontSize: 13,
              letterSpacing: 1,
              color: TNTTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Deck top: the uppermost card back with a count badge and a draw glow
// ----------------------------------------------------------------------

class _DeckTop extends StatelessWidget {
  const _DeckTop({required this.count, required this.active});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const w = 54.0;
    return Container(
      width: w,
      height: w / 0.72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.09),
        boxShadow: active
            ? [
                BoxShadow(
                  color: TNTTheme.gold.withValues(alpha: 0.75),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(1, 2),
                ),
              ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CardBack(width: w),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TNTTheme.gold,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TNTTheme.fontNumber,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TNTTheme.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Flip reveal: the drawn card turns over face-up in the hand
// ----------------------------------------------------------------------

class _FlipReveal extends StatefulWidget {
  const _FlipReveal({
    required this.card,
    required this.width,
    this.busted = false,
  });

  final GameCard card;
  final double width;
  final bool busted;

  @override
  State<_FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<_FlipReveal> {
  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    return TweenAnimationBuilder<double>(
      key: ValueKey('flip-${widget.card.id}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        Widget card = CardBack(width: w);
        if (t >= 0.5) {
          card = Stack(
            children: [
              CardView(card: widget.card, width: w),
              if (widget.busted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(w * 0.09),
                        border: Border.all(
                          color: const Color(0xFFB42318).withValues(alpha: 0.9),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB42318)
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BUST',
                              style: TextStyle(
                                fontFamily: TNTTheme.fontTitle,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        final s = t >= 0.5 ? (t - 0.5) * 2 : (0.5 - t) * 2;
        return Transform.scale(scaleX: math.max(s, 0.02), child: card);
      },
    );
  }
}

// ----------------------------------------------------------------------
// Drop slot: a dashed card outline at a valid drop point
// ----------------------------------------------------------------------

class _DropSlot extends StatelessWidget {
  const _DropSlot({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAccept,
      child: SizedBox(
        width: 44,
        height: 60,
        child: DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (_) {
            onAccept();
          },
          builder: (context, candidate, _) {
            final hot = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: TNTTheme.gold.withValues(alpha: hot ? 0.32 : 0.10),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: TNTTheme.gold.withValues(alpha: hot ? 1 : 0.45),
                  width: hot ? 2.4 : 1.6,
                ),
                child: hot
                    ? const Center(
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: TNTTheme.goldSoft,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Dashed border painter
// ----------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.width,
    this.radius = 7,
  });

  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        if (end > d) canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}

/// One in-flight card (Vanish discard / Summon theft) and its endpoints,
/// in flight-overlay coordinates.
class _Flight {
  const _Flight({required this.card, required this.from, required this.to});

  final GameCard card;
  final Offset from;
  final Offset to;
}
