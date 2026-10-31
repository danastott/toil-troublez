/// The three background colors of a card. Each is marked by one of the
/// three symbols (Sun, Moon, Star) on the card face.
enum CardColor {
  sun('Sun'),
  moon('Moon'),
  star('Star');

  const CardColor(this.label);
  final String label;
}

/// The four kinds of Master Magician action card.
enum MagicianKind {
  vanish('Vanish'),
  summon('Summon'),
  poison('Poison'),
  cloak('Cloak');

  const MagicianKind(this.label);
  final String label;

  /// Vanish, Summon and Poison resolve when picked up from the Enchanted
  /// Forest. The Cloak acts when it is placed.
  bool get resolvesOnPickup => this != MagicianKind.cloak;
}

/// The five kinds of Talisman in the Enchanted Forest. Each kind is fixed
/// to exactly one number in the printed deck (rulebook p. 11): 1 = Toad,
/// 2 = Crystal, 3 = Mushroom, 4 = Raven, 5 = Flower.
enum TalismanType {
  toad('Toad', 1),
  crystal('Crystal', 2),
  mushroom('Mushroom', 3),
  raven('Raven', 4),
  flower('Flower', 5);

  const TalismanType(this.label, this.number);

  final String label;

  /// The one number this kind of Talisman carries.
  final int number;
}

/// Talismans carry a [TalismanType] fixed to its number (1-5); Master
/// Magicians carry a [MagicianKind].
class GameCard {
  const GameCard._(this.id, this.talisman, this.magician, this.number, this.color);

  final int id;
  final TalismanType? talisman;
  final MagicianKind? magician;
  final int? number;
  final CardColor color;

  bool get isTalisman => talisman != null;
  bool get isCloak => magician == MagicianKind.cloak;

  /// A row may contain at most one of each key: the five Talisman types and
  /// the three picking-up magicians. Cloaks never enter the row.
  String get rowKey {
    if (isTalisman) return 'T${talisman!.index}';
    if (isCloak) return 'C';
    return 'M${magician!.index}';
  }

  @override
  String toString() =>
      isTalisman
          ? '${talisman!.label} $number (${color.label})'
          : '${magician!.label} (${color.label})';
}

/// Builds the 83-card deck: 60 Talismans and 23 Master Magicians.
class Deck {
  Deck._();

  static const int talismanCount = 60;
  static const int magicianCount = 23;
  static const int total = talismanCount + magicianCount;

  /// Each Talisman kind exists in all three colors, four copies each —
  /// 12 cards per kind, 60 in total.
  static const int copiesPerColor = 4;

  /// Color distribution of the 23 Master Magicians:
  /// 6 Vanish, 6 Summon, 5 Poison, 6 Cloak.
  static final List<MagicianKind> _magicians = [
    for (var i = 0; i < 6; i++) MagicianKind.vanish,
    for (var i = 0; i < 6; i++) MagicianKind.summon,
    for (var i = 0; i < 5; i++) MagicianKind.poison,
    for (var i = 0; i < 6; i++) MagicianKind.cloak,
  ];

  /// Builds the deck deterministically. The order is fixed (grouped by type),
  /// so every device can rebuild the identical deck from the shared shuffle
  /// [seed].
  static List<GameCard> build(int seed) {
    final cards = <GameCard>[];
    for (final type in TalismanType.values) {
      for (final color in CardColor.values) {
        for (var i = 0; i < copiesPerColor; i++) {
          cards.add(GameCard._(
            cards.length,
            type,
            null,
            type.number,
            color,
          ));
        }
      }
    }
    final colors = [CardColor.sun, CardColor.moon, CardColor.star];
    for (final kind in _magicians) {
      final color = colors[(kind.index + cards.length) % colors.length];
      cards.add(GameCard._(cards.length, null, kind, null, color));
    }
    assert(cards.length == total);
    final deck = List<GameCard>.of(cards);
    _shuffle(deck, seed);
    return deck;
  }

  /// Deterministically reshuffles [deck] in place (Fisher–Yates with the
  /// shared LCG). The PRNG state is derived from the game [seed] and a
  /// [salt] (the depletion count), so every device rebuilds the identical
  /// order and each reshuffle differs from the initial shuffle and from
  /// the other reshuffles.
  static void reshuffle(List<GameCard> deck, int seed, int salt) =>
      _shuffle(deck, seed * 1000003 + salt * 7919);

  /// A small deterministic PRNG so all devices shuffle identically.
  static void _shuffle(List<GameCard> deck, int seed) {
    var state = seed == 0 ? 0x12345678 : seed;
    int next() {
      state = state * 1103515245 + 12345;
      return ((state >> 16) & 0x7fff);
    }

    for (var i = deck.length - 1; i > 0; i--) {
      final j = next() % (i + 1);
      final t = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
  }
}