import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/tracks_provider.dart';
import 'track_formatting.dart';

class CreateTrackScreen extends ConsumerStatefulWidget {
  const CreateTrackScreen({super.key, required this.bandId});

  final String bandId;

  @override
  ConsumerState<CreateTrackScreen> createState() => _CreateTrackScreenState();
}

class _CreateTrackScreenState extends ConsumerState<CreateTrackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _durationController = TextEditingController();
  final _tempoController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedKey;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationController.dispose();
    _tempoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// WR-02: rejects non-empty, non-whole-number input on the Duration/Tempo
  /// fields instead of silently discarding it (int.tryParse returning null
  /// was previously treated the same as a genuinely blank field). An empty
  /// field remains valid — Duration/Tempo stay optional.
  String? _wholeNumberValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text) == null ? l10n.commonEnterWholeNumber : null;
  }

  /// DUR-02: independently re-validates the mm:ss Duration field at submit
  /// time — DurationTextInputFormatter only shapes keystrokes and cannot
  /// guard against paste or programmatic text assignment. An empty field
  /// remains valid — Duration stays optional (D-06).
  String? _durationValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) {
      return l10n.commonDurationFormatHint;
    }
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) {
      return l10n.commonDurationFormatHint;
    }
    if (minutes < 0 || seconds < 0) {
      return l10n.commonDurationNegative;
    }
    if (seconds > 59) {
      return l10n.commonDurationSecondsRange;
    }
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final notes = _notesController.text.trim();

    try {
      await ref
          .read(publicApiProvider)
          .createBandTrack(
            bandId: widget.bandId,
            title: title,
            artist: artist,
            durationSeconds: parseDurationSeconds(_durationController.text),
            tempo: int.tryParse(_tempoController.text.trim()),
            key: _selectedKey,
            notes: notes.isEmpty ? null : notes,
          );
      ref.invalidate(trackListDataProvider(widget.bandId));
      // CR-03: also invalidate the global cross-band Tracks tab so a newly
      // created track is reflected there without a manual filter change.
      // Guarded with ref.exists() — the global tab may not have been
      // visited yet in this session, and reading .notifier / invalidating a
      // never-instantiated provider would trigger an unwanted network fetch
      // as a side effect.
      if (ref.exists(userTracksListDataProvider)) {
        ref.invalidate(userTracksListDataProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createTrackAddedSnackbar(title))),
      );
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTrackAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.commonTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.commonEnterTrackTitle
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _artistController,
                  decoration: InputDecoration(
                    labelText: l10n.commonArtistLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.commonEnterArtistName
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DurationTextInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.commonDurationLabel,
                    hintText: '0:00',
                    helperText: l10n.commonDurationHelperText,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _durationValidator,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tempoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.commonTempoLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _wholeNumberValidator,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _selectedKey,
                  decoration: InputDecoration(
                    labelText: l10n.commonKeyLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: musicalKeys
                      .map(
                        (key) => DropdownMenuItem(value: key, child: Text(key)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedKey = value),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notesController,
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.commonNotesLabel,
                    border: const OutlineInputBorder(),
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
                                ? l10n.createTrackSaveButton
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
