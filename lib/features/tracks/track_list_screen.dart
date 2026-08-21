import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/tracks_provider.dart';
import '../../widgets/sync_status_badge.dart';
import 'create_track_screen.dart';
import 'track_detail_screen.dart';
import 'track_formatting.dart';

class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trackListDataProvider(bandId));
    final syncedAt = ref.watch(trackListSyncedAtProvider(bandId));
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tracks')),
      body: tracksAsync.when(
        data: (tracks) => Column(
          children: [
            SyncStatusBadge(syncedAt: syncedAt),
            Expanded(child: _buildContent(context, tracks)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(trackListDataProvider(bandId)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isOnline
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateTrackScreen(bandId: bandId),
                ),
              )
            : null,
        tooltip: isOnline ? 'Add track' : 'Requires connection',
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
        final key = track['key'] as String?;
        final colorScheme = Theme.of(context).colorScheme;
        return ListTile(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: SizedBox(
            width: 130,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (key != null) ...[
                  Icon(Icons.music_note, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    key,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.timer, size: 18, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  durationSeconds?.asMinutesSeconds ?? '—',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
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
