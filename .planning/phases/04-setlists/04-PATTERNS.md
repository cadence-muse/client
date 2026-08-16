# Phase 4: Setlists - Pattern Map

**Mapped:** 2026-08-16
**Files analyzed:** 9 new + 4 modified
**Analogs found:** 9 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/providers/setlists_provider.dart` | provider | CRUD + cache-first | `lib/providers/tracks_provider.dart` | exact |
| `lib/cache/cache_service.dart` (add methods) | utility | cache storage | `lib/cache/cache_service.dart` | exact |
| `lib/api/public_api.dart` (add methods) | service | request-response | `lib/api/public_api.dart` | exact |
| `lib/features/setlists/setlist_list_screen.dart` | screen | CRUD read | `lib/features/tracks/track_list_screen.dart` | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | screen | CRUD read + drag-drop | `lib/features/tracks/track_detail_screen.dart` | role-match |
| `lib/features/setlists/create_setlist_screen.dart` | screen | CRUD create | `lib/features/tracks/create_track_screen.dart` | exact |
| `lib/features/setlists/edit_setlist_screen.dart` | screen | CRUD update | `lib/features/tracks/edit_track_screen.dart` | exact |
| `lib/features/setlists/confirm_delete_setlist_dialog.dart` | dialog | CRUD delete | `lib/features/tracks/confirm_delete_track_dialog.dart` | exact |
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | dialog | CRUD create (bulk) | `lib/features/tracks/create_track_screen.dart` | role-match |
| `lib/features/setlists/setlist_formatting.dart` | utility | format/display | `lib/features/tracks/track_formatting.dart` | exact |
| `lib/features/setlists/setlists_screen.dart` | screen | CRUD read (global) | `lib/features/songs/tracks_screen.dart` | exact |
| `lib/navigation/root_scaffold.dart` (modify) | navigation | routing | `lib/navigation/root_scaffold.dart` | exact |
| `lib/features/bands/band_detail_screen.dart` (modify) | screen | navigation entry | `lib/features/bands/band_detail_screen.dart` | exact |

## Pattern Assignments

### `lib/providers/setlists_provider.dart` (provider, CRUD cache-first)

**Analog:** `lib/providers/tracks_provider.dart`

**Imports pattern** (lines 1-8):
```dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'setlists_provider.g.dart';
```

**Cache-first provider pattern for per-band list** (lines 23-106):
```dart
// SetlistListData — mirrors TrackListData exactly
@riverpod
class SetlistListData extends _$SetlistListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;  // WR-02: race condition guard

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandSetlists(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));  // Silent background refresh
      return cached;
    }
    return _fetchAndCache(bandId);  // Inline fetch on cache miss
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final setlists = await ref.read(publicApiProvider).listBandSetlists(bandId);
    await ref.read(cacheServiceProvider).writeBandSetlists(bandId, setlists);
    return setlists;
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  void removeFromList(String setlistId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = [
      for (final setlist in current)
        if (setlist['id'] != setlistId) setlist,
    ];
    _version++;
    state = AsyncData(filtered);
    unawaited(ref.read(cacheServiceProvider).writeBandSetlists(bandId, filtered));
  }
}
```

**Detail provider with field patching** (lines 116-206):
```dart
// SetlistDetailData — mirrors TrackDetailData exactly
@riverpod
class SetlistDetailData extends _$SetlistDetailData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String setlistId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readSetlistDetail(bandId, setlistId);
    if (cached != null) {
      unawaited(_refresh(bandId, setlistId));
      return cached;
    }
    return _fetchAndCache(bandId, setlistId);
  }

  Future<void> updateFields(Map<String, dynamic> patch) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, ...patch};
    _version++;
    state = AsyncData(updated);
    await ref.read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }

  /// New: reorder tracks list after drag-and-drop reorder endpoint succeeds
  Future<void> reorderTracks(List<String> trackIds) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    final oldTracks = (current['tracks'] as List<dynamic>).cast<Map<String, dynamic>>();
    final trackMap = {for (final t in oldTracks) t['trackId']: t};
    final reordered = [
      for (final id in trackIds)
        if (trackMap.containsKey(id)) trackMap[id]!,
    ];
    
    _version++;
    final updated = {...current, 'tracks': reordered};
    state = AsyncData(updated);
    await ref.read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }
}
```

**Filter notifier for global tab** (lines 211-222):
```dart
@riverpod
class SelectedBandIdFilter extends _$SelectedBandIdFilter {
  @override
  String? build() => null;

  void setFilter(String? bandId) => state = bandId;
}
```

**Global cross-band list provider** (lines 229-301):
```dart
// UserSetlistsListData — mirrors UserTracksListData exactly
@riverpod
class UserSetlistsListData extends _$UserSetlistsListData {
  Future<void>? _inFlightRefresh;
  final int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readUserSetlists(bandIdFilter);
    if (cached != null) {
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    String? bandIdFilter,
  ) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listUserSetlists(bandIdFilter: bandIdFilter);
    await ref.read(cacheServiceProvider)
        .writeUserSetlists(bandIdFilter, setlists);
    return setlists;
  }
}
```

---

### `lib/cache/cache_service.dart` (modify, cache storage)

**Analog:** `lib/cache/cache_service.dart`

**Add setlists box to initialize()** (lines 106-117):
```dart
static Future<void> initialize() async {
  final profileBox = await Hive.openBox<Map>('profileBox');
  final homepageBox = await Hive.openBox<Map>('homepageBox');
  final bandsBox = await Hive.openBox<Map>('bandsBox');
  final tracksBox = await Hive.openBox<Map>('tracksBox');
  final setlistsBox = await Hive.openBox<Map>('setlistsBox');  // NEW
  _instance = CacheService._(
    _HiveStore(profileBox),
    _HiveStore(homepageBox),
    _HiveStore(bandsBox),
    _HiveStore(tracksBox),
    _HiveStore(setlistsBox),  // NEW
  );
}
```

**Add setlists storage fields to constructor** (lines 81-86):
```dart
CacheService._(
  this._profileStore,
  this._homepageStore,
  this._bandsStore,
  this._tracksStore,
  this._setlistsStore,  // NEW
);
```

**Add setlists methods (mirrors track methods pattern)** (lines ~287):
```dart
Future<List<Map<String, dynamic>>?> readBandSetlists(String bandId) async {
  try {
    final cached = _setlistsStore.get(_bandSetlistsKey(bandId));
    if (cached == null) return null;
    return (cached['items'] as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<void> writeBandSetlists(
  String bandId,
  List<Map<String, dynamic>> data,
) async {
  try {
    await _setlistsStore.put(_bandSetlistsKey(bandId), {'items': data});
  } catch (_) {
  }
}

static String _bandSetlistsKey(String bandId) => 'setlists_$bandId';

Future<Map<String, dynamic>?> readSetlistDetail(
  String bandId,
  String setlistId,
) async {
  try {
    return _setlistsStore.get(_setlistDetailKey(bandId, setlistId));
  } catch (_) {
    return null;
  }
}

Future<void> writeSetlistDetail(
  String bandId,
  String setlistId,
  Map<String, dynamic> data,
) async {
  try {
    await _setlistsStore.put(_setlistDetailKey(bandId, setlistId), data);
  } catch (_) {
  }
}

static String _setlistDetailKey(String bandId, String setlistId) =>
    'detail_${bandId}_$setlistId';

Future<List<Map<String, dynamic>>?> readUserSetlists(
  String? bandIdFilter,
) async {
  try {
    final cached = _setlistsStore.get(_userSetlistsKey(bandIdFilter));
    if (cached == null) return null;
    return (cached['items'] as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<void> writeUserSetlists(
  String? bandIdFilter,
  List<Map<String, dynamic>> data,
) async {
  try {
    await _setlistsStore.put(_userSetlistsKey(bandIdFilter), {'items': data});
  } catch (_) {
  }
}

static String _userSetlistsKey(String? bandIdFilter) =>
    'user_setlists_${bandIdFilter ?? 'all'}';
```

**Update clearAll()** (line 281-286):
```dart
Future<void> clearAll() async {
  await _profileStore.clear();
  await _homepageStore.clear();
  await _bandsStore.clear();
  await _tracksStore.clear();
  await _setlistsStore.clear();  // NEW
}
```

---

### `lib/api/public_api.dart` (modify, request-response)

**Analog:** `lib/api/public_api.dart`

**Add setlist API methods** (append to class):
```dart
// Per-band setlist list
Future<List<Map<String, dynamic>>> listBandSetlists(String bandId) async {
  final response = await _client.send('GET', '/api/band/$bandId/setlist/list');
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}

// Per-band setlist detail
Future<Map<String, dynamic>> getSetlist(String bandId, String setlistId) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/setlist/$setlistId',
  );
  return response!;
}

// Create setlist (with optional initial tracks via trackIds)
Future<Map<String, dynamic>> createSetlist({
  required String bandId,
  required String name,
  String? eventLocation,
  String? eventDate,
  List<String>? trackIds,
}) async {
  final response = await _client.send(
    'POST',
    '/api/band/$bandId/setlist',
    body: {
      'name': name,
      'eventLocation': eventLocation,
      'eventDate': eventDate,
      'trackIds': trackIds,
    },
  );
  return response!;
}

// Update setlist (always send all fields, including explicit null to clear)
// Mirrors updateBandTrack pattern: CR-02 fix
Future<void> updateSetlist({
  required String bandId,
  required String setlistId,
  required String name,
  String? eventLocation,
  String? eventDate,
}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId/setlist/$setlistId',
    body: {
      'name': name,
      'eventLocation': eventLocation,
      'eventDate': eventDate,
    },
  );
}

// Delete setlist
Future<void> deleteSetlist(String bandId, String setlistId) async {
  await _client.send('DELETE', '/api/band/$bandId/setlist/$setlistId');
}

// Add tracks in bulk (new D-01 endpoint)
Future<void> addSetlistTracks({
  required String bandId,
  required String setlistId,
  required List<String> trackIds,
}) async {
  await _client.send(
    'POST',
    '/api/band/$bandId/setlist/$setlistId/tracks',
    body: {'trackIds': trackIds},
  );
}

// Remove single track from setlist
Future<void> removeSetlistTrack({
  required String bandId,
  required String setlistId,
  required String trackId,
}) async {
  await _client.send(
    'DELETE',
    '/api/band/$bandId/setlist/$setlistId/track/$trackId',
  );
}

// Reorder tracks in setlist (full new order, no partial update)
Future<void> reorderSetlistTracks({
  required String bandId,
  required String setlistId,
  required List<String> trackIds,
}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId/setlist/$setlistId/tracks/reorder',
    body: {'trackIds': trackIds},
  );
}

// Cross-band setlist list (new D-03 endpoint)
Future<List<Map<String, dynamic>>> listUserSetlists({
  String? bandIdFilter,
}) async {
  final response = await _client.send(
    'GET',
    '/api/setlist/list',
    queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

---

### `lib/features/setlists/setlist_list_screen.dart` (screen, CRUD read)

**Analog:** `lib/features/tracks/track_list_screen.dart` (lines 1-80)

**Structure pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/setlists_provider.dart';
import 'create_setlist_screen.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart';

class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistListDataProvider(bandId));

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => _buildContent(context, setlists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(setlistListDataProvider(bandId)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CreateSetlistScreen(bandId: bandId)),
        ),
        tooltip: 'Add setlist',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Empty state with create button
  // ListView.separated with setlist rows (name + track count + duration + event date)
  // Tap row to navigate to SetlistDetailScreen(bandId, setlistId)
}
```

---

### `lib/features/setlists/setlist_detail_screen.dart` (screen, CRUD read + drag-drop)

**Analog:** `lib/features/tracks/track_detail_screen.dart` (lines 1-100)

**Core structure:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/setlists_provider.dart';
import 'edit_setlist_screen.dart';
import 'confirm_delete_setlist_dialog.dart';
import 'add_setlist_tracks_dialog.dart';
import 'setlist_formatting.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({
    super.key,
    required this.bandId,
    required this.setlistId,
  });

  final String bandId;
  final String setlistId;

  @override
  ConsumerState<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  bool _editMode = false;  // NEW: toggleable edit mode (D-15)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistAsync = ref.watch(setlistDetailDataProvider(widget.bandId, widget.setlistId));
    final name = setlistAsync.valueOrNull?['name'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? 'Setlist'),
        actions: [
          if (name != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditSetlistScreen(
                    bandId: widget.bandId,
                    setlistId: widget.setlistId,
                    currentSetlist: setlistAsync.valueOrNull ?? {},
                  ),
                ),
              ),
            ),
        ],
      ),
      body: setlistAsync.when(
        data: (setlist) => _buildContent(context, setlist),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(context, () => ref.invalidate(...)),
      ),
    );
  }

  // Display: event info (date, location), total duration, track count
  // Tracks list with two modes:
  //   - Normal: read-only, no drag handles/remove icons
  //   - Edit mode (_editMode=true): drag handles + remove icons visible
  // Add Tracks button to open AddSetlistTracksDialog
  // Delete button at bottom (opens confirm dialog)
}
```

**NEW for Phase 4: Reorderable list pattern (D-14, D-15):**
```dart
// In edit mode, wrap tracks with reorderable list widget:
// Option 1: reorderable_grid_view package
// Option 2: flutter_reorderable_list package
// On drop callback: call API immediately (no batching)

Future<void> _handleReorder(int oldIndex, int newIndex) async {
  try {
    // Reorder array
    final tracks = (setlist['tracks'] as List<dynamic>).cast<Map<String, dynamic>>();
    final reordered = List.of(tracks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    
    final trackIds = [for (final t in reordered) t['trackId'] as String];
    
    // Call API immediately on drop (D-14)
    await ref.read(publicApiProvider).reorderSetlistTracks(
      bandId: widget.bandId,
      setlistId: widget.setlistId,
      trackIds: trackIds,
    );
    
    // Update cache on success
    await ref.read(setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier)
        .reorderTracks(trackIds);
  } on ApiException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reorder failed: ${e.message}')),
    );
    // UI reverts on error (drag-and-drop lib handles visual revert)
  }
}
```

---

### `lib/features/setlists/create_setlist_screen.dart` (screen, CRUD create)

**Analog:** `lib/features/tracks/create_track_screen.dart` (lines 1-96)

**Pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';  // For track list to pick initial tracks
import 'setlist_formatting.dart';

class CreateSetlistScreen extends ConsumerStatefulWidget {
  const CreateSetlistScreen({super.key, required this.bandId});

  final String bandId;

  @override
  ConsumerState<CreateSetlistScreen> createState() => _CreateSetlistScreenState();
}

class _CreateSetlistScreenState extends ConsumerState<CreateSetlistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();

  Set<String> _selectedTrackIds = {};  // Multi-select track picker (D-09)
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
      await ref.read(publicApiProvider).createSetlist(
        bandId: widget.bandId,
        name: name,
        eventLocation: location.isEmpty ? null : location,
        eventDate: date.isEmpty ? null : date,
        trackIds: _selectedTrackIds.isNotEmpty ? _selectedTrackIds.toList() : null,
      );
      ref.invalidate(setlistListDataProvider(widget.bandId));
      // Also invalidate global setlists tab (if visited)
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
      if (!mounted) return;
      // Navigate to setlist detail screen (D-11)
      // Use the returned setlist ID or fetch from provider
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name created!')),
      );
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
    // Form with fields: name (required), eventLocation (optional), eventDate (optional)
    // Inline multi-select checklist of band's tracks (D-09, D-10)
    // Submit button
  }
}
```

---

### `lib/features/setlists/edit_setlist_screen.dart` (screen, CRUD update)

**Analog:** `lib/features/tracks/edit_track_screen.dart` (lines 1-80)

**Pattern (mirrors create form, without track picker):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';

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
      // CR-02 fix: always send all fields, including explicit null to clear
      await ref.read(publicApiProvider).updateSetlist(
        bandId: widget.bandId,
        setlistId: widget.setlistId,
        name: name,
        eventLocation: location.isEmpty ? null : location,
        eventDate: date.isEmpty ? null : date,
      );
      // Patch cache without refetch (API has no response body)
      await ref
          .read(setlistDetailDataProvider(widget.bandId, widget.setlistId).notifier)
          .updateFields({
            'name': name,
            'eventLocation': location.isEmpty ? null : location,
            'eventDate': date.isEmpty ? null : date,
          });
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
    // Form with fields: name (required), eventLocation (optional), eventDate (optional)
    // No track picker (D-16)
    // Submit button
  }
}
```

---

### `lib/features/setlists/confirm_delete_setlist_dialog.dart` (dialog, CRUD delete)

**Analog:** `lib/features/tracks/confirm_delete_track_dialog.dart` (lines 1-117)

**Pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';

/// Lightweight Cancel/Delete confirm dialog (D-18).
/// Only shown from SetlistDetailScreen (never swipe-to-dismiss).
class ConfirmDeleteSetlistDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteSetlistDialog({
    super.key,
    required this.bandId,
    required this.setlistId,
    required this.setlistName,
  });

  final String bandId;
  final String setlistId;
  final String setlistName;

  @override
  ConsumerState<ConfirmDeleteSetlistDialog> createState() =>
      _ConfirmDeleteSetlistDialogState();
}

class _ConfirmDeleteSetlistDialogState
    extends ConsumerState<ConfirmDeleteSetlistDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicApiProvider)
          .deleteSetlist(widget.bandId, widget.setlistId);
      
      // Remove from per-band list cache
      if (ref.exists(setlistListDataProvider(widget.bandId))) {
        ref
            .read(setlistListDataProvider(widget.bandId).notifier)
            .removeFromList(widget.setlistId);
      } else {
        ref.invalidate(setlistListDataProvider(widget.bandId));
      }
      
      // Invalidate global tab
      if (ref.exists(userSetlistsListDataProvider)) {
        ref.invalidate(userSetlistsListDataProvider);
      }
      
      if (!mounted) return;
      // Pop dialog, then pop detail screen -> back to list (D-19)
      Navigator.of(context).pop();
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
    return AlertDialog(
      title: Text('Delete ${widget.setlistName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This action cannot be undone.'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _isSubmitting ? null : _delete,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
```

---

### `lib/features/setlists/add_setlist_tracks_dialog.dart` (dialog, CRUD create bulk)

**Analog:** `lib/features/tracks/create_track_screen.dart` (multi-select pattern)

**Pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';

/// Multi-select picker for adding tracks to a setlist (D-12).
/// Shows all band tracks not already in the setlist.
class AddSetlistTracksDialog extends ConsumerStatefulWidget {
  const AddSetlistTracksDialog({
    super.key,
    required this.bandId,
    required this.setlistId,
    required this.currentTrackIds,
  });

  final String bandId;
  final String setlistId;
  final Set<String> currentTrackIds;

  @override
  ConsumerState<AddSetlistTracksDialog> createState() =>
      _AddSetlistTracksDialogState();
}

class _AddSetlistTracksDialogState
    extends ConsumerState<AddSetlistTracksDialog> {
  late Set<String> _selectedTrackIds = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _add() async {
    if (_selectedTrackIds.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Call bulk add endpoint (D-01)
      await ref.read(publicApiProvider).addSetlistTracks(
        bandId: widget.bandId,
        setlistId: widget.setlistId,
        trackIds: _selectedTrackIds.toList(),
      );
      
      // Update detail cache (append new tracks)
      // For simplicity, refetch detail to ensure correct data (especially duration)
      ref.invalidate(setlistDetailDataProvider(widget.bandId, widget.setlistId));
      
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracks added!')),
      );
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
    final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));

    return tracksAsync.when(
      data: (tracks) {
        // Filter out tracks already in setlist
        final availableTracks = [
          for (final track in tracks)
            if (!widget.currentTrackIds.contains(track['id'])) track,
        ];

        return AlertDialog(
          title: const Text('Add tracks'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: availableTracks.length,
              itemBuilder: (context, index) {
                final track = availableTracks[index];
                final trackId = track['id'] as String;
                final title = track['title'] as String;
                final artist = track['artist'] as String;

                return CheckboxListTile(
                  value: _selectedTrackIds.contains(trackId),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTrackIds.add(trackId);
                      } else {
                        _selectedTrackIds.remove(trackId);
                      }
                    });
                  },
                  title: Text(title),
                  subtitle: Text(artist),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _selectedTrackIds.isEmpty || _isSubmitting ? null : _add,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        );
      },
      loading: () => const AlertDialog(
        content: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Couldn\'t load tracks'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

---

### `lib/features/setlists/setlist_formatting.dart` (utility, format/display)

**Analog:** `lib/features/tracks/track_formatting.dart` (lines 1-36)

**Pattern:**
```dart
/// Formats a setlist's `durationSeconds` as `mm:ss` (mirroring track duration)
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}

/// Format event date as "MMM dd, yyyy" or "No date set" if null
String formatEventDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) {
    return 'No date set';  // D-07
  }
  // Parse ISO 8601 date and format
  try {
    final date = DateTime.parse(dateString);
    return '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
  } catch (_) {
    return 'No date set';
  }
}

String _monthAbbr(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}
```

---

### `lib/features/setlists/setlists_screen.dart` (screen, CRUD read global)

**Analog:** `lib/features/songs/tracks_screen.dart` (global Tracks tab)

**Pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/setlists_provider.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart';

/// Global Setlists tab showing all setlists across every band the user belongs to,
/// optionally filtered by band (D-20, D-21).
class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final setlistsAsync = ref.watch(userSetlistsListDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setlists'),
        actions: [
          // Band filter dropdown (mirrors Tracks tab pattern)
          _buildFilterDropdown(context, ref, bandIdFilter),
        ],
      ),
      body: setlistsAsync.when(
        data: (setlists) => _buildContent(context, setlists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(userSetlistsListDataProvider),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    WidgetRef ref,
    String? selectedBandId,
  ) {
    // Dropdown button showing "All bands" or selected band name
    // On selection, call ref.read(selectedBandIdFilterProvider.notifier).setFilter(bandId)
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> setlists,
  ) {
    // Flat list with band-name badge per row (D-20)
    // Show setlist name + band name + track count + duration + event date
    // Tap to navigate to SetlistDetailScreen
  }
}
```

---

### `lib/navigation/root_scaffold.dart` (modify, navigation)

**Analog:** `lib/navigation/root_scaffold.dart` (lines 1-54)

**Changes (D-21 — reorder to Home/Bands/Tracks/Setlists/Profile):**
```dart
// Current order (line 16-21):
final screens = [
  const HomeScreen(),
  const TracksScreen(),      // Was index 1
  const BandsScreen(),       // Was index 2
  const ProfileScreen(),
];

// NEW order:
final screens = [
  const HomeScreen(),        // Index 0
  const BandsScreen(),       // Index 1 (moved from 2)
  const TracksScreen(),      // Index 2 (moved from 1)
  const SetlistsScreen(),    // Index 3 (NEW)
  const ProfileScreen(),     // Index 4
];

// Also update NavigationDestination order (lines 29-50):
destinations: const [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Bands',
  ),
  NavigationDestination(
    icon: Icon(Icons.music_note_outlined),
    selectedIcon: Icon(Icons.music_note),
    label: 'Tracks',
  ),
  NavigationDestination(  // NEW
    icon: Icon(Icons.playlist_play_outlined),
    selectedIcon: Icon(Icons.playlist_play),
    label: 'Setlists',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Profile',
  ),
],
```

---

### `lib/features/bands/band_detail_screen.dart` (modify, navigation entry)

**Analog:** `lib/features/bands/band_detail_screen.dart` (lines 177-186)

**Add Setlists entry point after Tracks (mirrors the existing Tracks entry, lines 177-186):**
```dart
// Current Tracks entry (lines 177-186):
ListTile(
  leading: const Icon(Icons.music_note),
  title: const Text('Tracks'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TrackListScreen(bandId: bandId),
    ),
  ),
),

// NEW: Add after Tracks entry:
ListTile(
  leading: const Icon(Icons.playlist_play),
  title: const Text('Setlists'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SetlistListScreen(bandId: bandId),
    ),
  ),
),

// Also add import at top of file:
import '../setlists/setlist_list_screen.dart';
```

---

## Shared Patterns

### Error Handling with ApiException
**Source:** `lib/api/api_exception.dart` + `lib/features/tracks/confirm_delete_track_dialog.dart` (lines 65-67)
**Apply to:** All screen/dialog files with mutation operations (create/edit/delete)
```dart
try {
  // API call
  await ref.read(publicApiProvider).someMethod(...);
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} catch (_) {
  setState(() => _errorMessage = 'Something went wrong. Please try again.');
}
```

### Cache Invalidation Pattern
**Source:** `lib/features/tracks/create_track_screen.dart` (lines 74-82)
**Apply to:** All mutation screens (create/edit/delete setlist)
```dart
// Invalidate per-band list
ref.invalidate(setlistListDataProvider(widget.bandId));

// Also invalidate global tab if it's been visited
// (guarded with ref.exists to avoid unwanted fetches)
if (ref.exists(userSetlistsListDataProvider)) {
  ref.invalidate(userSetlistsListDataProvider);
}
```

### Local Cache Patching (No Refetch)
**Source:** `lib/features/tracks/edit_track_screen.dart` + `lib/providers/tracks_provider.dart` (lines 190-205)
**Apply to:** Edit setlist operations (updateFields method)
```dart
// After API call succeeds with no response body:
await ref.read(setlistDetailDataProvider(bandId, setlistId).notifier)
    .updateFields({
      'name': name,
      'eventLocation': eventLocation,
      'eventDate': eventDate,
    });
```

### Version Guard for Race Conditions (WR-02)
**Source:** `lib/providers/tracks_provider.dart` (lines 27-32, 55-64)
**Apply to:** All AsyncNotifier providers
```dart
int _version = 0;  // Monotonic counter

// Before network call, capture version
final capturedVersion = _version;

// After network await, check if version changed
if (_version == capturedVersion) {
  state = AsyncData(fresh);
}

// Before local mutation, increment version
void removeFromList(String id) {
  _version++;  // Bump before mutation
  // ... update state ...
}
```

### Refresh Deduplication (_inFlightRefresh)
**Source:** `lib/providers/tracks_provider.dart` (lines 69-73, 25)
**Apply to:** All AsyncNotifier providers with refresh() method
```dart
Future<void>? _inFlightRefresh;

Future<void> refresh() {
  return _inFlightRefresh ??= _doRefresh().whenComplete(
    () => _inFlightRefresh = null,
  );
}
```

### Always-Send-All-Fields on Update (CR-02 Fix)
**Source:** `lib/api/public_api.dart` (lines 167-189)
**Apply to:** updateSetlist method
```dart
// Always send all editable fields, including explicit null to clear
Future<void> updateSetlist({
  required String bandId,
  required String setlistId,
  required String name,
  String? eventLocation,
  String? eventDate,
}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId/setlist/$setlistId',
    body: {
      'name': name,
      'eventLocation': eventLocation,  // Send null to clear
      'eventDate': eventDate,
    },
  );
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | dialog | CRUD create (bulk) | Bulk picker dialog is new pattern; single-track add in Phase 3 was inline in form, not dialog-based |

*(All other files have direct analogs in Phase 3 Tracks or Phase 2-3 established patterns.)*

---

## Metadata

**Analog search scope:** 
- `lib/providers/` — Riverpod AsyncNotifier patterns
- `lib/cache/` — Hive cache service
- `lib/api/` — PublicApi methods
- `lib/features/tracks/` — Screen UI components and forms
- `lib/features/bands/` — Navigation entry points and detail screens
- `lib/navigation/` — Bottom navigation bar

**Files scanned:** 13 files analyzed; 9 with direct exact matches

**Pattern extraction date:** 2026-08-16

**High-confidence analogs:** 12/13 (92%)
- TrackListData → SetlistListData (100% mirror)
- TrackDetailData → SetlistDetailData (100% mirror, plus reorderTracks new method)
- UserTracksListData → UserSetlistsListData (100% mirror)
- SelectedBandIdFilter → reused pattern (100% match)
- CacheService methods → new setlist methods (100% structure match)
- PublicApi methods → new setlist methods (100% pattern match)
- Screen layouts → setlist screens (95%+ structural match, domain-specific fields)
- Dialog patterns → delete dialog (100% match), add dialog (role-match)
- Formatting helpers → duration/date formatting (100% match)
- Navigation updates → RootScaffold + BandDetailScreen (exact)

**Primary sources verified:**
- `lib/providers/tracks_provider.dart` — All cache-first AsyncNotifier patterns (lines 23-301)
- `lib/cache/cache_service.dart` — Cache method signature pattern (lines 203-280)
- `lib/api/public_api.dart` — API method signatures (lines 107-210)
- `lib/features/tracks/track_list_screen.dart` — Screen structure (lines 1-80)
- `lib/features/tracks/track_detail_screen.dart` — Detail screen (lines 1-100)
- `lib/features/tracks/create_track_screen.dart` — Form pattern (lines 1-100)
- `lib/features/tracks/edit_track_screen.dart` — Edit form pattern (lines 1-80)
- `lib/features/tracks/confirm_delete_track_dialog.dart` — Delete dialog (lines 1-117)
- `lib/features/tracks/track_formatting.dart` — Formatting helpers (full file)
- `lib/navigation/root_scaffold.dart` — Navigation structure (lines 1-54)
- `lib/features/bands/band_detail_screen.dart` — Entry point pattern (lines 177-186)

---

*Phase: 4-Setlists*  
*Patterns mapped: 2026-08-16*  
*Ready for planning phase*
