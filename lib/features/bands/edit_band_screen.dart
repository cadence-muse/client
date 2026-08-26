import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Lets any band member rename an existing band (BAND-04). Not owner-gated —
/// unlike Delete/Remove-member, updating a band's name has no ownership
/// restriction per REQUIREMENTS.md and ROADMAP.md Phase 2 success criteria #4.
class EditBandScreen extends ConsumerStatefulWidget {
  const EditBandScreen({
    super.key,
    required this.bandId,
    required this.currentName,
  });

  final String bandId;
  final String currentName;

  @override
  ConsumerState<EditBandScreen> createState() => _EditBandScreenState();
}

class _EditBandScreenState extends ConsumerState<EditBandScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.currentName);

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref
          .read(publicApiProvider)
          .updateBand(bandId: widget.bandId, name: name);
      // Only merge into the detail provider's cached state if it's already
      // alive (i.e. the caller — BandDetailScreen — is watching it). Reading
      // `.notifier` on a provider that hasn't been created yet would
      // instantiate it and kick off its own network fetch, which is neither
      // necessary (we already know the new name) nor safe to fire from here.
      if (ref.exists(bandDetailDataProvider(widget.bandId))) {
        await ref
            .read(bandDetailDataProvider(widget.bandId).notifier)
            .updateName(name);
      }
      // Same reasoning as above: only patch bandsListDataProvider if it's
      // already alive (BandsScreen stays mounted in RootScaffold's
      // IndexedStack in real usage, so this is normally a no-op guard).
      if (ref.exists(bandsListDataProvider)) {
        ref
            .read(bandsListDataProvider.notifier)
            .renameBand(widget.bandId, name);
      }
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
    final isOnline = ref.watch(isOnlineProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editBandAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.commonBandNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.commonEnterBandName
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Tooltip(
                  message: isOnline ? '' : l10n.commonRequiresConnection,
                  child: FilledButton(
                    onPressed: (!isOnline || _isSubmitting) ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isOnline
                                ? l10n.commonSave
                                : l10n.commonRequiresConnection,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
