import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Type-to-confirm dialog for deleting a band (BAND-05, owner-only, D-13).
///
/// The Delete button stays disabled until the typed text is an EXACT match
/// (case-sensitive, no trimming) to [bandName] — this is the one
/// irreversible action in Phase 2 that destroys the band for every member at
/// once, so the match must not be loosened.
class ConfirmDeleteBandDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteBandDialog({
    super.key,
    required this.bandId,
    required this.bandName,
  });

  final String bandId;
  final String bandName;

  @override
  ConsumerState<ConfirmDeleteBandDialog> createState() =>
      _ConfirmDeleteBandDialogState();
}

class _ConfirmDeleteBandDialogState
    extends ConsumerState<ConfirmDeleteBandDialog> {
  final _controller = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(publicApiProvider).deleteBand(widget.bandId);
      // Invalidate before navigating so the Bands list re-fetches the next
      // time it's read, rather than serving stale cached data (D-15).
      ref.invalidate(bandsListDataProvider);
      if (!mounted) return;
      // Pop the dialog, then pop BandDetailScreen — the navigation depth
      // here is always dialog -> detail -> list.
      Navigator.of(context).pop();
      Navigator.of(context).pop();
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
    final l10n = AppLocalizations.of(context)!;
    // Exact match only — no .trim()/.toLowerCase() — per D-13's intent.
    final matches = _controller.text == widget.bandName;
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text(l10n.confirmDeleteBandTitle(widget.bandName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.confirmDeleteBandBody),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: l10n.commonBandNameLabel),
            onChanged: (_) => setState(() {}),
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
            onPressed: (!matches || !isOnline || _isSubmitting)
                ? null
                : _delete,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isOnline
                        ? l10n.commonDelete
                        : l10n.commonRequiresConnection,
                  ),
          ),
        ),
      ],
    );
  }
}
