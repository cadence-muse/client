import 'package:flutter/material.dart';

/// 4 beat-indicator dots showing "where in the bar" the metronome is
/// (D-09) -- a stateless display widget driven entirely by the caller's
/// [currentBeat]/[isPlaying]. Beat 0 (the accent, D-03) is permanently
/// larger and `colorScheme.primary` (D-10); beats 1-3 are smaller and
/// `colorScheme.outlineVariant`. Whichever dot matches [currentBeat] while
/// [isPlaying] additionally pulses to a brighter/bigger state (D-09).
class BeatIndicator extends StatelessWidget {
  const BeatIndicator({
    super.key,
    required this.currentBeat,
    required this.isPlaying,
  });

  final int currentBeat;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildDot(colorScheme, i),
          ),
      ],
    );
  }

  Widget _buildDot(ColorScheme colorScheme, int index) {
    final isAccentDot = index == 0;
    final isActive = isPlaying && currentBeat == index;

    final baseDiameter = isAccentDot ? 18.0 : 10.0;
    final activeDiameter = isAccentDot ? 24.0 : 14.0;
    final color = isAccentDot ? colorScheme.primary : colorScheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: isActive ? activeDiameter : baseDiameter,
      height: isActive ? activeDiameter : baseDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color.withAlpha(255) : color.withAlpha(140),
      ),
    );
  }
}
