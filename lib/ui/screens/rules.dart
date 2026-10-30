import 'package:flutter/material.dart';

import '../../game/cards.dart';
import '../app_state.dart';
import '../icons.dart';
import '../theme.dart';

/// Scrollable parchment page summarizing the rules of Toil & Troublez.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: TNTTheme.fontTitle,
              fontSize: 13,
              letterSpacing: 2,
              color: TNTTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TntScaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Overview',
              const Text(
                'It’s the witching hour in the Enchanted Forest. Search for '
                'Talismans — mystical items that empower you to become a great '
                'magician. Along the way you will meet the Master Magicians, '
                'whose spells help or hinder your quest. Play it safe, or push '
                'your luck…',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'The Pieces',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '60 Talisman cards — each kind fixed to one number: '
                    '1 Toad, 2 Crystal, 3 Mushroom, 4 Raven, 5 Flower — '
                    'marked with one of three colors: Sun, Moon or Star.\n\n'
                    '23 Master Magician cards — Vanish, Summon, Poison and '
                    'Cloak.',
                    style: TextStyle(
                      fontFamily: TNTTheme.fontSerif,
                      fontSize: 13,
                      color: TNTTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final t in TalismanType.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              TalismanIcon(type: t, size: 30),
                              const SizedBox(height: 2),
                              Text(
                                '${t.number} ${t.label}',
                                style: const TextStyle(
                                  fontFamily: TNTTheme.fontUi,
                                  fontSize: 10,
                                  color: TNTTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 14),
                      Column(
                        children: [
                          const ColorGlyph(color: CardColor.sun, size: 26),
                          const SizedBox(height: 2),
                          Text(
                            'Sun · Moon · Star',
                            style: const TextStyle(
                              fontFamily: TNTTheme.fontUi,
                              fontSize: 10,
                              color: TNTTheme.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              'Setup',
              const Text(
                'Shuffle all cards into a face-down draw pile and place it in '
                'the Enchanted Forest where all players can reach it, with '
                'space beside it for the discard pile. The player who last ate '
                'mushrooms goes first.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'On Your Turn',
              const Text(
                '1. Draw a card and place it in the Enchanted Forest.\n'
                '2. Keep drawing and placing, or pass. If you ever draw a card '
                'that cannot be placed, your turn ends immediately — that card '
                'is discarded.\n'
                '3. When you pass, choose one row of the Enchanted Forest. '
                'Perform any Vanish, Summon or Poison cards in that row, '
                'discard those along with any Cloak cards, and take the row’s '
                'Talismans into your Trove.\n'
                '4. Every other player then takes one card from the outside of '
                'a row, clockwise. Picked-up Magicians resolve immediately; a '
                'picked-up Cloak is discarded and the talisman beneath goes to '
                'the player.\n'
                '5. The next player clockwise begins their turn.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'Placement Rules',
              const Text(
                '• The Forest holds up to 3 rows.\n'
                '• Cards are placed on the left or right end of a row, or '
                'start a new row — never between other cards.\n'
                '• Each row holds at most one of each Talisman and one of each '
                'Vanish, Summon or Poison.\n'
                '• Talismans in a row must ascend in number, left to right '
                '(numbers may be skipped).\n'
                '• Cards of the same color may not touch — except Cloak '
                'cards, which follow no color rules.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'Collections',
              const Text(
                'A Collection is either 1 of each of the 5 Talismans, or 4 of '
                'the same Talisman (any colors). Complete them any time. Each '
                'Collection becomes one face-down marker card worth 10 Magic '
                'Marks — it cannot be stolen — and the rest of the set is '
                'discarded.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'Master Magicians',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _magician(
                    MagicianKind.vanish,
                    'Choose one of the 5 Talismans. Every other player with at '
                    'least one in their Trove must discard one.',
                  ),
                  _magician(
                    MagicianKind.summon,
                    'Move a Talisman of your choice from another player’s '
                    'Trove into your own. Collection markers are safe.',
                  ),
                  _magician(
                    MagicianKind.poison,
                    'Discard a Talisman of your choice from your Trove.',
                  ),
                  _magician(
                    MagicianKind.cloak,
                    'Place on top of any Talisman in the Forest to hide its '
                    'color and number. Cloaks may sit beside each other and '
                    'break no color rule. If no Talismans are out, the Cloak '
                    'is discarded and your turn ends.',
                  ),
                ],
              ),
            ),
            _section(
              'Ending the Game',
              const Text(
                'The game ends when the draw pile is exhausted: with 2–3 '
                'players on its first depletion; with 4–5 after one reshuffle '
                'of the discard pile; with 6 after two. Finish the current '
                'turn, then score.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
            _section(
              'Scoring',
              const Text(
                'Each Collection marker is 10 Magic Marks; each remaining '
                'Talisman in your Trove is 1. The most Magic Marks wins. Ties '
                'break on the most Collections; still tied, the victory is '
                'shared.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontSize: 13,
                  color: TNTTheme.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _magician(MagicianKind kind, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicianIcon(kind: kind, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${kind.label}: $text',
              style: const TextStyle(
                fontFamily: TNTTheme.fontSerif,
                fontSize: 13,
                color: TNTTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
