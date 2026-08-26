import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Confirm dialog for the band owner rotating the band's invite code
/// (BAND-11, D-06/D-07/D-08). On success, patches [BandDetailData] in place
/// with the server-returned `newInviteCode` — no dependency on a background
/// refetch (D-08).
class ConfirmRotateInviteCodeDialog extends ConsumerStatefulWidget {
  const ConfirmRotateInviteCodeDialog({
    super.key,
    required this.bandId,
    required this.bandName,
  });

  final String bandId;
  final String bandName;

  @override
  ConsumerState<ConfirmRotateInviteCodeDialog> createState() =>
      _ConfirmRotateInviteCodeDialogState();
}

class _ConfirmRotateInviteCodeDialogState
    extends ConsumerState<ConfirmRotateInviteCodeDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _rotate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ref
          .read(publicApiProvider)
          .rotateInviteCode(widget.bandId);
      final newCode = response['newInviteCode'] as String;
      // Same reasoning as edit_band_screen.dart: only patch the detail
      // provider if it's already alive (i.e. BandDetailScreen — this
      // dialog's only caller — is watching it). Reading `.notifier` on a
      // provider nobody watches would instantiate it and fire an unplanned
      // network fetch as a side effect.
      if (ref.exists(bandDetailDataProvider(widget.bandId))) {
        await ref
            .read(bandDetailDataProvider(widget.bandId).notifier)
            .rotateInviteCode(newCode);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.confirmRotateInviteCodeSnackbar)),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.localizedMessage(l10n));
    } catch (_) {
      setState(() => _errorMessage = l10n.commonSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.confirmRotateInviteCodeTitle),
      content: SingleChildScrollView(
        // Wrapped in a scroll view so the fixed body text doesn't overflow
        // the dialog's default (non-scrollable) AlertDialog sizing at large
        // OS text-scale settings (UI-SPEC E4 backstop truth).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmRotateInviteCodeBody),
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
          child: Text(l10n.commonCancel),
        ),
        Tooltip(
          message: isOnline ? '' : l10n.commonRequiresConnection,
          child: FilledButton(
            onPressed: (!isOnline || _isSubmitting) ? null : _rotate,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isOnline
                        ? l10n.commonRotate
                        : l10n.commonRequiresConnection,
                  ),
          ),
        ),
      ],
    );
  }
}
