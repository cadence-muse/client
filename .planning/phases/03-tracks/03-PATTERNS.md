# Phase 3: Tracks - Pattern Map

**Mapped:** 2026-08-16  
**Files analyzed:** 13 new/modified files  
**Analogs found:** 11 / 13 (comprehensive coverage from Phase 2)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/api/publicapi.yml` | config | API contract | (existing, extend) | exact |
| `lib/api/public_api.dart` | service | CRUD (request-response) | `src/api/public_api.dart` | exact |
| `lib/cache/cache_service.dart` | service | CRUD (file-I/O) | (existing, extend) | exact |
| `lib/providers/tracks_provider.dart` | provider | CRUD (cache-first) | `lib/providers/bands_provider.dart` | exact |
| `lib/features/tracks/track_list_screen.dart` | screen | request-response (cache-first) | `lib/features/bands/bands_screen.dart` | exact |
| `lib/features/tracks/track_detail_screen.dart` | screen | request-response (cache-first) | `lib/features/bands/band_detail_screen.dart` | exact |
| `lib/features/tracks/create_track_screen.dart` | screen | request-response (form) | `lib/features/bands/create_band_screen.dart` | exact |
| `lib/features/tracks/edit_track_screen.dart` | screen | request-response (form) | `lib/features/bands/edit_band_screen.dart` | exact |
| `lib/features/tracks/confirm_delete_track_dialog.dart` | component | request-response (mutation) | `lib/features/bands/confirm_leave_band_dialog.dart` | exact |
| `lib/features/tracks/track_avatar.dart` | component | UI-only | `lib/features/bands/band_avatar.dart` | exact |
| `lib/features/songs/songs_screen.dart` (rename → `tracks_screen.dart`) | screen | request-response (cache-first) | `lib/features/bands/bands_screen.dart` | adaptation |
| `lib/navigation/root_scaffold.dart` | navigation | UI-only | (existing, modify) | exact |
| `test/providers/tracks_provider_test.dart` | test | unit | `test/widget_test.dart` (existing test patterns) | role-match |

---

## Pattern Assignments

### `lib/api/publicapi.yml` (config, API contract) — EXTEND EXISTING

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/api/publicapi.yml`

**Scope:** Add new endpoint definitions for track CRUD (6 new endpoints) following existing OpenAPI 3.0 schema structure.

**Pattern:** Mirror existing `Band` endpoint definitions (path structure, request/response bodies, status codes). All schemas use raw JSON (no TypeAdapters).

**New endpoints to add:**
- `GET /api/band/{bandId}/track/list` → `ListBandTracksResponseBody` (`items: TrackListItem[]`)
- `GET /api/band/{bandId}/track/{trackId}` → `BandTrack` (full detail)
- `POST /api/band/{bandId}/track` → `CreateBandTrackRequestBody` / `CreateBandTrackResponseBody` (`{id}`)
- `PUT /api/band/{bandId}/track/{trackId}` → `UpdateBandTrackRequestBody` / `204` no content
- `DELETE /api/band/{bandId}/track/{trackId}` → `204` no content
- `GET /api/track/list` (global) → `ListUserTracksResponseBody` (`items: UserTrackListItem[]`, each extending `TrackListItem` with `bandId`/`bandName`)

**Citation:** CONTEXT.md D-01, RESEARCH.md sections on API contract and code examples.

---

### `lib/api/public_api.dart` (service, CRUD request-response) — EXTEND EXISTING

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/api/public_api.dart`

**Analog:** `lib/api/public_api.dart` lines 41-104 (existing band methods)

**Pattern:** Add 6 new methods following the existing style (async Future return types, named parameters, request/response handling via `_client.send()`).

**Imports pattern** (lines 1-8, already exists):
```dart
import 'api_client.dart';
```

**Core CRUD pattern for list method** (mirror of lines 41-44):
```dart
/// Returns the list of tracks in a band (TrackListItem — id, title, artist, durationSeconds).
Future<List<Map<String, dynamic>>> listBandTracks(String bandId) async {
  final response = await _client.send('GET', '/api/band/$bandId/track/list');
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Core CRUD pattern for get detail** (mirror of lines 48-51):
```dart
/// Returns full track detail (BandTrack — id, title, artist, duration, tempo, key, notes).
Future<Map<String, dynamic>> getBandTrack(String bandId, String trackId) async {
  final response = await _client.send('GET', '/api/band/$bandId/track/$trackId');
  return response!;
}
```

**Core CRUD pattern for create** (mirror of lines 55-62):
```dart
/// Creates a new track. Returns the raw CreateBandTrackResponseBody map ({id}).
Future<Map<String, dynamic>> createBandTrack({
  required String bandId,
  required String title,
  required String artist,
  int? durationSeconds,
  int? tempo,
  String? key,
  String? notes,
}) async {
  final response = await _client.send(
    'POST',
    '/api/band/$bandId/track',
    body: {
      'title': title,
      'artist': artist,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (tempo != null) 'tempo': tempo,
      if (key != null) 'key': key,
      if (notes != null) 'notes': notes,
    },
  );
  return response!;
}
```

**Core CRUD pattern for update** (mirror of lines 81-83):
```dart
/// Updates a track. Response has no content schema; callers merge submitted fields into cache.
Future<void> updateBandTrack({
  required String bandId,
  required String trackId,
  String? title,
  String? artist,
  int? durationSeconds,
  int? tempo,
  String? key,
  String? notes,
}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId/track/$trackId',
    body: {
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (tempo != null) 'tempo': tempo,
      if (key != null) 'key': key,
      if (notes != null) 'notes': notes,
    },
  );
}
```

**Core CRUD pattern for delete** (mirror of lines 89-91):
```dart
/// Deletes a track from a band.
Future<void> deleteBandTrack(String bandId, String trackId) async {
  await _client.send('DELETE', '/api/band/$bandId/track/$trackId');
}
```

**Global list with optional filter** (new pattern, follows band list structure):
```dart
/// Lists all tracks across all user's bands, optionally filtered by bandId.
Future<List<Map<String, dynamic>>> listUserTracks({String? bandIdFilter}) async {
  final uri = '/api/track/list';
  final params = <String, String>{};
  if (bandIdFilter != null) params['bandId'] = bandIdFilter;
  final response = await _client.send('GET', uri, queryParams: params);
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

---

### `lib/cache/cache_service.dart` (service, CRUD file-I/O) — EXTEND EXISTING

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/cache/cache_service.dart`

**Analog:** `lib/cache/cache_service.dart` lines 80-203 (existing cache methods for bands)

**Pattern:** Add a new `_tracksStore` backing store to the `CacheService` constructor, then add read/write methods for three cache entry types: per-band track lists, per-track details, and global user tracks.

**Constructor modification** (lines 81, extend):
```dart
class CacheService {
  CacheService._(
    this._profileStore,
    this._homepageStore,
    this._bandsStore,
    this._tracksStore,  // NEW
  );
```

**Factory override for test double** (lines 87-91, extend):
```dart
@visibleForTesting
factory CacheService.inMemory() => CacheService._(
  _InMemoryStore(),
  _InMemoryStore(),
  _InMemoryStore(),
  _InMemoryStore(),  // NEW
);
```

**Initialize new box** (lines 99-108, extend):
```dart
static Future<void> initialize() async {
  final profileBox = await Hive.openBox<Map>('profileBox');
  final homepageBox = await Hive.openBox<Map>('homepageBox');
  final bandsBox = await Hive.openBox<Map>('bandsBox');
  final tracksBox = await Hive.openBox<Map>('tracksBox');  // NEW
  _instance = CacheService._(
    _HiveStore(profileBox),
    _HiveStore(homepageBox),
    _HiveStore(bandsBox),
    _HiveStore(tracksBox),  // NEW
  );
}
```

**Add track list cache methods** (mirror of lines 156-173):
```dart
/// Per-band track list (cache key: "band_{bandId}"). Returns List<Map<String, dynamic>> from ListBandTracksResponseBody.
Future<List<Map<String, dynamic>>?> readBandTracks(String bandId) async {
  try {
    final cached = _tracksStore.get(_bandTracksKey(bandId));
    if (cached == null) return null;
    return (cached['items'] as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<void> writeBandTracks(String bandId, List<Map<String, dynamic>> data) async {
  try {
    await _tracksStore.put(_bandTracksKey(bandId), {'items': data});
  } catch (_) {
    // Non-critical cache write failure; swallow.
  }
}
```

**Add track detail cache methods** (mirror of lines 175-190):
```dart
/// Full track detail (cache key: "detail_{bandId}_{trackId}").
Future<Map<String, dynamic>?> readBandTrackDetail(String bandId, String trackId) async {
  try {
    return _tracksStore.get(_trackDetailKey(bandId, trackId));
  } catch (_) {
    return null;
  }
}

Future<void> writeBandTrackDetail(String bandId, String trackId, Map<String, dynamic> data) async {
  try {
    await _tracksStore.put(_trackDetailKey(bandId, trackId), data);
  } catch (_) {
    // Non-critical cache write failure; swallow.
  }
}
```

**Add global user tracks cache methods** (new):
```dart
/// Global user tracks, optionally filtered by bandId (cache key: "user_tracks_{bandIdFilter ?? 'all'}").
Future<List<Map<String, dynamic>>?> readUserTracks(String? bandIdFilter) async {
  try {
    final cacheKey = _userTracksKey(bandIdFilter);
    final cached = _tracksStore.get(cacheKey);
    if (cached == null) return null;
    return (cached['items'] as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<void> writeUserTracks(String? bandIdFilter, List<Map<String, dynamic>> data) async {
  try {
    final cacheKey = _userTracksKey(bandIdFilter);
    await _tracksStore.put(cacheKey, {'items': data});
  } catch (_) {
    // Non-critical cache write failure; swallow.
  }
}
```

**Add cache key helpers** (mirror of line 192):
```dart
static String _bandTracksKey(String bandId) => 'band_$bandId';
static String _trackDetailKey(String bandId, String trackId) => 'detail_${bandId}_$trackId';
static String _userTracksKey(String? bandIdFilter) => 'user_tracks_${bandIdFilter ?? 'all'}';
```

**Extend clearAll()** (line 194-198):
```dart
Future<void> clearAll() async {
  await _profileStore.clear();
  await _homepageStore.clear();
  await _bandsStore.clear();
  await _tracksStore.clear();  // NEW
}
```

---

### `lib/providers/tracks_provider.dart` (provider, CRUD cache-first) — NEW FILE

**Analog:** `lib/providers/bands_provider.dart` lines 22-203

**Pattern:** Mirror `BandsListData` and `BandDetailData` exactly for per-band track list caching, per-track detail caching, and global user track list caching. Use family AsyncNotifiers with cache-first loading, background refresh, version guards (WR-02), and in-flight deduplication.

**Imports pattern** (mirror lines 1-8):
```dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'tracks_provider.g.dart';
```

**TrackListData family provider** (mirror of lines 22-113):
```dart
/// Cache-first `GET /api/band/{bandId}/track/list` data, keyed per band.
/// Mirrors BandsListData's cache-first shape: cache hit returns immediately
/// with silent background refresh; cache miss fetches inline (any ApiException
/// becomes an AsyncError).
@riverpod
class TrackListData extends _$TrackListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandTracks(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks);
    return tracks;
  }

  Future<void> _refresh(String bandId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }
}
```

**TrackDetailData family provider** (mirror of lines 123-203):
```dart
/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per band/track.
/// Mirrors BandDetailData's cache-first shape.
@riverpod
class TrackDetailData extends _$TrackDetailData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String trackId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandTrackDetail(bandId, trackId);
    if (cached != null) {
      unawaited(_refresh(bandId, trackId));
      return cached;
    }
    return _fetchAndCache(bandId, trackId);
  }

  Future<Map<String, dynamic>> _fetchAndCache(String bandId, String trackId) async {
    final track = await ref.read(publicApiProvider).getBandTrack(bandId, trackId);
    await ref.read(cacheServiceProvider).writeBandTrackDetail(bandId, trackId, track);
    return track;
  }

  Future<void> _refresh(String bandId, String trackId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId, trackId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId, trackId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }
}
```

**UserTracksListData simple provider** (cache-first global list):
```dart
/// Cache-first `GET /api/track/list` (global tracks) with optional bandId filter.
/// Filter state is stored separately in selectedBandIdFilterProvider.
@riverpod
class UserTracksListData extends _$UserTracksListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final cached = await cache.readUserTracks(bandIdFilter);
    if (cached != null) {
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String? bandIdFilter) async {
    final tracks = await ref.read(publicApiProvider).listUserTracks(bandIdFilter: bandIdFilter);
    await ref.read(cacheServiceProvider).writeUserTracks(bandIdFilter, tracks);
    return tracks;
  }

  Future<void> _refresh(String? bandIdFilter) async {
    try {
      final fresh = await _fetchAndCache(bandIdFilter);
      state = AsyncData(fresh);
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    try {
      final fresh = await _fetchAndCache(null);
      state = AsyncData(fresh);
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }
}

/// Filter state for global tracks (null = all bands).
@riverpod
class SelectedBandIdFilter extends _$SelectedBandIdFilter {
  @override
  String? build() => null;
}
```

---

### `lib/features/tracks/track_list_screen.dart` (screen, request-response cache-first) — NEW FILE

**Analog:** `lib/features/bands/bands_screen.dart` lines 1-80

**Pattern:** ConsumerWidget listing tracks for a specific band. Show title + artist + duration in list rows. Tap row to navigate to `TrackDetailScreen`. "Add Track" button (FAB or app bar button) navigates to `CreateTrackScreen`. Use cache-first `TrackListData` provider.

**Imports pattern** (mirror):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tracks_provider.dart';
import 'track_detail_screen.dart';
import 'create_track_screen.dart';
```

**Core widget structure** (mirror of lines 10-30):
```dart
class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trackListDataProvider(bandId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tracks')),
      body: tracksAsync.when(
        data: (tracks) => _buildContent(context, tracks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(trackListDataProvider(bandId))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CreateTrackScreen(bandId: bandId)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> tracks,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Text('No tracks yet'),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final title = track['title'] as String?;
        final artist = track['artist'] as String?;
        final durationSeconds = track['durationSeconds'] as int?;
        return ListTile(
          title: Text(title ?? 'Untitled'),
          subtitle: Text(artist ?? 'Unknown'),
          trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackDetailScreen(bandId: bandId, trackId: track['id'] as String),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Couldn\'t load tracks.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

---

### `lib/features/tracks/track_detail_screen.dart` (screen, request-response cache-first) — NEW FILE

**Analog:** `lib/features/bands/band_detail_screen.dart` lines 1-73

**Pattern:** ConsumerWidget displaying full track detail (title, artist, duration in mm:ss, tempo, key, notes). Show Edit button (app bar icon) and Delete button. Delete button opens `ConfirmDeleteTrackDialog`. Use cache-first `TrackDetailData` provider.

**Imports pattern** (mirror):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tracks_provider.dart';
import 'edit_track_screen.dart';
import 'confirm_delete_track_dialog.dart';
```

**Core widget structure** (mirror of lines 13-73):
```dart
class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({super.key, required this.bandId, required this.trackId});

  final String bandId;
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackAsync = ref.watch(trackDetailDataProvider(bandId, trackId));
    final title = trackAsync.valueOrNull?['title'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Track'),
        actions: [
          if (title != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditTrackScreen(
                    bandId: bandId,
                    trackId: trackId,
                    currentTrack: trackAsync.valueOrNull!,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: trackAsync.when(
        data: (track) => _buildContent(context, track),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(trackDetailDataProvider(bandId, trackId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> track) {
    final title = track['title'] as String?;
    final artist = track['artist'] as String?;
    final durationSeconds = track['durationSeconds'] as int?;
    final tempo = track['tempo'] as int?;
    final key = track['key'] as String?;
    final notes = track['notes'] as String?;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title ?? 'Untitled', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(artist ?? 'Unknown', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        _buildField(context, 'Duration', durationSeconds?.asMinutesSeconds ?? '—'),
        _buildField(context, 'Tempo', tempo?.toString() ?? '—'),
        _buildField(context, 'Key', key ?? '—'),
        if (notes != null) ...[
          const SizedBox(height: 16),
          _buildField(context, 'Notes', notes),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          icon: const Icon(Icons.delete),
          label: const Text('Delete Track'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => ConfirmDeleteTrackDialog(
              bandId: bandId,
              trackId: trackId,
              trackTitle: title ?? 'Track',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Couldn\'t load track.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

---

### `lib/features/tracks/create_track_screen.dart` (screen, request-response form) — NEW FILE

**Analog:** `lib/features/bands/create_band_screen.dart` lines 1-113

**Pattern:** ConsumerStatefulWidget form with TextFormField inputs for title, artist, durationSeconds, tempo, key (dropdown), and notes. Form validation (title/artist required). On submit, call `PublicApi.createBandTrack()`, invalidate `TrackListData(bandId)`, show snackbar, and navigate to `TrackListScreen(bandId)`. Error handling via `ApiException`.

**Imports pattern** (mirror of lines 1-8):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracks_provider.dart';
import 'track_list_screen.dart';
```

**Core widget structure** (mirror of lines 9-113):
```dart
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
  final _durationSecondsController = TextEditingController();
  final _tempoController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedKey;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationSecondsController.dispose();
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

    try {
      await ref.read(publicApiProvider).createBandTrack(
        bandId: widget.bandId,
        title: title,
        artist: artist,
        durationSeconds: int.tryParse(_durationSecondsController.text),
        tempo: int.tryParse(_tempoController.text),
        key: _selectedKey,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      ref.invalidate(trackListDataProvider(widget.bandId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Track "$title" added!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrackListScreen(bandId: widget.bandId)),
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
    const musicalKeys = [
      'C', 'Cm', 'C#', 'C#m', 'D', 'Dm', 'D#', 'D#m', 'E', 'Em',
      'F', 'Fm', 'F#', 'F#m', 'G', 'Gm', 'G#', 'G#m', 'A', 'Am',
      'A#', 'A#m', 'B', 'Bm',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Add Track')),
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _artistController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Artist *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter an artist' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationSecondsController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tempoController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tempo (BPM)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedKey,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                  ),
                  items: musicalKeys
                      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                      .toList(),
                  onChanged: (newKey) => setState(() => _selectedKey = newKey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                      : const Text('Add Track'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### `lib/features/tracks/edit_track_screen.dart` (screen, request-response form) — NEW FILE

**Analog:** `lib/features/bands/edit_band_screen.dart` lines 1-112

**Pattern:** ConsumerStatefulWidget form with pre-populated fields for title, artist, durationSeconds, tempo, key, and notes. On submit, call `PublicApi.updateBandTrack()`, merge into cache (if provider is alive via `ref.exists()`), and pop back to detail screen. Mirror the `ref.exists()` guard pattern exactly.

**Imports pattern** (mirror of lines 1-6):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/tracks_provider.dart';
```

**Core widget and form pattern** (mirror of lines 11-112):
```dart
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
  late final _titleController = TextEditingController(text: widget.currentTrack['title'] as String?);
  late final _artistController = TextEditingController(text: widget.currentTrack['artist'] as String?);
  late final _durationSecondsController = TextEditingController(
    text: widget.currentTrack['durationSeconds']?.toString() ?? '',
  );
  late final _tempoController = TextEditingController(
    text: widget.currentTrack['tempo']?.toString() ?? '',
  );
  late final _notesController = TextEditingController(text: widget.currentTrack['notes'] as String? ?? '');
  
  late String? _selectedKey = widget.currentTrack['key'] as String?;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationSecondsController.dispose();
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

    try {
      await ref.read(publicApiProvider).updateBandTrack(
        bandId: widget.bandId,
        trackId: widget.trackId,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        durationSeconds: int.tryParse(_durationSecondsController.text),
        tempo: int.tryParse(_tempoController.text),
        key: _selectedKey,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      // Only merge into cache if detail provider is alive (same pattern as edit_band_screen.dart).
      if (ref.exists(trackDetailDataProvider(widget.bandId, widget.trackId))) {
        // Merge updated fields into cached track.
        // Note: UpdateBandTrack has no response body, so we must manually construct the updated track.
        final current = ref.read(trackDetailDataProvider(widget.bandId, widget.trackId)).valueOrNull;
        if (current != null) {
          final updated = {
            ...current,
            'title': _titleController.text.trim(),
            'artist': _artistController.text.trim(),
            if (int.tryParse(_durationSecondsController.text) != null)
              'durationSeconds': int.parse(_durationSecondsController.text),
            if (int.tryParse(_tempoController.text) != null)
              'tempo': int.parse(_tempoController.text),
            if (_selectedKey != null) 'key': _selectedKey,
            if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
          };
          await ref
              .read(cacheServiceProvider)
              .writeBandTrackDetail(widget.bandId, widget.trackId, updated);
          // Manually update state (similar to BandDetailData.updateName pattern).
          ref.read(trackDetailDataProvider(widget.bandId, widget.trackId).notifier).state =
              AsyncData(updated);
        }
      }
      // Also invalidate list to refresh if needed.
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
    const musicalKeys = [
      'C', 'Cm', 'C#', 'C#m', 'D', 'Dm', 'D#', 'D#m', 'E', 'Em',
      'F', 'Fm', 'F#', 'F#m', 'G', 'Gm', 'G#', 'G#m', 'A', 'Am',
      'A#', 'A#m', 'B', 'Bm',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Track')),
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _artistController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Artist *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter an artist' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationSecondsController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tempoController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tempo (BPM)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedKey,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                  ),
                  items: musicalKeys
                      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                      .toList(),
                  onChanged: (newKey) => setState(() => _selectedKey = newKey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                      : const Text('Update Track'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### `lib/features/tracks/confirm_delete_track_dialog.dart` (component, request-response mutation) — NEW FILE

**Analog:** `lib/features/bands/confirm_leave_band_dialog.dart` lines 1-103

**Pattern:** ConsumerStatefulWidget AlertDialog with Cancel and Delete buttons. On delete, call `PublicApi.deleteBandTrack()`, invalidate `TrackListData(bandId)`, pop dialog, then pop detail screen (double-pop pattern). Lightweight confirm (no type-to-confirm).

**Imports pattern** (mirror of lines 1-7):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/tracks_provider.dart';
```

**Core widget and dialog pattern** (mirror of lines 13-103):
```dart
class ConfirmDeleteTrackDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteTrackDialog({
    super.key,
    required this.bandId,
    required this.trackId,
    required this.trackTitle,
  });

  final String bandId;
  final String trackId;
  final String trackTitle;

  @override
  ConsumerState<ConfirmDeleteTrackDialog> createState() =>
      _ConfirmDeleteTrackDialogState();
}

class _ConfirmDeleteTrackDialogState
    extends ConsumerState<ConfirmDeleteTrackDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(publicApiProvider).deleteBandTrack(
        widget.bandId,
        widget.trackId,
      );
      ref.invalidate(trackListDataProvider(widget.bandId));
      if (!mounted) return;
      // Pop the dialog, then pop detail screen — navigation depth is dialog -> detail -> list.
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
      title: Text('Delete "${widget.trackTitle}"?'),
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

### `lib/features/tracks/track_avatar.dart` (component, UI-only) — NEW FILE

**Analog:** `lib/features/bands/band_avatar.dart` lines 1-37

**Pattern:** StatelessWidget avatar for a track list row. Display a colored circle with the track title's first letter. Color is deterministic based on title hash.

**Code** (direct mirror, only name changes):
```dart
import 'package:flutter/material.dart';

/// Avatar for a track list row: a colored circle with the track title's first
/// letter. The background color is picked deterministically from [trackTitle]'s
/// hash, so the same track title always renders the same color.
class TrackAvatar extends StatelessWidget {
  const TrackAvatar({super.key, required this.trackTitle});

  final String trackTitle;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[trackTitle.hashCode.abs() % _colors.length];
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        trackTitle.isEmpty ? '?' : trackTitle[0].toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
```

---

### `lib/features/songs/songs_screen.dart` (rename to `tracks_screen.dart`, screen, request-response cache-first) — MODIFIED

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/features/songs/songs_screen.dart`

**Scope:** Rename file from `songs_screen.dart` to `tracks_screen.dart`. Replace placeholder implementation with global tracks list using `UserTracksListData` provider and `SelectedBandIdFilter` for band filtering.

**Analog:** `lib/features/bands/bands_screen.dart` lines 1-80 (adapted for global view)

**Core pattern** (similar to BandsScreen, but:):
- No create/join actions (only view)
- Add filter dropdown for band selection
- Flat list with band-name badge per row (no grouping)
- Read from `UserTracksListData` and `selectedBandIdFilterProvider`

**Imports pattern**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tracks_provider.dart';
import '../../providers/bands_provider.dart';
import '../tracks/track_detail_screen.dart';
```

**Core widget structure** (mirror of BandsScreen with global list logic):
```dart
class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(userTracksListDataProvider);
    final bandsAsync = ref.watch(bandsListDataProvider);
    final selectedBandId = ref.watch(selectedBandIdFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: selectedBandId,
              hint: const Text('All bands'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All bands')),
                ...bandsAsync.maybeWhen(
                  data: (bands) => bands
                      .map((band) => DropdownMenuItem(
                            value: band['id'] as String,
                            child: Text(band['name'] as String? ?? 'Unknown'),
                          ))
                      .toList(),
                  orElse: () => [],
                ),
              ],
              onChanged: (newBandId) {
                ref.read(selectedBandIdFilterProvider.notifier).state = newBandId;
                ref.invalidate(userTracksListDataProvider);
              },
            ),
          ),
        ),
      ),
      body: tracksAsync.when(
        data: (tracks) => _buildContent(context, tracks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(userTracksListDataProvider)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> tracks,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Text('No tracks'),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final title = track['title'] as String?;
        final artist = track['artist'] as String?;
        final bandName = track['bandName'] as String?;
        final durationSeconds = track['durationSeconds'] as int?;
        return ListTile(
          title: Text(title ?? 'Untitled'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(artist ?? 'Unknown'),
              Text(bandName ?? 'Unknown band', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackDetailScreen(
                bandId: track['bandId'] as String,
                trackId: track['id'] as String,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Couldn\'t load tracks.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

---

### `lib/navigation/root_scaffold.dart` (navigation component, UI-only) — MODIFY EXISTING

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/navigation/root_scaffold.dart`

**Changes:**
1. Line 6: Change import from `songs_screen` to `tracks_screen`:
   ```dart
   import '../features/songs/tracks_screen.dart';  // was songs_screen.dart
   ```

2. Line 22: Change `SongsScreen()` to `TracksScreen()`:
   ```dart
   const TracksScreen(),  // was const SongsScreen(),
   ```

3. Lines 39-43: Change navigation destination label from "Songs" to "Tracks":
   ```dart
   NavigationDestination(
     icon: Icon(Icons.music_note_outlined),
     selectedIcon: Icon(Icons.music_note),
     label: 'Tracks',  // was 'Songs'
   ),
   ```

---

### `lib/features/bands/band_detail_screen.dart` (navigation integration) — MODIFY EXISTING

**File:** `/home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/features/bands/band_detail_screen.dart`

**Changes:**
Add "Tracks" entry point to navigate to `TrackListScreen(bandId)`.

**Pattern:** Mirror the Edit Band entry point (D-02), add a navigation tile or menu item that opens `TrackListScreen(bandId)`.

**Location:** In `_buildContent` method, add before members section (or as a dedicated section):
```dart
// New: Tracks section / navigation entry
ListTile(
  leading: const Icon(Icons.music_note),
  title: const Text('Tracks'),
  trailing: const Icon(Icons.arrow_forward),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TrackListScreen(bandId: bandId),
    ),
  ),
),
```

(Exact location in file structure to be determined during implementation, but mirrors existing navigation patterns.)

---

## Shared Patterns

### Error Handling
**Source:** `lib/api/api_exception.dart` lines 1-32

**Apply to:** All service methods and screen submission handlers

**Pattern:** Catch `ApiException` from `PublicApi` methods, check `statusCode` and `code`, show user-friendly `message` in UI. Re-throw unexpected errors up the stack (handled by error boundaries if added).

**Code excerpt** (from `create_band_screen.dart` lines 52-58):
```dart
try {
  // API call here
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} catch (_) {
  setState(() => _errorMessage = 'Something went wrong. Please try again.');
}
```

### Cache Invalidation
**Source:** `lib/providers/bands_provider.dart` lines 43, 92-112; `lib/features/bands/edit_band_screen.dart` lines 57-67

**Apply to:** All track create/update/delete handlers

**Pattern:** After mutation success, call `ref.invalidate(provider)` to refresh affected cache. Use `ref.exists()` guard to avoid instantiating providers unnecessarily.

**Code excerpt** (from `edit_band_screen.dart` lines 57-67):
```dart
if (ref.exists(bandDetailDataProvider(widget.bandId))) {
  await ref.read(bandDetailDataProvider(widget.bandId).notifier).updateName(name);
}
if (ref.exists(bandsListDataProvider)) {
  ref.read(bandsListDataProvider.notifier).renameBand(widget.bandId, name);
}
```

### Version Guard (WR-02)
**Source:** `lib/providers/bands_provider.dart` lines 31, 54-63, 74-87

**Apply to:** Background refresh logic in all family providers

**Pattern:** Capture `_version` counter before each network await. After await, discard result if `_version` changed (indicating user-initiated state changed during fetch). Prevents background refresh from overwriting local edits.

**Code excerpt** (from `bands_provider.dart` lines 54-63):
```dart
Future<void> _refresh() async {
  final capturedVersion = _version;
  try {
    final fresh = await _fetchAndCache();
    if (_version == capturedVersion) {
      state = AsyncData(fresh);
    }
  } catch (_) {
    // Keep showing cached data.
  }
}
```

### Deep Type Conversion (CR-01)
**Source:** `lib/cache/cache_service.dart` lines 37-47

**Apply to:** All Hive cache reads (already handled by `_HiveStore.get()`)

**Pattern:** Hive's `BinaryReaderImpl` always deserializes to `Map<dynamic, dynamic>` and `List<dynamic>`. Use recursive `_deepConvert()` to normalize nested collections at every depth. This is already implemented in `_HiveStore`, so all new cache methods automatically inherit the fix.

---

## No Analog Found

None. All new files have close analogs in Phase 2 Bands (exact role/data flow match) or are extensions of existing Phase 1/2 infrastructure.

---

## Metadata

**Analog search scope:** `lib/features/bands/`, `lib/providers/`, `lib/api/`, `lib/cache/`, `lib/navigation/`  
**Files scanned:** 9 band screens/dialogs, 1 bands provider, 1 public_api, 1 cache_service, 1 root_scaffold  
**Pattern extraction date:** 2026-08-16

---

*Phase: 3 - Tracks*  
*Pattern mapping complete: Ready for planning*
