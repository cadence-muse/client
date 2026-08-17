import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';
import 'add_setlist_tracks_dialog.dart';
import 'confirm_delete_setlist_dialog.dart';
import 'edit_setlist_screen.dart';
import 'setlist_formatting.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({
    super.key,
    required this.bandId,
    required this.setlistId,
  });

  final String bandId;
  final String setlistId;

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  bool _editMode = false;

  Future<void> _removeTrack(String trackId) async {
    try {
      await ref
          .read(publicApiProvider)
          .removeSetlistTrack(
            bandId: widget.bandId,
            setlistId: widget.setlistId,
            trackId: trackId,
          );
      // Server owns the post-remove durationSeconds/track array (SETL-09) —
      // a full refresh() re-fetches rather than a client-side splice.
      await ref
          .read(
            setlistDetailDataProvider(
              widget.bandId,
              widget.setlistId,
            ).notifier,
          )
          .refresh();
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        await ref
            .read(setlistListDataProvider(widget.bandId).notifier)
            .refresh();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove track. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setlistAsync = ref.watch(
      setlistDetailDataProvider(widget.bandId, widget.setlistId),
    );
    final name = setlistAsync.valueOrNull?['name'] as String?;
    final currentSetlist = setlistAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? 'Setlist'),
        actions: [
          if (currentSetlist != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit setlist',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditSetlistScreen(
                    bandId: widget.bandId,
                    setlistId: widget.setlistId,
                    currentSetlist: currentSetlist,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: setlistAsync.when(
        data: (setlist) => _buildContent(context, setlist),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(
            setlistDetailDataProvider(widget.bandId, widget.setlistId),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

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
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _editMode = !_editMode),
            child: Text(_editMode ? 'Done' : 'Edit'),
          ),
        ),
        const SizedBox(height: 8),
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
            final trackId = track['trackId'] as String;
            final title = track['title'] as String;
            final artist = track['artist'] as String;
            final trackDurationSeconds = track['durationSeconds'] as int?;
            final durationText =
                trackDurationSeconds?.asMinutesAndSeconds ?? '—';
            return ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '$artist • $durationText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _editMode
                  ? IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Remove',
                      onPressed: () => _removeTrack(trackId),
                    )
                  : null,
            );
          }),
        if (_editMode) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AddSetlistTracksDialog(
                bandId: widget.bandId,
                setlistId: widget.setlistId,
                currentTrackIds: {
                  for (final track in tracks) track['trackId'] as String,
                },
              ),
            ),
            child: const Text('Add tracks'),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.delete, color: colorScheme.error),
          title: Text('Delete', style: TextStyle(color: colorScheme.error)),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => ConfirmDeleteSetlistDialog(
              bandId: widget.bandId,
              setlistId: widget.setlistId,
              setlistName: name,
            ),
          ),
        ),
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
