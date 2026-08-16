import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
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
    text: (widget.currentTrack['durationSeconds'] as int?)?.toString(),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final durationSeconds = int.tryParse(_durationController.text.trim());
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
      if (!mounted) return;
      Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit track')),
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
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? 'Enter a track title'
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _artistController,
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? 'Enter an artist name'
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tempoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tempo (BPM)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _selectedKey,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                  ),
                  items: musicalKeys
                      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedKey = value),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notesController,
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Notes',
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
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
