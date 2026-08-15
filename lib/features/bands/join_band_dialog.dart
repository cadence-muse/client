import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../cache/cache_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import 'band_detail_screen.dart';

/// Result of a successful join, used to drive post-dialog navigation from
/// [showJoinBandDialog] (never from inside the dialog itself, since its own
/// `BuildContext` is torn down once the dialog pops).
class _JoinOutcome {
  const _JoinOutcome.navigated(String bandId, String bandName)
    : this._(bandId: bandId, bandName: bandName, ambiguous: false);
  const _JoinOutcome.ambiguous() : this._(ambiguous: true);
  const _JoinOutcome._({
    this.bandId,
    this.bandName,
    required this.ambiguous,
  });

  final String? bandId;
  final String? bandName;
  final bool ambiguous;
}

/// Shows the "Join a band" dialog (D-11). `POST /api/band/join` returns no
/// response body, so the newly-joined band's id is resolved client-side by
/// diffing the bands list before/after the join (see 02-03-PLAN.md "Flagged
/// Assumptions"). On an unambiguous single-new-id result, navigates to that
/// band's detail screen (D-12); otherwise falls back to the (refreshed)
/// Bands list.
Future<void> showJoinBandDialog(BuildContext context, WidgetRef ref) async {
  final outcome = await showDialog<_JoinOutcome>(
    context: context,
    builder: (_) => const _JoinBandDialog(),
  );
  if (outcome == null || !context.mounted) return;

  if (outcome.ambiguous) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Joined band!')));
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("You've joined ${outcome.bandName}!")),
  );
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BandDetailScreen(bandId: outcome.bandId!),
    ),
  );
}

class _JoinBandDialog extends ConsumerStatefulWidget {
  const _JoinBandDialog();

  @override
  ConsumerState<_JoinBandDialog> createState() => _JoinBandDialogState();
}

class _JoinBandDialogState extends ConsumerState<_JoinBandDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final inviteCode = _codeController.text.trim();
    final publicApi = ref.read(publicApiProvider);

    try {
      final cachedBands = ref.read(bandsListDataProvider).value;
      final oldIds = (cachedBands ?? await publicApi.listBands())
          .map((band) => band['id'] as String)
          .toSet();

      await publicApi.joinBand(inviteCode: inviteCode);

      final freshBands = await publicApi.listBands();
      await ref.read(cacheServiceProvider).writeBands(freshBands);
      ref.read(bandsListDataProvider.notifier).setBands(freshBands);

      final newIds = freshBands
          .map((band) => band['id'] as String)
          .toSet()
          .difference(oldIds);

      if (!mounted) return;
      if (newIds.length == 1) {
        final joinedBand = freshBands.firstWhere(
          (band) => band['id'] == newIds.single,
        );
        Navigator.of(context).pop(
          _JoinOutcome.navigated(newIds.single, joinedBand['name'] as String),
        );
      } else {
        Navigator.of(context).pop(const _JoinOutcome.ambiguous());
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a band'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'Paste the code here',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter an invite code'
                  : null,
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}
