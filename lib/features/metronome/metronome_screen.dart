import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/metronome_provider.dart';
import 'audio/metronome_audio_service.dart';
import 'beat_indicator.dart';
import 'metronome_dial.dart';

/// The metronome screen (METR-01/METR-02/METR-03/METR-04). [initialBpm]
/// seeds the [metronomeStateProvider] family -- 120 from the Homepage entry
/// point (D-08 default) or a track's own tempo from the Track Detail entry
/// point (METR-02). BPM display/adjustment is the large round drag-to-set
/// [MetronomeDial] (D-05/D-06/D-07), replacing Plan 18-01's plain BPM `Text`
/// stub -- a widget swap only, no architectural change to this screen, the
/// provider, or the audio layer.
class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key, required this.initialBpm});

  final int initialBpm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync = ref.watch(metronomeAudioServiceProvider);
    final state = ref.watch(metronomeStateProvider(initialBpm));
    final notifier = ref.read(metronomeStateProvider(initialBpm).notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.metronomeAppBarTitle)),
      body: audioAsync.when(
        data: (_) => _buildContent(context, state, notifier),
        loading: () => _buildLoading(context, l10n),
        error: (e, st) => _buildError(context, ref, l10n),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: notifier.togglePlay,
        child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MetronomeData state,
    MetronomeState notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MetronomeDial(bpm: state.bpm, onBpmChanged: notifier.setBpm),
            const SizedBox(height: 16),
            _buildQuickAdjustRow(l10n, state, notifier),
            const SizedBox(height: 32),
            BeatIndicator(
              currentBeat: state.currentBeat,
              isPlaying: state.isPlaying,
            ),
          ],
        ),
      ),
    );
  }

  // METR-04: ±1/±5 quick-adjust buttons, ordered [-5, -1, +1, +5] flanking
  // the dial (outer pair = ±5, inner pair = ±1). Both pairs share an icon
  // (Icons.remove/Icons.add) and are differentiated by position, iconSize
  // (28 for ±5, 20 for ±1), and tooltip text. Every button routes through
  // notifier.setBpm -- the same clamped [40,300] choke point the dial uses
  // (D-06/T-18-06) -- the onPressed bound check below is a UI-only
  // convenience for disabling at the edges, not the real enforcement point.
  Widget _buildQuickAdjustRow(
    AppLocalizations l10n,
    MetronomeData state,
    MetronomeState notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          iconSize: 28,
          tooltip: l10n.metronomeMinus5Tooltip,
          onPressed: state.bpm > 40
              ? () => notifier.setBpm(state.bpm - 5)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.remove),
          iconSize: 20,
          tooltip: l10n.metronomeMinus1Tooltip,
          onPressed: state.bpm > 40
              ? () => notifier.setBpm(state.bpm - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          iconSize: 20,
          tooltip: l10n.metronomePlus1Tooltip,
          onPressed: state.bpm < 300
              ? () => notifier.setBpm(state.bpm + 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          iconSize: 28,
          tooltip: l10n.metronomePlus5Tooltip,
          onPressed: state.bpm < 300
              ? () => notifier.setBpm(state.bpm + 5)
              : null,
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.metronomeLoadingMessage),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.metronomeErrorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(metronomeAudioServiceProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
