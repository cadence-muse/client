import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Confirm dialog for the band owner transferring ownership to another
/// member (BAND-12, D-01/D-04/D-05/D-09/D-10). The body must explicitly
/// state the acting owner's own demotion, not just the target's promotion
/// (D-04). On success, invalidates the band detail (D-09, no response body
/// to trust) and patches the bands list's `ownerId` in place with the known
/// target [memberUserId] (D-10).
class ConfirmTransferOwnershipDialog extends ConsumerStatefulWidget {
  const ConfirmTransferOwnershipDialog({
    super.key,
    required this.bandId,
    required this.memberUserId,
    required this.memberUsername,
    required this.bandName,
  });

  final String bandId;
  final String memberUserId;
  final String memberUsername;
  final String bandName;

  @override
  ConsumerState<ConfirmTransferOwnershipDialog> createState() =>
      _ConfirmTransferOwnershipDialogState();
}

class _ConfirmTransferOwnershipDialogState
    extends ConsumerState<ConfirmTransferOwnershipDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _transfer() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicApiProvider)
          .transferOwnership(
            bandId: widget.bandId,
            userId: widget.memberUserId,
          );
      // D-09: no response body to trust — invalidate so the detail screen
      // refetches the server's authoritative post-transfer state.
      ref.invalidate(bandDetailDataProvider(widget.bandId));
      // D-10: patch the bands list's ownerId in place with the known
      // target, so the Bands tab's Owner/Member badge doesn't go stale
      // until an unrelated tab-switch refetch. Same ref.exists() guard as
      // edit_band_screen.dart — only patch if the list provider is already
      // alive.
      if (ref.exists(bandsListDataProvider)) {
        ref
            .read(bandsListDataProvider.notifier)
            .patchBandOwner(widget.bandId, widget.memberUserId);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ownership transferred')),
        );
      }
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
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text('Transfer ownership to ${widget.memberUsername}?'),
      content: SingleChildScrollView(
        // Wrapped in a scroll view so the interpolated body text (which can
        // grow arbitrarily with a long member/band name) doesn't overflow
        // the dialog's default (non-scrollable) AlertDialog sizing (UI-SPEC
        // E3 backstop truths — dialog overflow and long-text).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.memberUsername} will become the owner of this '
              'band.\n\nYou will no longer be the owner of '
              '${widget.bandName}.',
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: FilledButton(
            onPressed: (!isOnline || _isSubmitting) ? null : _transfer,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isOnline ? 'Transfer' : 'Requires connection'),
          ),
        ),
      ],
    );
  }
}
