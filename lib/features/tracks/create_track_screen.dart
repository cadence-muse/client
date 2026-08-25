import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
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
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text) == null ? 'Enter a whole number' : null;
  }

  /// DUR-02: independently re-validates the mm:ss Duration field at submit
  /// time — DurationTextInputFormatter only shapes keystrokes and cannot
  /// guard against paste or programmatic text assignment. An empty field
  /// remains valid — Duration stays optional (D-06).
  String? _durationValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) {
      return 'Enter duration in mm:ss format (e.g. 0:30)';
    }
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) {
      return 'Enter duration in mm:ss format (e.g. 0:30)';
    }
    if (minutes < 0 || seconds < 0) {
      return 'Duration cannot be negative';
    }
    if (seconds > 59) {
      return 'Seconds must be 0–59 (e.g. 2:30, not 2:75)';
    }
    return null;
  }

  Future<void> _submit() async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title added!')));
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
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add track')),
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
                  inputFormatters: [DurationTextInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    hintText: '0:00',
                    helperText: 'e.g. 2:30 for 2 minutes 30 seconds',
                    border: OutlineInputBorder(),
                  ),
                  validator: _durationValidator,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tempoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tempo (BPM)',
                    border: OutlineInputBorder(),
                  ),
                  validator: _wholeNumberValidator,
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
                Tooltip(
                  message: isOnline ? '' : 'Requires connection',
                  child: FilledButton(
                    onPressed: (!isOnline || _isSubmitting) ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isOnline ? 'Save track' : 'Requires connection'),
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
