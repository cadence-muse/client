import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/profile_provider.dart';

/// Standard confirm dialog for a member leaving a band (self-remove, BAND-08,
/// D-14). Never shown to the band owner — see `BandDetailScreen`'s ownership
/// gating (D-03: owners must delete the band instead, there's no
/// ownership-transfer endpoint).
class ConfirmLeaveBandDialog extends ConsumerStatefulWidget {
  const ConfirmLeaveBandDialog({
    super.key,
    required this.bandId,
    required this.bandName,
  });

  final String bandId;
  final String bandName;

  @override
  ConsumerState<ConfirmLeaveBandDialog> createState() =>
      _ConfirmLeaveBandDialogState();
}

class _ConfirmLeaveBandDialogState
    extends ConsumerState<ConfirmLeaveBandDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Guaranteed non-null: this dialog is only reachable once
      // profileDataProvider has resolved (see BandDetailScreen's
      // ownership gate) and an authenticated session always has a profile.
      final userId = ref.read(profileDataProvider).value!['id'] as String;
      await ref
          .read(publicApiProvider)
          .removeMember(bandId: widget.bandId, userId: userId);
      // Invalidate before navigating so the Bands list re-fetches the next
      // time it's read, rather than serving stale cached data (D-15).
      ref.invalidate(bandsListDataProvider);
      if (!mounted) return;
      // Pop the dialog, then pop BandDetailScreen — the navigation depth
      // here is always dialog -> detail -> list.
      Navigator.of(context).pop();
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
      title: Text(l10n.confirmLeaveBandTitle(widget.bandName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.confirmLeaveBandBody),
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
            onPressed: (!isOnline || _isSubmitting) ? null : _leave,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isOnline ? l10n.commonLeave : l10n.commonRequiresConnection,
                  ),
          ),
        ),
      ],
    );
  }
}
