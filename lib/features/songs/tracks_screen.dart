import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/tracks_provider.dart';
import '../tracks/track_detail_screen.dart';
import '../tracks/track_formatting.dart';

/// The global, cross-band Tracks tab (TRACK-06): a flat list of every track
/// across every band the user belongs to, with a band-name badge per row and
/// a filter dropdown to narrow to one band. See `03-UI-SPEC.md`
/// "GlobalTracksScreen".
class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(bandsListDataProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Tracks')),
      body: bands.isEmpty
          ? _buildEmptyState(context, ref, showViewBandsButton: true)
          : Column(
              children: [
                _buildFilterDropdown(context, ref, bands),
                Expanded(child: _buildTracksBody(context, ref)),
              ],
            ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> bands,
  ) {
    final selectedBandId = ref.watch(selectedBandIdFilterProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButton<String?>(
        isExpanded: true,
        value: selectedBandId,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All bands'),
          ),
          for (final band in bands)
            DropdownMenuItem<String?>(
              value: band['id'] as String,
              child: Text(band['name'] as String),
            ),
        ],
        onChanged: (value) =>
            ref.read(selectedBandIdFilterProvider.notifier).setFilter(value),
      ),
    );
  }

  Widget _buildTracksBody(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(userTracksListDataProvider);

    return tracksAsync.when(
      data: (tracks) => _buildContent(context, ref, tracks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _buildError(
        context,
        () => ref.invalidate(userTracksListDataProvider),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> tracks,
  ) {
    if (tracks.isEmpty) {
      return _buildEmptyState(context, ref, showViewBandsButton: false);
    }

    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final title = track['title'] as String;
        final artist = track['artist'] as String;
        final bandName = track['bandName'] as String;
        final durationSeconds = track['durationSeconds'] as int?;
        return ListTile(
          leading: Chip(
            label: Text(bandName, overflow: TextOverflow.ellipsis),
            visualDensity: VisualDensity.compact,
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackDetailScreen(
                bandId: track['bandId'] as String,
                trackId: track['id'] as String,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool showViewBandsButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No tracks',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create tracks in a band to see them here.',
              textAlign: TextAlign.center,
            ),
            if (showViewBandsButton) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                // WR-01: switch to the Bands tab (index 2 per
                // root_scaffold.dart's destination order) instead of
                // being a no-op.
                onPressed: () =>
                    ref.read(selectedTabIndexProvider.notifier).setIndex(2),
                child: const Text('View bands'),
              ),
            ],
          ],
        ),
      ),
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
