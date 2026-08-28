import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/metronome_provider.dart';
import 'audio/metronome_audio_service.dart';
import 'beat_indicator.dart';

/// The metronome screen (METR-01/METR-02/METR-03). [initialBpm] seeds the
/// [metronomeStateProvider] family -- 120 from the Homepage entry point
/// (D-08 default) or a track's own tempo from the Track Detail entry point
/// (METR-02). This plan's BPM display is a plain [Text] pair, an explicit
/// stub for Plan 18-02's drag-to-BPM dial (D-05) -- no architectural change
/// needed to swap it in later.
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
        data: (_) => _buildContent(context, state),
        loading: () => _buildLoading(context, l10n),
        error: (e, st) => _buildError(context, ref, l10n),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: notifier.togglePlay,
        child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MetronomeData state) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${state.bpm}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              AppLocalizations.of(context)!.metronomeBpmUnitLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
