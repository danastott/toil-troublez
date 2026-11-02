import 'package:flutter/material.dart';

import '../../settings_prefs.dart';
import '../app_state.dart';
import '../theme.dart';

/// App preferences: currently the pause after a drawn card is revealed.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TntScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Card Reveal Pause',
                style: TextStyle(
                  fontFamily: TNTTheme.fontTitle,
                  fontSize: 19,
                  color: TNTTheme.parchment,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'How long a drawn card stays face-up before it is played '
                'into the forest.',
                style: TextStyle(
                  fontFamily: TNTTheme.fontSerif,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: TNTTheme.parchment.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: revealPauseMs,
                builder: (context, selected, _) => Column(
                  children: [
                    for (final ms in revealPauseOptions)
                      _PauseTile(
                        label: revealPauseLabel(ms),
                        selected: ms == selected,
                        onTap: () => revealPauseMs.value = ms,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseTile extends StatelessWidget {
  const _PauseTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? TNTTheme.gold.withValues(alpha: 0.22)
            : TNTTheme.ink.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? TNTTheme.gold
                    : TNTTheme.goldSoft.withValues(alpha: 0.35),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: TNTTheme.fontUi,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? TNTTheme.goldSoft : TNTTheme.parchment,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, color: TNTTheme.goldSoft, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
