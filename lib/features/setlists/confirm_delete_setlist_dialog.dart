import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';

/// Lightweight Cancel/Delete confirm dialog for deleting a setlist
/// (SETL-05, D-18) — only ever shown from `SetlistDetailScreen`. Not
/// owner-gated — see `04-02-PLAN.md`'s objective note resolving the
/// UI-SPEC's inapplicable owner-gating citation.
class ConfirmDeleteSetlistDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteSetlistDialog({
    super.key,
    required this.bandId,
    required this.setlistId,
    required this.setlistName,
  });

  final String bandId;
  final String setlistId;
  final String setlistName;

  @override
  ConsumerState<ConfirmDeleteSetlistDialog> createState() =>
      _ConfirmDeleteSetlistDialogState();
}

class _ConfirmDeleteSetlistDialogState
    extends ConsumerState<ConfirmDeleteSetlistDialog> {
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
          .deleteSetlist(widget.bandId, widget.setlistId);
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        ref
            .read(setlistListDataProvider(widget.bandId).notifier)
            .removeFromList(widget.setlistId);
      } else {
        ref.invalidate(setlistListDataProvider(widget.bandId));
      }
      if (!mounted) return;
      // Pop the dialog, then pop SetlistDetailScreen — the navigation depth
      // here is always dialog -> detail -> list (D-19).
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Delete failed. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete setlist?'),
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
