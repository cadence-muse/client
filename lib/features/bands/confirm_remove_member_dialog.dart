import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Standard confirm dialog for the band owner removing another member
/// (BAND-09, D-14). Never shown for the owner's own row (see
/// `BandDetailScreen`'s member-list rendering) — the owner uses "Delete" or
/// "Leave" for that.
class ConfirmRemoveMemberDialog extends ConsumerStatefulWidget {
  const ConfirmRemoveMemberDialog({
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
  ConsumerState<ConfirmRemoveMemberDialog> createState() =>
      _ConfirmRemoveMemberDialogState();
}

class _ConfirmRemoveMemberDialogState
    extends ConsumerState<ConfirmRemoveMemberDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicApiProvider)
          .removeMember(bandId: widget.bandId, userId: widget.memberUserId);
      // The acting owner stays on the detail screen — only the members
      // sub-list needs refreshing (RESEARCH.md Pitfall 5), so invalidate the
      // detail provider (not the list provider).
      ref.invalidate(bandDetailDataProvider(widget.bandId));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = l10n.commonSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text(
        l10n.confirmRemoveMemberTitle(widget.memberUsername, widget.bandName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.confirmRemoveMemberBody(widget.memberUsername)),
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
          child: Text(l10n.commonCancel),
        ),
        Tooltip(
          message: isOnline ? '' : l10n.commonRequiresConnection,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: (!isOnline || _isSubmitting) ? null : _remove,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isOnline
                        ? l10n.commonRemove
                        : l10n.commonRequiresConnection,
                  ),
          ),
        ),
      ],
    );
  }
}
