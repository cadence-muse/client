import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cadence/features/tracks/track_formatting.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/setlists_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
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

  // Tracks currently mid-removal — guards the remove IconButton against a
  // fast double-tap firing two overlapping DELETE requests for the same
  // track (WR-04), consistent with the `_isSubmitting` pattern used
  // elsewhere in this feature (create/edit/delete/add-tracks all disable
  // their trigger while a request is in flight).
  final Set<String> _removingTrackIds = {};

  Future<void> _removeTrack(String trackId) async {
    if (_removingTrackIds.contains(trackId)) return;
    setState(() => _removingTrackIds.add(trackId));
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
      // force: true (WR-01) — removing two different tracks in quick
      // succession must not have the second removal's resync silently
      // absorbed into an in-flight fetch that started before it reached
      // the server.
      await ref
          .read(
            setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier,
          )
          .refresh(force: true);
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        await ref
            .read(setlistListDataProvider(widget.bandId).notifier)
            .refresh(force: true);
      }
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setlistDetailRemoveTrackFailedSnackbar)),
      );
    } finally {
      if (mounted) {
        setState(() => _removingTrackIds.remove(trackId));
      }
    }
  }

  /// Handles a drop from the edit-mode `ReorderableListView` (D-14, D-15).
  /// Submits the reorder immediately on drop — no batching, no "Save order"
  /// action. Builds the new order via `removeAt`/`insert` on the *complete*
  /// existing tracks list (never a filtered/partial reconstruction), so the
  /// submitted `trackIds` always contains every track currently in the
  /// setlist (must_haves.prohibitions).
  ///
  /// Wired to `onReorderItem`, not the plan's originally-cited `onReorder` —
  /// this project's installed Flutter 3.44.9 SDK deprecates `onReorder` in
  /// favor of `onReorderItem` (identical `ReorderCallback` signature, but
  /// `newIndex` already accounts for the removed item at `oldIndex`, so no
  /// manual `newIndex > oldIndex ? newIndex - 1 : newIndex` adjustment is
  /// needed/correct here — doing so would double-adjust and place the
  /// dropped track one slot short). `ReorderableListView` asserts exactly
  /// one of `onReorder`/`onReorderItem` may be supplied.
  ///
  /// On success, patches local state via `SetlistDetailData.reorderTracks`
  /// (no refetch — reorder doesn't change `durationSeconds`/track count).
  /// On failure, the on-screen order was never mutated (it's driven by
  /// provider state, only touched after a successful response), so there's
  /// nothing to visually revert — shows the failure snackbar and resyncs
  /// with server truth via `refresh()`.
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final current = ref.read(
      setlistDetailDataProvider(widget.bandId, widget.setlistId),
    );
    final tracks = (current.valueOrNull?['tracks'] as List?)
        ?.cast<Map<String, dynamic>>();
    if (tracks == null) return;

    final reordered = List<Map<String, dynamic>>.of(tracks)
      ..removeAt(oldIndex)
      ..insert(newIndex, tracks[oldIndex]);
    final trackIds = [
      for (final track in reordered) track['trackId'] as String,
    ];

    // ReorderSetlistTracksRequestBody caps `trackIds` at 100 (publicapi.yml).
    // This method always submits the *entire* current track list (see its
    // doc comment), so a setlist that has grown past this cap would
    // otherwise have every reorder deterministically fail with a misleading
    // "Refreshing..." message (WR-03) — guard client-side before the doomed
    // network call.
    if (trackIds.length > maxSetlistTracks) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.setlistDetailReorderTooManyTracks(
              l10n.trackCount(maxSetlistTracks),
            ),
          ),
        ),
      );
      return;
    }

    try {
      await ref
          .read(publicApiProvider)
          .reorderSetlistTracks(
            bandId: widget.bandId,
            setlistId: widget.setlistId,
            trackIds: trackIds,
          );
      await ref
          .read(
            setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier,
          )
          .reorderTracks(trackIds);
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setlistDetailReorderFailedSnackbar)),
      );
      await ref
          .read(
            setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier,
          )
          .refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final setlistAsync = ref.watch(
      setlistDetailDataProvider(widget.bandId, widget.setlistId),
    );
    final isOnline = ref.watch(isOnlineProvider);
    final name = setlistAsync.valueOrNull?['name'] as String?;
    final currentSetlist = setlistAsync.valueOrNull;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? l10n.setlistDetailFallbackTitle),
        actions: [
          if (currentSetlist != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: isOnline
                  ? l10n.setlistDetailEditTooltip
                  : l10n.commonRequiresConnection,
              onPressed: isOnline
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditSetlistScreen(
                          bandId: widget.bandId,
                          setlistId: widget.setlistId,
                          currentSetlist: currentSetlist,
                        ),
                      ),
                    )
                  : null,
            ),
        ],
      ),
      body: setlistAsync.when(
        data: (setlist) => _buildContent(context, setlist, isOnline),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(
              setlistDetailDataProvider(widget.bandId, widget.setlistId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> setlist,
    bool isOnline,
  ) {
    final name = setlist['name'] as String;
    final eventLocation = setlist['eventLocation'] as String?;
    final eventDate = setlist['eventDate'] as String?;
    final durationSeconds = setlist['durationSeconds'] as int;
    final tracks = (setlist['tracks'] as List).cast<Map<String, dynamic>>();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Header info / Edit-Done toggle / delete tile stay outside the
    // reorderable region as plain Column children — the Expanded child
    // below only swaps between a plain ListView (read-only) and a
    // ReorderableListView (edit mode), avoiding mixed-scroll-physics
    // complications from nesting the whole screen in one scrollable.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (eventLocation != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(eventLocation)),
                  ],
                ),
              ],
              if (eventDate != null) ...[
                const SizedBox(height: 16),
                Text(formatEventDate(eventDate)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.timer, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(durationSeconds.asMinutesSeconds),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: isOnline || _editMode
                      ? ''
                      : l10n.commonRequiresConnection,
                  child: TextButton(
                    onPressed: isOnline
                        ? () => setState(() => _editMode = !_editMode)
                        : (_editMode
                              ? () => setState(() => _editMode = false)
                              : null),
                    child: Text(
                      _editMode
                          ? l10n.setlistDetailDoneButton
                          : l10n.commonEdit,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: Text(
                  l10n.setlistDetailTracksHeader(tracks.length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(child: Text(l10n.setlistDetailNoTracks))
              : (_editMode && isOnline)
              ? ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final trackId = track['trackId'] as String;
                    final title = track['title'] as String;
                    final artist = track['artist'] as String;
                    final trackDurationSeconds =
                        track['durationSeconds'] as int?;
                    final durationText =
                        trackDurationSeconds?.asMinutesSeconds ?? '—';
                    return ListTile(
                      key: ValueKey(trackId),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$artist • $durationText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _removingTrackIds.contains(trackId)
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: colorScheme.error,
                              ),
                              tooltip: l10n.setlistDetailRemoveTrackTooltip,
                              onPressed: () => _removeTrack(trackId),
                            ),
                    );
                  },
                  onReorderItem: _handleReorder,
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: tracks.map((track) {
                    final title = track['title'] as String;
                    final artist = track['artist'] as String;
                    final trackDurationSeconds =
                        track['durationSeconds'] as int?;
                    final durationText =
                        trackDurationSeconds?.asMinutesSeconds ?? '—';
                    return ListTile(
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$artist • $durationText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
        ),
        if (_editMode && isOnline)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: ElevatedButton(
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
              child: Text(l10n.commonAddTracks),
            ),
          ),
        const Divider(height: 1),
        ListTile(
          enabled: isOnline,
          leading: Icon(Icons.delete, color: colorScheme.error),
          title: Text(
            l10n.commonDelete,
            style: TextStyle(color: colorScheme.error),
          ),
          onTap: isOnline
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmDeleteSetlistDialog(
                    bandId: widget.bandId,
                    setlistId: widget.setlistId,
                    setlistName: name,
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
            Text(l10n.commonFailedToLoadSetlists, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
