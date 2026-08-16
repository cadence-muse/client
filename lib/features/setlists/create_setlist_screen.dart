import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';
import 'setlist_detail_screen.dart';

class CreateSetlistScreen extends ConsumerStatefulWidget {
  const CreateSetlistScreen({super.key, required this.bandId});

  final String bandId;

  @override
  ConsumerState<CreateSetlistScreen> createState() =>
      _CreateSetlistScreenState();
}

class _CreateSetlistScreenState extends ConsumerState<CreateSetlistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();

  final Set<String> _selectedTrackIds = {};
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
    final location = _locationController.text.trim();
    final date = _dateController.text.trim();

    try {
      final response = await ref
          .read(publicApiProvider)
          .createSetlist(
            bandId: widget.bandId,
            name: name,
            eventLocation: location.isEmpty ? null : location,
            eventDate: date.isEmpty ? null : date,
            trackIds: _selectedTrackIds.isEmpty
                ? null
                : _selectedTrackIds.toList(),
          );
      ref.invalidate(setlistListDataProvider(widget.bandId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name created!')));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SetlistDetailScreen(
            bandId: widget.bandId,
            setlistId: response['id'] as String,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Failed to create setlist. Try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));

    return Scaffold(
      appBar: AppBar(title: const Text('Create setlist')),
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
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add tracks (optional)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                tracksAsync.when(
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No tracks in this band yet'),
                      );
                    }
                    return Column(
                      children: [
                        for (final track in tracks)
                          CheckboxListTile(
                            title: Text(
                              track['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artist'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: _selectedTrackIds.contains(
                              track['id'] as String,
                            ),
                            onChanged: (checked) => setState(() {
                              final trackId = track['id'] as String;
                              if (checked == true) {
                                _selectedTrackIds.add(trackId);
                              } else {
                                _selectedTrackIds.remove(trackId);
                              }
                            }),
                          ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No tracks in this band yet'),
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
                      : const Text('Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
