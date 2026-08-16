import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/setlists_provider.dart';
import 'setlist_formatting.dart';

class SetlistDetailScreen extends ConsumerWidget {
  const SetlistDetailScreen({
    super.key,
    required this.bandId,
    required this.setlistId,
  });

  final String bandId;
  final String setlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistAsync = ref.watch(
      setlistDetailDataProvider(bandId, setlistId),
    );
    final name = setlistAsync.valueOrNull?['name'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Setlist')),
      body: setlistAsync.when(
        data: (setlist) => _buildContent(context, setlist),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(setlistDetailDataProvider(bandId, setlistId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> setlist) {
    final name = setlist['name'] as String;
    final eventLocation = setlist['eventLocation'] as String?;
    final eventDate = setlist['eventDate'] as String?;
    final durationSeconds = setlist['durationSeconds'] as int;
    final tracks = (setlist['tracks'] as List).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (eventLocation != null) ...[
          const SizedBox(height: 16),
          Text(eventLocation),
        ],
        if (eventDate != null) ...[
          const SizedBox(height: 16),
          Text(formatEventDate(eventDate)),
        ],
        const SizedBox(height: 16),
        Text('Duration: ${durationSeconds.asMinutesAndSeconds}'),
        const SizedBox(height: 24),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            'Tracks (${tracks.length})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (tracks.isEmpty)
          const Text('No tracks in this setlist')
        else
          ...tracks.map((track) {
            final title = track['title'] as String;
            final artist = track['artist'] as String;
            final trackDurationSeconds = track['durationSeconds'] as int?;
            return ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                trackDurationSeconds?.asMinutesAndSeconds ?? '—',
              ),
            );
          }),
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
            const Text(
              'Failed to load setlists. Tap to try again.',
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
