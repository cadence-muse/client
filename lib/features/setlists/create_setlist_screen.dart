import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart' show maxSetlistTracks;

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
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createSetlistSuccessSnackbar(name))),
      );
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
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMessage = l10n.createSetlistFailedError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));
    final isOnline = ref.watch(isOnlineProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createSetlistAppBarTitle)),
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
                  decoration: InputDecoration(
                    labelText: l10n.commonNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.commonNameRequired
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: l10n.commonLocationLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: l10n.commonDateLabel,
                    hintText: l10n.createSetlistDateHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.createSetlistAddTracksOptionalHeader,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                tracksAsync.when(
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(l10n.createSetlistNoTracksInBand),
                      );
                    }
                    // CreateBandSetlistsRequestBody caps `trackIds` at 100
                    // (publicapi.yml) — guard selection client-side against
                    // that flat cap (WR-03).
                    final atCap = _selectedTrackIds.length >= maxSetlistTracks;
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
                            onChanged:
                                (!_selectedTrackIds.contains(
                                      track['id'] as String,
                                    ) &&
                                    atCap)
                                ? null
                                : (checked) => setState(() {
                                    final trackId = track['id'] as String;
                                    if (checked == true) {
                                      _selectedTrackIds.add(trackId);
                                    } else {
                                      _selectedTrackIds.remove(trackId);
                                    }
                                  }),
                          ),
                        if (atCap)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              l10n.setlistTracksLimit(
                                l10n.trackCount(maxSetlistTracks),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(l10n.commonCouldntLoadTracks)),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            trackListDataProvider(widget.bandId),
                          ),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
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
                    onPressed: (_isSubmitting || !isOnline) ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isOnline
                                ? l10n.commonCreate
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
