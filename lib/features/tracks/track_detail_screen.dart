import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/tracks_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import 'confirm_delete_track_dialog.dart';
import 'edit_track_screen.dart';
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
    final isOnline = ref.watch(isOnlineProvider);
    final title = trackAsync.valueOrNull?['title'] as String?;
    final currentTrack = trackAsync.valueOrNull;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? l10n.trackDetailFallbackTitle),
        actions: [
          if (currentTrack != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: isOnline
                  ? l10n.trackDetailEditTooltip
                  : l10n.commonRequiresConnection,
              onPressed: isOnline
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditTrackScreen(
                          bandId: bandId,
                          trackId: trackId,
                          currentTrack: currentTrack,
                        ),
                      ),
                    )
                  : null,
            ),
        ],
      ),
      body: trackAsync.when(
        data: (track) => _buildContent(context, track, isOnline),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(trackDetailDataProvider(bandId, trackId)),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> track,
    bool isOnline,
  ) {
    final title = track['title'] as String;
    final artist = track['artist'] as String;
    final durationSeconds = track['durationSeconds'] as int?;
    final tempo = track['tempo'] as int?;
    final key = track['key'] as String?;
    final notes = track['notes'] as String?;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
        Row(
          children: [
            Icon(Icons.timer, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(durationSeconds?.asMinutesSeconds ?? '—'),
          ],
        ),
        if (tempo != null) ...[
          const SizedBox(height: 16),
          Text(l10n.trackDetailTempoLine(tempo)),
        ],
        if (key != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.music_note, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(key),
            ],
          ),
        ],
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(notes))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.delete, color: colorScheme.error),
          title: Text(
            l10n.commonDelete,
            style: TextStyle(color: colorScheme.error),
          ),
          enabled: isOnline,
          onTap: isOnline
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmDeleteTrackDialog(
                    bandId: bandId,
                    trackId: trackId,
                    trackTitle: title,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.commonCouldntLoadTracks,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.commonConnectionError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
