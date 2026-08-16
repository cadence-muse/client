import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tracks_provider.dart';
import 'track_formatting.dart';

class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({
    super.key,
    required this.bandId,
    required this.trackId,
  });

  final String bandId;
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackAsync = ref.watch(trackDetailDataProvider(bandId, trackId));
    final title = trackAsync.valueOrNull?['title'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Track')),
      body: trackAsync.when(
        data: (track) => _buildContent(context, track),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(trackDetailDataProvider(bandId, trackId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> track) {
    final title = track['title'] as String;
    final artist = track['artist'] as String;
    final durationSeconds = track['durationSeconds'] as int?;
    final tempo = track['tempo'] as int?;
    final key = track['key'] as String?;
    final notes = track['notes'] as String?;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(artist),
        const SizedBox(height: 16),
        Text('Duration: ${durationSeconds?.asMinutesSeconds ?? '—'}'),
        if (tempo != null) ...[
          const SizedBox(height: 16),
          Text('Tempo: $tempo BPM'),
        ],
        if (key != null) ...[
          const SizedBox(height: 16),
          Text('Key: $key'),
        ],
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Notes: $notes'),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load tracks",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
