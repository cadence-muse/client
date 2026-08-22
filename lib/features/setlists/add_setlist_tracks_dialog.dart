import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';

/// Returns true when [query] is empty, or is a case-insensitive substring
/// of [track]'s title or artist (D-02). An exact-match query is trivially a
/// substring of itself, so exact title/artist matches are automatically
/// covered.
bool trackMatchesSearchQuery(Map<String, dynamic> track, String query) {
  if (query.isEmpty) return true;
  final lowerQuery = query.toLowerCase();
  return (track['title'] as String).toLowerCase().contains(lowerQuery) ||
      (track['artist'] as String).toLowerCase().contains(lowerQuery);
}

/// Multi-select picker (D-12) for adding one or more of the band's existing
/// tracks to a setlist in a single bulk `addSetlistTracks` call. Only shown
/// from `SetlistDetailScreen` while in edit mode (D-15).
///
/// [currentTrackIds] excludes tracks already present in the setlist from the
/// checklist — the picker only ever offers tracks NOT already in
/// `setlist['tracks']`.
class AddSetlistTracksDialog extends ConsumerStatefulWidget {
  const AddSetlistTracksDialog({
    super.key,
    required this.bandId,
    required this.setlistId,
    required this.currentTrackIds,
  });

  final String bandId;
  final String setlistId;
  final Set<String> currentTrackIds;

  @override
  ConsumerState<AddSetlistTracksDialog> createState() =>
      _AddSetlistTracksDialogState();
}

class _AddSetlistTracksDialogState
    extends ConsumerState<AddSetlistTracksDialog> {
  // AddSetlistTracksRequestBody caps `trackIds` at 100 (publicapi.yml) —
  // guard selection client-side against the *remaining* slots left in the
  // setlist rather than a flat 100, since [currentTrackIds] already occupies
  // some of the cap (WR-03).
  static const int _maxSetlistTracks = 100;

  final Set<String> _selectedTrackIds = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Drives the offline substring filter immediately (D-02/D-05/D-07, no
  // debounce delay needed for a pure local computation), and — only while
  // online — arms a 300ms-debounced network request (D-03/D-04) sent
  // directly via publicApiProvider rather than trackListDataProvider, so
  // the shared cache (used by 6+ other call sites) is never keyed by search
  // variants. That response is intentionally discarded (D-05): the
  // displayed list never re-filters on it this milestone.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounceTimer?.cancel();
    if (!ref.read(isOnlineProvider)) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref
          .read(publicApiProvider)
          .listBandTracks(widget.bandId, searchQuery: _searchQuery)
          .catchError((_) => <Map<String, dynamic>>[]);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicApiProvider)
          .addSetlistTracks(
            bandId: widget.bandId,
            setlistId: widget.setlistId,
            trackIds: _selectedTrackIds.toList(),
          );
      // Server owns the post-add durationSeconds/track array (SETL-09) — a
      // full refresh() re-fetches rather than a client-side splice.
      await ref
          .read(
            setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier,
          )
          .refresh();
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        await ref
            .read(setlistListDataProvider(widget.bandId).notifier)
            .refresh();
      }
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tracks added!')));
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Failed to add tracks. Try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: const Text('Add tracks'),
      content: SizedBox(
        width: double.maxFinite,
        child: tracksAsync.when(
          data: (tracks) {
            var availableTracks = [
              for (final track in tracks)
                if (!widget.currentTrackIds.contains(track['id'] as String))
                  track,
            ];
            // Offline search only visibly filters (D-05/D-06) — online, the
            // debounced request fires (see _onSearchChanged) but the
            // displayed list intentionally stays full/unfiltered. Order is
            // preserved: no sort is introduced here.
            if (!isOnline && _searchQuery.isNotEmpty) {
              availableTracks = [
                for (final track in availableTracks)
                  if (trackMatchesSearchQuery(track, _searchQuery)) track,
              ];
            }
            final remainingSlots =
                _maxSetlistTracks - widget.currentTrackIds.length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search by title or artist',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                if (remainingSlots <= 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'This setlist already has the maximum of 100 tracks.',
                    ),
                  )
                else if (!isOnline &&
                    _searchQuery.isNotEmpty &&
                    availableTracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: Text('No tracks match your search')),
                  )
                else if (availableTracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No more tracks available'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableTracks.length,
                      itemBuilder: (context, index) {
                        final track = availableTracks[index];
                        final trackId = track['id'] as String;
                        final isSelected = _selectedTrackIds.contains(
                          trackId,
                        );
                        final atCap =
                            _selectedTrackIds.length >= remainingSlots;
                        return CheckboxListTile(
                          title: Text(
                            track['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track['artist'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          value: isSelected,
                          onChanged: (!isSelected && atCap)
                              ? null
                              : (checked) => setState(() {
                                  if (checked == true) {
                                    _selectedTrackIds.add(trackId);
                                  } else {
                                    _selectedTrackIds.remove(trackId);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                if (remainingSlots > 0 &&
                    _selectedTrackIds.length >= remainingSlots) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Setlists can have at most 100 tracks — '
                    '$remainingSlots slot'
                    '${remainingSlots == 1 ? '' : 's'} remaining.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text("Couldn't load tracks")),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(trackListDataProvider(widget.bandId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: FilledButton(
            onPressed:
                (_isSubmitting || _selectedTrackIds.isEmpty || !isOnline)
                ? null
                : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isOnline ? 'Add' : 'Requires connection'),
          ),
        ),
      ],
    );
  }
}
