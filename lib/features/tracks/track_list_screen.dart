import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tracks_provider.dart';
import 'create_track_screen.dart';
import 'track_detail_screen.dart';
import 'track_formatting.dart';

class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trackListDataProvider(bandId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tracks')),
      body: tracksAsync.when(
        data: (tracks) => _buildContent(context, tracks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(trackListDataProvider(bandId)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CreateTrackScreen(bandId: bandId)),
        ),
        tooltip: 'Add track',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> tracks,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No tracks yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a track or ask a bandmate to add one.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateTrackScreen(bandId: bandId),
                  ),
                ),
                child: const Text('Add track'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final title = track['title'] as String;
        final artist = track['artist'] as String;
        final durationSeconds = track['durationSeconds'] as int?;
        return ListTile(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackDetailScreen(
                bandId: bandId,
                trackId: track['id'] as String,
              ),
            ),
          ),
        );
      },
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
