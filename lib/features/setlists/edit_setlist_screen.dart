import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/setlists_provider.dart';

/// Lets any band member edit an existing setlist's info (SETL-04) via a
/// pre-populated full-screen form separate from the create form (D-16). Not
/// owner-gated — see `04-02-PLAN.md`'s objective note resolving the
/// UI-SPEC's inapplicable owner-gating citation.
class EditSetlistScreen extends ConsumerStatefulWidget {
  const EditSetlistScreen({
    super.key,
    required this.bandId,
    required this.setlistId,
    required this.currentSetlist,
  });

  final String bandId;
  final String setlistId;
  final Map<String, dynamic> currentSetlist;

  @override
  ConsumerState<EditSetlistScreen> createState() => _EditSetlistScreenState();
}

class _EditSetlistScreenState extends ConsumerState<EditSetlistScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.currentSetlist['name'] as String?,
  );
  late final _locationController = TextEditingController(
    text: widget.currentSetlist['eventLocation'] as String?,
  );
  late final _dateController = TextEditingController(
    text: widget.currentSetlist['eventDate'] as String?,
  );
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final locationText = _locationController.text.trim();
    final dateText = _dateController.text.trim();
    final eventLocation = locationText.isEmpty ? null : locationText;
    final eventDate = dateText.isEmpty ? null : dateText;

    try {
      await ref
          .read(publicApiProvider)
          .updateSetlist(
            bandId: widget.bandId,
            setlistId: widget.setlistId,
            name: name,
            eventLocation: eventLocation,
            eventDate: eventDate,
          );
      // Only merge into the detail provider's cached state if it's already
      // alive — same reasoning as EditTrackScreen: reading `.notifier` on a
      // provider that hasn't been created yet would instantiate it and kick
      // off its own network fetch.
      if (ref.exists(
        setlistDetailDataProvider(widget.bandId, widget.setlistId),
      )) {
        await ref
            .read(
              setlistDetailDataProvider(
                widget.bandId,
                widget.setlistId,
              ).notifier,
            )
            .updateFields({
              'name': name,
              'eventLocation': eventLocation,
              'eventDate': eventDate,
            });
      }
      // List rows show name/date, which may have changed; SetlistListData
      // has no per-field patch method so invalidate rather than merge.
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        ref.invalidate(setlistListDataProvider(widget.bandId));
      }
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Failed to save setlist. Try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit setlist')),
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
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _dateController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
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
                  message: isOnline ? '' : 'Requires connection',
                  child: FilledButton(
                    onPressed: (_isSubmitting || !isOnline) ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isOnline ? 'Save' : 'Requires connection'),
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
