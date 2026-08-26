import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/tracks_provider.dart';
import 'track_formatting.dart';

/// Lets any band member edit an existing track's info (TRACK-04). Not
/// owner-gated — see `03-02-PLAN.md`'s objective note resolving the
/// UI-SPEC's inapplicable owner-gating citation.
class EditTrackScreen extends ConsumerStatefulWidget {
  const EditTrackScreen({
    super.key,
    required this.bandId,
    required this.trackId,
    required this.currentTrack,
  });

  final String bandId;
  final String trackId;
  final Map<String, dynamic> currentTrack;

  @override
  ConsumerState<EditTrackScreen> createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends ConsumerState<EditTrackScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.currentTrack['title'] as String?,
  );
  late final _artistController = TextEditingController(
    text: widget.currentTrack['artist'] as String?,
  );
  late final _durationController = TextEditingController(
    text: (widget.currentTrack['durationSeconds'] as int?)?.asMinutesSeconds,
  );
  late final _tempoController = TextEditingController(
    text: (widget.currentTrack['tempo'] as int?)?.toString(),
  );
  late final _notesController = TextEditingController(
    text: widget.currentTrack['notes'] as String?,
  );

  // CR-01 fix: only pre-select the track's `key` value if it's one of the
  // client's 24-entry `musicalKeys` list — the API's `key` field is an
  // unconstrained string (no server-side enum, see track_formatting.dart),
  // so a track edited/created via another client could carry a value
  // outside that list. Passing such a value as DropdownButtonFormField's
  // `initialValue` would trigger an assertion failure since Flutter
  // requires `value` to be null or exactly match a supplied item.
  late String? _selectedKey = musicalKeys.contains(widget.currentTrack['key'])
      ? widget.currentTrack['key'] as String?
      : null;
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
  /// remains valid — Duration stays optional (D-06). Duplicated per-file
  /// (not extracted to a shared helper), matching the existing
  /// _wholeNumberValidator per-file convention.
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
    final durationSeconds = parseDurationSeconds(_durationController.text);
    final tempo = int.tryParse(_tempoController.text.trim());
    final key = _selectedKey;
    final notesText = _notesController.text.trim();
    final notes = notesText.isEmpty ? null : notesText;

    try {
      await ref
          .read(publicApiProvider)
          .updateBandTrack(
            bandId: widget.bandId,
            trackId: widget.trackId,
            title: title,
            artist: artist,
            durationSeconds: durationSeconds,
            tempo: tempo,
            key: key,
            notes: notes,
          );
      // Only merge into the detail provider's cached state if it's already
      // alive — same reasoning as EditBandScreen: reading `.notifier` on a
      // provider that hasn't been created yet would instantiate it and kick
      // off its own network fetch.
      if (ref.exists(trackDetailDataProvider(widget.bandId, widget.trackId))) {
        await ref
            .read(
              trackDetailDataProvider(widget.bandId, widget.trackId).notifier,
            )
            .updateFields({
              'title': title,
              'artist': artist,
              'durationSeconds': durationSeconds,
              'tempo': tempo,
              'key': key,
              'notes': notes,
            });
      }
      // List rows show title/artist/duration, which may have changed;
      // TrackListData has no per-field patch method so invalidate rather
      // than merge.
      if (ref.exists(trackListDataProvider(widget.bandId))) {
        ref.invalidate(trackListDataProvider(widget.bandId));
      }
      // CR-03: also invalidate the global cross-band Tracks tab so an edit
      // made from a band's screens is reflected there without a manual
      // filter change. Guarded with ref.exists() — the global tab may not
      // have been visited yet in this session, and reading .notifier /
      // invalidating a never-instantiated provider would trigger an
      // unwanted network fetch as a side effect.
      if (ref.exists(userTracksListDataProvider)) {
        ref.invalidate(userTracksListDataProvider);
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
    final l10n = AppLocalizations.of(context)!;
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editTrackAppBarTitle)),
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
