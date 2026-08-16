import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracks_provider.dart';

/// Lightweight Cancel/Delete confirm dialog for deleting a track (TRACK-05,
/// D-11) — never shown via swipe-to-dismiss on list rows (D-12), only from
/// `TrackDetailScreen`. Not owner-gated — see `03-02-PLAN.md`'s objective
/// note resolving the UI-SPEC's inapplicable owner-gating citation.
class ConfirmDeleteTrackDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteTrackDialog({
    super.key,
    required this.bandId,
    required this.trackId,
    required this.trackTitle,
  });

  final String bandId;
  final String trackId;
  final String trackTitle;

  @override
  ConsumerState<ConfirmDeleteTrackDialog> createState() =>
      _ConfirmDeleteTrackDialogState();
}

class _ConfirmDeleteTrackDialogState
    extends ConsumerState<ConfirmDeleteTrackDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicApiProvider)
          .deleteBandTrack(widget.bandId, widget.trackId);
      if (ref.exists(trackListDataProvider(widget.bandId))) {
        ref
            .read(trackListDataProvider(widget.bandId).notifier)
            .removeFromList(widget.trackId);
      } else {
        ref.invalidate(trackListDataProvider(widget.bandId));
      }
      // CR-03: also invalidate the global cross-band Tracks tab so a
      // deleted track stops appearing there without a manual filter
      // change. Guarded with ref.exists() — the global tab may not have
      // been visited yet in this session, and reading .notifier /
      // invalidating a never-instantiated provider would trigger an
      // unwanted network fetch as a side effect.
      if (ref.exists(userTracksListDataProvider)) {
        ref.invalidate(userTracksListDataProvider);
      }
      if (!mounted) return;
      // Pop the dialog, then pop TrackDetailScreen — the navigation depth
      // here is always dialog -> detail -> list (D-13).
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Delete ${widget.trackTitle}?',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This action cannot be undone.'),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _isSubmitting ? null : _delete,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
