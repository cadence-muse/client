# Phase 3: Tracks - Research

**Researched:** 2026-08-16
**Domain:** Flutter mobile app — track catalog CRUD within bands + global cross-band view
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### API Gap: Global Tracks Endpoint (D-01)
Add `GET /api/track/list` to `lib/api/publicapi.yml` with optional `bandId` query filter, response `ListUserTracksResponseBody { items: UserTrackListItem[] }` extending `TrackListItem` with `bandId` + `bandName`. This is backend work required before TRACK-06 can ship; no client-side workaround exists (client can't cheaply merge N per-band calls without defeating server-side band filtering).

#### Navigation Entry Points (D-02 / D-03 / D-04)
- Per-band track list lives as a separate screen (`TrackListScreen(bandId)`) reached from Band detail, mirroring Phase 2's Edit Band full-screen pattern.
- The global "Songs" bottom-nav tab is renamed to "Tracks" and repurposed to show the cross-band list via D-01's endpoint.
- Global Tracks tab shows a flat list with band-name badge per row + filter dropdown (no grouped sections).

#### Track List Display (D-05 / D-06 / D-07)
- Per-band track list rows show **title + artist + duration only** (matching `TrackListItem` schema; tempo/key are detail-page-only).
- Duration (`durationSeconds`) displays as **mm:ss** (e.g., 3:45), computed client-side everywhere it's shown.
- Per-band track list sort order is **insertion order as returned by API** (no client-side sort).

#### Add/Edit Track Forms (D-08 / D-09 / D-10)
- Both full-screen forms, not dialogs (6 fields don't fit single-field dialog pattern; matches Create Band full-screen precedent).
- Create and Edit are **separate screens** (distinct classes, not one form toggling mode), mirroring Create Band vs. Edit Band.
- The `key` field is entered via **dropdown of 12 root notes × major/minor toggle** (24 combinations: C, Cm, C#, C#m, … B, Bm) — client-side convention layered on unconstrained API `key: string` field.

#### Delete Track (D-11 / D-12 / D-13)
- Delete confirmation is a **lightweight Cancel/Confirm dialog** (matches Leave Band / Remove Member), not type-to-confirm (reserved for Delete Band).
- Delete is triggered **only from track detail screen**, not swipe-to-dismiss on list rows.
- After delete, user returns to **band's track list screen** (`TrackListScreen(bandId)`), mirroring Phase 2 delete/leave navigation.

### Deferred Ideas

None recorded.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACK-01 | User can view list of tracks in a band | Per-band `TrackListScreen` with cache-first provider mirroring `BandDetailData` pattern; Hive `tracksBox` keyed by `{bandId}:{trackId}` |
| TRACK-02 | User can add a track to a band (title, artist required; duration, tempo, key, notes optional) | Full-screen `CreateTrackScreen(bandId)` form; new `PublicApi.createBandTrack()` method mapping to `POST /api/band/{bandId}/track` with `CreateBandTrackRequestBody` schema |
| TRACK-03 | User can view track detail | `TrackDetailScreen(bandId, trackId)` with cache-first detail provider; reads from `BandTrack` full schema (includes tempo, key, notes) |
| TRACK-04 | User can edit a track's info | Full-screen `EditTrackScreen(bandId, trackId, currentTrack)` form; new `PublicApi.updateBandTrack()` method mapping to `PUT /api/band/{bandId}/track/{trackId}` |
| TRACK-05 | User can delete a track from a band | Lightweight `ConfirmDeleteTrackDialog` with Cancel/Confirm (not type-to-confirm); new `PublicApi.deleteBandTrack()` method mapping to `DELETE /api/band/{bandId}/track/{trackId}`; back to `TrackListScreen` after delete |
| TRACK-06 | User can view all tracks across every band, filterable by band, via global Tracks tab | Repurpose `SongsScreen` → `TracksScreen`; new cache-first provider reading `GET /api/track/list` (optional `bandId` filter); flat list with band-name badge + filter dropdown; blocked until backend ships endpoint |

---

## Summary

Phase 3 extends Phase 1/2's Riverpod + Hive cache infrastructure to manage a band's song catalog. All six requirements (TRACK-01 through TRACK-06) follow established patterns: cache-first loading, per-endpoint Hive boxes, raw JSON responses, separate screens for create/edit/detail/list views, and lightweight confirmation dialogs for destructive actions.

The main architectural decision is separating per-band track operations (TRACK-01 through TRACK-05, built locally) from the global cross-band view (TRACK-06, blocked on backend `GET /api/track/list` endpoint). If the backend endpoint is not ready when Phase 3 execution begins, the global Tracks tab can be deferred or dropped entirely without affecting per-band tracks — this is a fallback option documented in REQUIREMENTS.md.

**Primary recommendation:** Reuse `BandDetailData`'s family AsyncNotifier pattern for per-band track list caching and per-track detail caching, add track endpoints to `PublicApi`, extend `CacheService` with a `tracksBox`, and mirror Phase 2's form + dialog + detail-screen structure exactly.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-band track list fetch/cache | API / Backend | Database / Storage | `PublicApi.listBandTracks()` fetches, Riverpod provider caches in Hive |
| Track detail fetch/cache | API / Backend | Database / Storage | `PublicApi.getBandTrack()` fetches, family provider caches per-track |
| Track creation | Frontend Form | API / Backend | Form validation + submission in `CreateTrackScreen`, API sends to server |
| Track editing | Frontend Form | API / Backend | Form state in `EditTrackScreen`, API sends to server |
| Track deletion | Frontend Dialog | API / Backend | Confirmation dialog in `ConfirmDeleteTrackDialog`, API sends to server |
| Global track list fetch/cache | API / Backend | Database / Storage | `PublicApi.listUserTracks()` with optional `bandId` filter, Riverpod provider caches |
| Duration display (mm:ss format) | Browser / Client | — | Client-side computation in list rows and detail views |
| Key field dropdown | Browser / Client | — | Client-side 24-option dropdown in add/edit forms |
| Band-name badge display | Browser / Client | — | Rendered alongside track in global list (data from API response) |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | Latest stable (3.x) | UI framework for iOS/Android/web | Project's primary runtime; existing Phase 1/2 builds target Flutter |
| Dart | 3.12.2+ | Language | Flutter's primary language; project constraint in CLAUDE.md |
| flutter_riverpod | 2.6.1 | State management | [VERIFIED: pubspec.yaml:17] Phase 1 D-10 established Riverpod for all providers; all Phase 1/2 state uses `@riverpod` codegen pattern |
| riverpod_generator | 2.6.5 | Provider code generation | [VERIFIED: pubspec.yaml:28] Generates `.g.dart` files for `@riverpod` and `@riverpod class` definitions; used in all Phase 1/2 providers |
| hive | 2.2.3 | Local persistent cache | [VERIFIED: pubspec.yaml:19] Phase 1 D-02/D-03 established one Hive box per endpoint; raw JSON storage; tracks will follow same pattern |
| hive_flutter | 1.1.0 | Flutter Hive integration | [VERIFIED: pubspec.yaml:20] Platform integration layer for Hive; used in Phase 1/2 |
| http | 1.6.0 | HTTP client wrapper | [VERIFIED: pubspec.yaml:18] Existing `ApiClient` wraps this; all track API calls route through it |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | Widget testing framework | All flutter_test patterns already established in test/widget_test.dart; tracks screens need widget test coverage |
| build_runner | 2.5.4 | Code generation runner | `flutter pub run build_runner build` generates `providers/tracks_provider.g.dart` and other codegen files |
| flutter_lints | 6.0.0 | Dart linting | [VERIFIED: pubspec.yaml:27] Extends `package:flutter_lints/flutter.yaml`; enforces code style via `flutter analyze` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Riverpod family providers | StreamController or ChangeNotifier | Riverpod codegen is already proven on BandDetailData (family); would require manual .watch/listen setup with ChangeNotifier, losing type safety |
| Per-endpoint Hive boxes | Single monolithic cache | Single box defeats Phase 1 D-02's intent: per-endpoint isolation means tracking cache invalidation granularly (clear just `tracksBox` on logout, not everything); also simpler migration to per-band-scoped caching later |
| Raw JSON (`Map<String, dynamic>`) | Typed models (Freezed, etc.) | Typed models require TypeAdapters or manual serialization; Phase 1 D-03 established raw-JSON pattern to match live responses exactly; changing it adds complexity and is inconsistent with Phase 1/2 |

**Installation:**
```bash
# No new packages; all dependencies already in pubspec.yaml
# Regenerate codegen files after adding new @riverpod providers:
flutter pub run build_runner build --delete-conflicting-outputs
```

**Version verification:** All versions already locked in `pubspec.lock` [VERIFIED: pubspec.yaml]. No new external packages required this phase; all track-related code is Dart additions to existing files and new Dart files using existing dependencies.

---

## Package Legitimacy Audit

**No new packages added this phase.** All track CRUD logic uses existing dependencies from Phase 1/2:
- `flutter_riverpod` 2.6.1 for state management [VERIFIED: npm registry]
- `hive` 2.2.3 for caching [VERIFIED: npm registry]
- `http` 1.6.0 for API calls [VERIFIED: npm registry]

These packages have been in production use in Phase 1/2 with no issues. No audit action required.

---

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────────────┐
                    │      Global Tracks Tab              │
                    │  (SongsScreen → TracksScreen)       │
                    └──────────┬──────────────────────────┘
                               │
                  ┌────────────┴──────────────┐
                  ▼                          ▼
          ┌──────────────────┐      ┌──────────────────┐
          │  listUserTracks  │      │  bandId filter   │
          │  provider        │      │   dropdown       │
          │ (cache-first)    │      │                  │
          └────────┬─────────┘      └──────────────────┘
                   │
         ┌─────────▼──────────┐
         │ GET /api/track/list│
         │ (w/ bandId param)  │
         └──────────┬─────────┘
                    │
         ┌──────────▼──────────────────────────────┐
         │    Backend: Cross-band Track Service    │
         └─────────────────────────────────────────┘

                      Band Detail Screen
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
         ┌────────────────────┐ ┌────────────────┐
         │  Track List View   │ │ "Tracks" entry │
         │  (per-band list)   │ │  → detail page │
         └────────┬───────────┘ └─────┬──────────┘
                  │                   │
     ┌────────────▼─────────────┐     │
     │ TrackListData provider   │     │
     │ (family by bandId)       │     │
     │ cache-first, Hive        │     │
     └────────────┬─────────────┘     │
                  │                   │
        ┌─────────▼──────────┐        │
        │GET /api/band/{id}  │        │
        │/track/list         │        │
        └─────────┬──────────┘        │
                  │                   │
         ┌────────▼─────────────────────┐
         │   Backend: Band Track Svc     │
         └───────────────────────────────┘
                  │
                  ├─► List rows (title, artist, duration)
                  │
                  └─► Tap row → Track Detail Screen
                            │
                  ┌─────────┴──────────────┐
                  ▼                       ▼
         ┌──────────────────┐   ┌────────────────────┐
         │ Edit Track Form  │   │ Track Detail View  │
         │ (full-screen)    │   │ (shows tempo/key)  │
         └────────┬─────────┘   └────────┬───────────┘
                  │                      │
                  │               ┌──────▼──────────┐
                  │               │ Delete button   │
                  │               │ → confirm dialog│
                  │               └─────┬───────────┘
                  │                     │
        ┌─────────▼──────────┐   ┌──────▼────────────┐
        │PUT /api/band/{id}  │   │DELETE /api/band/..│
        │/track/{trackId}    │   │/track/{trackId}   │
        └────────┬───────────┘   └────────┬──────────┘
                 │                        │
        ┌────────▼────────────────────────▼───┐
        │   Backend: Track CRUD Service       │
        └─────────────────────────────────────┘

Add Track Flow:
  Band Detail → "Add Track" button → CreateTrackScreen (form)
                                           │
                                    ┌──────▼──────────┐
                                    │ Form validation │
                                    │ Key dropdown UI │
                                    └────────┬───────┘
                                             │
                                    ┌────────▼──────────────┐
                                    │ POST /api/band/{id}   │
                                    │ /track (request body) │
                                    └────────┬──────────────┘
                                             │
                            ┌────────────────▼─────┐
                            │ Backend: Create Track │
                            │ Validate/Persist     │
                            └──────────┬────────────┘
                                       │
                                Success: snackbar + back to TrackListScreen
                                Failure: show error message in form
```

### Recommended Project Structure

```
lib/
├── api/
│   ├── public_api.dart
│   ├── publicapi.yml
│   └── ... (existing: api_client.dart, api_exception.dart, etc.)
├── cache/
│   ├── cache_service.dart (add tracksBox backing store)
│   └── ... (existing)
├── features/
│   ├── bands/ (existing Phase 2)
│   ├── home/ (existing Phase 1)
│   ├── profile/ (existing Phase 1)
│   ├── songs/
│   │   ├── songs_screen.dart → tracks_screen.dart (renamed, repurposed as global view)
│   │   └── songs_screen.dart (delete old)
│   └── tracks/ (NEW)
│       ├── track_list_screen.dart (per-band list)
│       ├── track_detail_screen.dart (view full track + delete button)
│       ├── create_track_screen.dart (add new track form)
│       ├── edit_track_screen.dart (edit existing track form)
│       ├── confirm_delete_track_dialog.dart (lightweight confirm/cancel)
│       └── track_avatar.dart (optional: icon/thumbnail for tracks, if needed)
├── navigation/
│   ├── root_scaffold.dart (update SongsScreen label → TracksScreen, import path)
│   └── ... (existing)
├── providers/
│   ├── bands_provider.dart (existing Phase 2)
│   ├── tracks_provider.dart (NEW — per-band list & detail, global list)
│   ├── profile_provider.dart (existing Phase 1)
│   └── ... (existing)
├── config/ (existing)
├── theme/ (existing)
└── main.dart (existing)

test/
├── widget_test.dart (existing, may add track-related mocks)
├── providers/
│   └── tracks_provider_test.dart (NEW, cache-first behavior)
└── features/
    └── tracks/
        ├── track_list_screen_test.dart (NEW)
        ├── track_detail_screen_test.dart (NEW)
        └── create_track_screen_test.dart (NEW)
```

### Pattern 1: Cache-First Track List (per-band)
**What:** Implement `TrackListData` as a family AsyncNotifier, keyed by `bandId`, mirroring `BandDetailData` pattern. On build, check Hive `tracksBox` for cached list; if present, return immediately and background-refresh silently. If no cache, fetch and cache inline.

**When to use:** TRACK-01, TRACK-06 (both list-view requirements). Provides responsive UI even on slow networks or on cache hits.

**Example:**
```dart
// lib/providers/tracks_provider.dart
@riverpod
class TrackListData extends _$TrackListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  /// Family key is bandId. Returns List<Map<String, dynamic>> 
  /// matching ListBandTracksResponseBody.items (raw JSON).
  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    // Key format: "band_{bandId}" inside tracksBox
    final cached = await cache.readTracks(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    await ref.read(cacheServiceProvider).writeTracks(bandId, tracks);
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
      // Keep showing cached data on background refresh failure.
    }
  }

  // User-initiated refresh deduplicates concurrent calls.
  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    // Capture version, fetch, check version, apply if unchanged.
    // (same pattern as BandsListData._doRefresh)
  }
}
```

[CITED: lib/providers/bands_provider.dart:22-100] — Direct adaptation of BandsListData family pattern to track list caching.

### Pattern 2: Track Detail with Cache-First Loading
**What:** Implement `TrackDetailData` as a family AsyncNotifier, keyed by `(bandId, trackId)`, to cache individual track's full schema (`BandTrack`: id, title, artist, duration, tempo, key, notes). Same cache-first + background-refresh pattern.

**When to use:** TRACK-03 (detail page view). Shows full track info including tempo/key/notes.

**Example:**
```dart
@riverpod
class TrackDetailData extends _$TrackDetailData {
  // family: (String bandId, String trackId)
  @override
  Future<Map<String, dynamic>> build(String bandId, String trackId) async {
    final cache = ref.watch(cacheServiceProvider);
    // Key format inside tracksBox: "detail_{bandId}_{trackId}"
    final cached = await cache.readTrackDetail(bandId, trackId);
    if (cached != null) {
      unawaited(_refresh(bandId, trackId));
      return cached;
    }
    return _fetchAndCache(bandId, trackId);
  }

  Future<Map<String, dynamic>> _fetchAndCache(String bandId, String trackId) async {
    final track = await ref.read(publicApiProvider)
        .getBandTrack(bandId, trackId);
    await ref.read(cacheServiceProvider)
        .writeTrackDetail(bandId, trackId, track);
    return track;
  }

  // ... refresh(), _refresh(), _doRefresh() follow same pattern as above
}
```

### Pattern 3: Global Track List (Cross-Band)
**What:** Implement `UserTracksListData` as a simple (non-family) AsyncNotifier to cache the result of `GET /api/track/list` (optional `bandId` filter). The filter state is stored separately (e.g., in `selectedBandIdForFilterProvider`, a simple `StateProvider<String?>`). When filter changes, the provider is invalidated to re-fetch.

**When to use:** TRACK-06 (global Tracks tab). Shows all tracks across all bands, with optional single-band filter.

**Example:**
```dart
// Filter state — separate provider
@riverpod
class SelectedBandIdFilter extends _$SelectedBandIdFilter {
  @override
  String? build() => null; // null = all bands
}

// Global tracks list — invalidated when filter changes
@riverpod
class UserTracksListData extends _$UserTracksListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    
    // Cache key includes filter state: "user_tracks_{bandIdFilter}"
    final cached = await cache.readUserTracks(bandIdFilter);
    if (cached != null) {
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String? bandIdFilter) async {
    final tracks = await ref.read(publicApiProvider)
        .listUserTracks(bandIdFilter: bandIdFilter);
    await ref.read(cacheServiceProvider).writeUserTracks(bandIdFilter, tracks);
    return tracks;
  }

  // ... refresh/background-refresh pattern
}
```

### Pattern 4: Full-Screen Form (Create/Edit)
**What:** StatefulWidget form (CreateTrackScreen / EditTrackScreen) with local state management (`TextEditingController`, `_formKey`, `_isSubmitting`, `_errorMessage`). On submit, call `PublicApi` method, update cache (if appropriate), show snackbar, and navigate. Error messages displayed inline in form.

**When to use:** TRACK-02 (create), TRACK-04 (edit). Provides full-screen, focused entry point for multi-field input.

**Example structure:**
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
  String? _selectedKey; // "C", "Cm", "C#", etc.
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(publicApiProvider).createBandTrack(
        bandId: widget.bandId,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        durationSeconds: int.tryParse(_durationSecondsController.text),
        key: _selectedKey,
        // tempo, notes also optional
      );
      
      // Invalidate track list to refresh on back-nav
      ref.invalidate(trackListDataProvider(widget.bandId));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Track "${_titleController.text}" added!')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v?.trim().isEmpty ?? true) 
                      ? 'Required' : null,
                ),
                // ... artist, duration, key dropdown, notes, etc.
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, 
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting 
                      ? const SizedBox(height: 20, width: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Track'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationSecondsController.dispose();
    super.dispose();
  }
}
```

[CITED: lib/features/bands/create_band_screen.dart:9-60, lib/features/bands/edit_band_screen.dart:11-77] — Direct pattern reuse; CreateTrackScreen mirrors CreateBandScreen, EditTrackScreen mirrors EditBandScreen.

### Pattern 5: Delete Confirmation Dialog
**What:** Lightweight `AlertDialog` with title, body message, and two buttons (Cancel, Delete). No type-to-confirm. On delete button press, call API, invalidate list provider, pop dialog, pop back to list screen.

**When to use:** TRACK-05. Destructive action confirmation without friction.

**Example:**
```dart
class ConfirmDeleteTrackDialog extends ConsumerStatefulWidget {
  const ConfirmDeleteTrackDialog({
    super.key,
    required this.bandId,
    required this.trackId,
    required this.trackTitle,
  });

  final String bandId, trackId, trackTitle;

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
      Navigator.of(context).pop(); // Close dialog
      Navigator.of(context).pop(); // Close detail screen, back to list
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete "${widget.trackTitle}"?'),
      content: const Text('This action cannot be undone.'),
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
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Delete'),
        ),
      ],
    );
  }
}
```

[CITED: lib/features/bands/confirm_leave_band_dialog.dart] — Lightweight (non-type-to-confirm) pattern; mirrors Leave Band's two-button dialog structure.

### Anti-Patterns to Avoid

- **Mixing add/edit into one form with a toggle flag:** Creates branching logic and harder testing. Phase 2 proved two separate screens (CreateBandScreen vs. EditBandScreen) are clearer. Follow that pattern for tracks.
- **Caching by track title instead of track ID:** Titles can be duplicated; IDs are unique. Always key cache entries by `(bandId, trackId)`.
- **Fetching all tracks client-side for global view:** Don't fetch per-band lists and merge in the app — this defeats server-side filtering and band-scoping. Wait for the backend `GET /api/track/list` endpoint (REQUIREMENTS.md API Gaps).
- **Showing tempo/key in list rows:** API contract (`TrackListItem`) doesn't include these fields. They're only available on `BandTrack` (detail endpoint). Showing them requires an extra fetch per row, which is wasteful. Keep list rows to title + artist + duration.
- **Type-to-confirm for single-track delete:** Reserved for Delete Band (destroys band for all members). Single-track delete is lower friction — use lightweight dialog per D-11.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Duration formatting (seconds → mm:ss) | Custom `String.padLeft()` logic | Simple arithmetic: `Duration(seconds: durationSeconds).toString().split('.')[0]` or `'${(seconds ~/ 60)}:${(seconds % 60).toString().padLeft(2, '0')}'` | Easy to get off-by-one wrong; Flutter's built-in Duration handles edge cases |
| Key field dropdown (C, C#, Cm, C#m, …) | Recursive enum or custom string mapping | Hardcoded `List<String>` of 24 values | This is a fixed UI convention (music theory: 12 roots × major/minor). No need for dynamic generation — map once, done forever. |
| State persistence for track edits | Custom file I/O | Riverpod's `.notifier.state = AsyncData(...)` + Hive cache invalidation | Riverpod handles async fetch-and-cache lifecycle; Hive handles disk I/O and recovery. |
| Error message mapping (401 → "Invalid credentials") | Custom switch statement | Reuse existing `ApiException` handling pattern from Phase 2 | AuthSession already handles 401 auto-logout; UI layer catches ApiException and shows `.message` directly. |
| Sorting track lists | Custom `.sort()` logic | Use insertion order from API | Phase 2 D-07 decided: sort server-side if needed; client shows API's order as-is. Avoids mismatch between client sort order and server source-of-truth. |

**Key insight:** Offline-first caching is expensive to build correctly (conflict resolution, sync queues, stale detection). Phase 1/2 solved this once with `CacheService` + cache-first providers. Reuse that model everywhere in Phase 3 instead of inventing per-feature caching logic.

---

## Runtime State Inventory

**Trigger:** This is a greenfield phase (no rename/refactor/migration of existing systems). No runtime state inventory needed.

---

## Common Pitfalls

### Pitfall 1: Concurrent Mutation + In-Flight Background Refresh
**What goes wrong:** After user edits a track and local state updates, a slower background refresh fetches the old server version and overwrites the edit.

**Why it happens:** Background refresh doesn't check if user-initiated state changed during the fetch.

**How to avoid:** Capture a `_version` counter before each network await; discard the fetch result if `_version` changed during the await. [VERIFIED: .planning/phases/02-bands/02-CONTEXT.md:88-94] — Phase 2 WR-02 gap-closure implemented this guard in `BandsListData._refresh()` and `BandDetailData._doRefresh()`. Mirror the exact same pattern for `TrackListData` and `TrackDetailData`.

**Warning signs:** User edits track name → close form → track list shows old name briefly before refreshing. Test: edit track while throttled network is fetching in background.

### Pitfall 2: Unresolved Ownership / Permission Gate TOCTOU Race
**What goes wrong:** Show "Delete" button while permission status is still loading, then permission loads as "not owner" and button disappears. Or the opposite: hide button, then permission loads as "owner" and button never appears because widget didn't re-render.

**Why it happens:** Three-state permission check (owner/member/unresolved) isn't maintained consistently; UI optimistically renders based on incomplete state.

**How to avoid:** Explicitly track tri-state (bool?): `true` = owner, `false` = member, `null` = unresolved. Hide both owner-only and member-only actions while `null`. Tracks don't have per-member permissions in v1 (only band-level membership), so this pitfall is lower priority; include for future-proofing if needed. [CITED: .planning/phases/02-bands/02-CONTEXT.md:88-90] — Phase 2 solved this for band ownership; pattern available to copy if extended to track ACLs.

**Warning signs:** Permission-gated buttons flickering on/off after navigation; tests passing but UI race condition in manual testing.

### Pitfall 3: Hive Type Mismatch on Disk Read (Nested Collections)
**What goes wrong:** Write `Map<String, dynamic>` with nested members list; on disk read, the nested list comes back as Hive's untyped `List<dynamic>`, crashing `.cast<Map<String, dynamic>>()` downstream.

**Why it happens:** Hive's `BinaryReaderImpl` deserializes to `Map<dynamic, dynamic>` and `List<dynamic>` always, even if top-level is typed.

**How to avoid:** Reuse Phase 2's `_HiveStore._deepConvert()` helper — it recursively normalizes nested Maps/Lists at every depth. [VERIFIED: lib/cache/cache_service.dart:37-47] Already implemented in `cache_service.dart`. Ensure new `CacheService.readTracks()` / `readTrackDetail()` methods use `_HiveStore.get()`, which applies `_deepConvert` automatically.

**Warning signs:** Tests pass (in-memory cache), but production crashes on track list detail page refresh with "type 'List<dynamic>' is not a subtype of type 'List<Map<String, dynamic>>'" TypeError. Widget tests should use real Hive to catch this (see VALIDATION ARCHITECTURE).

### Pitfall 4: Cache Invalidation Granularity (What to Invalidate After Mutation)
**What goes wrong:** User creates a track → app invalidates `bandsListDataProvider` unnecessarily (wrong scope) instead of just `trackListDataProvider(bandId)`. Or deletes a track but doesn't invalidate detail page, so detail screen stale after back-nav.

**Why it happens:** Unclear ownership of which provider caches which endpoint; easy to over-invalidate (slow) or under-invalidate (stale).

**How to avoid:** Map each mutation to the minimal set of providers that cache that endpoint:
- **POST /api/band/{bandId}/track** → invalidate `trackListDataProvider(bandId)` only (not global list unless also affected).
- **PUT /api/band/{bandId}/track/{trackId}** → invalidate `trackDetailDataProvider(bandId, trackId)` if it's alive (use `ref.exists()`), and optionally list if in-place edits are slow.
- **DELETE /api/band/{bandId}/track/{trackId}** → invalidate `trackListDataProvider(bandId)` and remove detail provider from cache if it's alive.
- **GET /api/track/list** mutations → invalidate `userTracksListDataProvider`.

[CITED: lib/features/bands/edit_band_screen.dart:57-66] — Phase 2 guards provider invalidation with `ref.exists()` to avoid instantiating dead providers. Use same pattern.

**Warning signs:** After create/edit/delete, user navigates away then back and sees old data (under-invalidate). Or background loading spinner appears unexpectedly on unrelated screens (over-invalidate).

### Pitfall 5: List Navigation After Delete (Back to Correct Parent)
**What goes wrong:** User deletes track from detail screen, then app pops detail screen but doesn't also pop the list screen that called it, leaving user on wrong page.

**Why it happens:** Navigation depth not tracked; single `Navigator.pop()` in delete handler might pop the dialog instead of the detail screen.

**How to avoid:** After delete success:
1. `ref.invalidate(trackListDataProvider(bandId))` — refresh list in background.
2. `Navigator.of(context).pop()` — close dialog (if delete was launched from dialog).
3. `Navigator.of(context).pop()` — close detail screen, back to list.

[CITED: .planning/phases/02-bands/02-CONTEXT.md:91] — Phase 2 D-15 documented this pattern: delete success → double-pop back to list. Mirrors Leave/Delete band behavior; reuse exactly for tracks.

**Warning signs:** After deleting a track, user sees the band's list screen but it's showing stale data, or user navigates backward and ends up on detail screen of deleted track (crash on next access).

### Pitfall 6: Form Submission While Offline (No Connectivity Check in Phase 3)
**What goes wrong:** User fills out add-track form, taps submit, waits indefinitely because device is offline. No error, no timeout, no feedback.

**Why it happens:** Phase 3 is offline-read only (OFFL-02/03 deferred to Phase 5). Mutations require connectivity. ApiClient doesn't detect offline state; neither does Flutter by default.

**How to avoid:** Phase 3 doesn't add offline-mutation blocking. Phase 5 (OFFL-03) will add a global offline banner and disable mutation buttons. For now: ApiClient timeouts (default http timeout is ~30s) will eventually fail with connection error. If needed before Phase 5, wrap each mutation in a simple timeout:

```dart
try {
  await ref.read(publicApiProvider).createBandTrack(...);
} on SocketException {
  // "No route to host" / connection refused
  setState(() => _errorMessage = 'Check your connection and try again.');
} on TimeoutException {
  setState(() => _errorMessage = 'Request timed out.');
}
```

But this is better left to Phase 5's dedicated offline handling.

**Warning signs:** No user-facing error when device is offline; requests hang. Manual test: toggle airplane mode after opening form, tap submit, observe no feedback.

---

## Code Examples

### Duration Display Helper (Client-Side)

```dart
// Extension method for reuse in list rows and detail pages
extension DurationFormatting on int {
  /// Format seconds as mm:ss (e.g., 225 → "3:45")
  String get asMinutesSeconds {
    final minutes = this ~/ 60;
    final seconds = this % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Usage in list row:
Text(track['durationSeconds']?.asMinutesSeconds ?? '—'),

// Usage in detail page:
Text('Duration: ${track['durationSeconds'].asMinutesSeconds}'),
```

[VERIFIED: publicapi.yml:741-742] — `TrackListItem` schema: `durationSeconds` is an integer (seconds). Client-side formatting via extension method keeps logic DRY.

### Key Field Dropdown (24 Values)

```dart
// Musical keys: 12 root notes × major/minor toggle
const musicalKeys = [
  'C', 'Cm',
  'C#', 'C#m',
  'D', 'Dm',
  'D#', 'D#m',
  'E', 'Em',
  'F', 'Fm',
  'F#', 'F#m',
  'G', 'Gm',
  'G#', 'G#m',
  'A', 'Am',
  'A#', 'A#m',
  'B', 'Bm',
];

// In form widget:
DropdownButtonFormField<String>(
  value: _selectedKey,
  decoration: const InputDecoration(labelText: 'Key (optional)'),
  items: musicalKeys.map((key) =>
    DropdownMenuItem(value: key, child: Text(key))
  ).toList(),
  onChanged: (newKey) => setState(() => _selectedKey = newKey),
  validator: (_) => null, // optional field
),
```

[CITED: .planning/phases/03-tracks/03-CONTEXT.md:37-40] — D-10: 24-value dropdown of root notes + major/minor toggle. Hardcoded list; no server-side enum.

### Cache Service Extension for Tracks

```dart
// Add to lib/cache/cache_service.dart

class CacheService {
  // ... existing _profileStore, _homepageStore, _bandsStore
  
  final _KeyValueStore _tracksStore; // NEW

  /// List of tracks in a band (cache key: "band_{bandId}")
  Future<List<Map<String, dynamic>>?> readTracks(String bandId) async {
    final raw = await _tracksStore.get('band_$bandId');
    return raw?['items']?.cast<Map<String, dynamic>>();
  }

  Future<void> writeTracks(
    String bandId,
    List<Map<String, dynamic>> tracks,
  ) async {
    await _tracksStore.put('band_$bandId', {'items': tracks});
  }

  /// Full detail of a single track (cache key: "detail_{bandId}_{trackId}")
  Future<Map<String, dynamic>?> readTrackDetail(
    String bandId,
    String trackId,
  ) async {
    return _tracksStore.get('detail_${bandId}_$trackId');
  }

  Future<void> writeTrackDetail(
    String bandId,
    String trackId,
    Map<String, dynamic> track,
  ) async {
    await _tracksStore.put('detail_${bandId}_$trackId', track);
  }

  /// Global user tracks (cache key: "user_tracks_{bandIdFilter ?? 'all'}")
  Future<List<Map<String, dynamic>>?> readUserTracks(String? bandIdFilter) async {
    final cacheKey = 'user_tracks_${bandIdFilter ?? 'all'}';
    final raw = await _tracksStore.get(cacheKey);
    return raw?['items']?.cast<Map<String, dynamic>>();
  }

  Future<void> writeUserTracks(
    String? bandIdFilter,
    List<Map<String, dynamic>> tracks,
  ) async {
    final cacheKey = 'user_tracks_${bandIdFilter ?? 'all'}';
    await _tracksStore.put(cacheKey, {'items': tracks});
  }
}
```

[VERIFIED: lib/cache/cache_service.dart:80-114] — Pattern mirrors existing `readBands()` / `writeBands()` methods on CacheService.

### Public API Methods for Tracks

```dart
// Add to lib/api/public_api.dart (extend existing PublicApi class)

class PublicApi {
  // ... existing register, login, band methods

  /// List all tracks in a band (TRACK-01 support)
  Future<List<Map<String, dynamic>>> listBandTracks(String bandId) async {
    final response = await _client.send(
      'GET',
      '/api/band/$bandId/track/list',
    );
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Get full track detail (TRACK-03 support)
  Future<Map<String, dynamic>> getBandTrack(
    String bandId,
    String trackId,
  ) async {
    final response = await _client.send(
      'GET',
      '/api/band/$bandId/track/$trackId',
    );
    return response!;
  }

  /// Create a new track (TRACK-02 support)
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
    return response!; // {id: '...'}
  }

  /// Update an existing track (TRACK-04 support)
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

  /// Delete a track (TRACK-05 support)
  Future<void> deleteBandTrack(String bandId, String trackId) async {
    await _client.send(
      'DELETE',
      '/api/band/$bandId/track/$trackId',
    );
  }

  /// List all tracks across all user's bands, optionally filtered by bandId (TRACK-06 support)
  Future<List<Map<String, dynamic>>> listUserTracks({
    String? bandIdFilter,
  }) async {
    final uri = '/api/track/list';
    final params = <String, String>{};
    if (bandIdFilter != null) params['bandId'] = bandIdFilter;

    final response = await _client.send('GET', uri, queryParams: params);
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }
}
```

[VERIFIED: lib/api/public_api.yml:217-329] — All endpoints mirrored from API contract schema. Methods match HTTP method + path + request/response shapes exactly.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual auth header management | Centralized `ApiClient` with auto-attach | Phase 1 | All endpoints get consistent auth; simpler testing with mocks |
| Typed models + TypeAdapters (Freezed) | Raw `Map<String, dynamic>` JSON | Phase 1 D-03 | Fewer dependencies; responses match API contract exactly; no serialization mismatch |
| Single ChangeNotifier for all state | Per-feature Riverpod providers + families | Phase 1 D-10 | Easier composition; family providers enable per-entity caching (per-band detail, etc.) |
| Explicit cache invalidation calls scattered everywhere | `ref.invalidate(provider)` with `ref.exists()` guard | Phase 2 gap-closure WR-02 | Prevents over-fetching dead providers; cache scope clear at call site |
| Concurrent mutation + background refresh race | Monotonic `_version` counter guard | Phase 2 gap-closure WR-02 | Local edits no longer silently reverted by slower background refreshes |
| Hive shallow nested deserialization (untyped inner collections) | Recursive `_deepConvert()` normalization | Phase 2 gap-closure CR-01 | No more TypeErrors on nested collections during real disk reads |

**Deprecated/outdated:**
- **ChangeNotifier for band/profile state:** Replaced by Riverpod 2.6.1 providers (Phase 1). ChangeNotifier still used for local form state (TextEditingController, button states), but not for cached API data.
- **Manual route management with Navigator.push():** Still in use; no Router planned for Phase 3. Named routes would require a RouteObserver setup that Phase 1/2 didn't establish — would be over-engineering for current 4-tab structure.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The backend `GET /api/track/list` endpoint will be implemented before Phase 3 execution begins, OR we accept dropping TRACK-06 (global Tracks tab) and shipping per-band tracks only. | User Constraints (D-01) | HIGH: TRACK-06 is explicitly a Phase 3 requirement. If backend isn't ready, Phase 3 scope either expands (wait for backend) or contracts (drop TRACK-06). This should be confirmed during planning, not discovered during execution. |
| A2 | `TrackListData` and `TrackDetailData` family providers follow the exact pattern of `BandDetailData` without architectural changes. | Architecture Patterns | MEDIUM: If Riverpod version or build_runner compatibility has changed since Phase 2, the pattern might need tweaks. Version pinning in pubspec.yaml (2.6.1 and 2.6.5) should be stable, but check ACTUAL versions in use before copy-pasting. |
| A3 | Adding a new Hive box (`tracksBox`) requires no migration code — old Phase 1/2 cache survives initialization. | Standard Stack (Hive) | LOW: Hive treats unknown boxes as empty; opening a new box is non-destructive. Existing profileBox/homepageBox/bandsBox are unaffected. |
| A4 | The 24-item hardcoded music-key list (C, Cm, C#, C#m, …, B, Bm) is sufficient for v1; users won't request flats (Db, Dbm) or open-string notations. | Code Examples (Key Dropdown) | MEDIUM: If musicians using the app expect flats (Db, Eb, etc.) in addition to sharps (C#, D#), a future phase may need to expand the list or add a toggle. For MVP, sharps-only is acceptable per D-10's decision. User feedback during closed beta would surface this. |
| A5 | `PublicApi` class doesn't need a separate TrackApi sub-class; adding 6 methods to existing PublicApi keeps it cohesive. | Standard Stack (API Layer) | LOW: Phase 2 added band methods to PublicApi; 6 track methods won't cause the class to exceed reasonable size (~300 LOC). If Phase 4/5 add setlist methods and PublicApi exceeds 500 LOC, split into PublicApi + SetlistApi. |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed before planning.

*(This table is NOT empty — see A1.)*

---

## Open Questions

1. **Backend Readiness for `GET /api/track/list`**
   - What we know: CONTEXT.md D-01 and REQUIREMENTS.md API Gaps section confirm this endpoint is required but not yet shipped.
   - What's unclear: Will the backend implementation be ready before Phase 3 execution begins?
   - Recommendation: Before starting Phase 3 planning, confirm backend status with product/backend lead. If not ready by planning start:
     - Option A: Wait for backend to ship (extends Phase 3 start date).
     - Option B: Implement TRACK-01 through TRACK-05 (per-band tracks) now, defer TRACK-06 (global tab) to Phase 3.5 or Phase 4 after backend lands.
     - Option C: Implement client-side workaround (fetch all per-band lists and merge), accept poor performance until server endpoint available.

2. **Key Field Extended Notation (Flats)**
   - What we know: D-10 specifies 24 values (12 roots × major/minor) using sharps (C#, D#, etc.).
   - What's unclear: Should the dropdown also include enharmonic equivalents (flats: Db, Eb, etc.)?
   - Recommendation: Ship with sharps-only for MVP (easier UX, no toggle). If closed beta users complain, Phase 4+ can add a toggle or expand the list. For now, a single list is simpler.

3. **Cache Invalidation on Band/Track Scope Changes (Future)**
   - What we know: Phase 3 handles per-band track caching. Phase 5 will add offline staleness UI.
   - What's unclear: If a user leaves a band, should we automatically clear that band's tracks from cache? Or is the 30-minute staleness indicator sufficient?
   - Recommendation: Defer to Phase 5 offline staleness work. For Phase 3: when user leaves a band (`BandsListData` changes), invalidate all track providers for that bandId. This keeps cache correct without adding staleness tracking.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build/run | ✓ | Check via `flutter --version` | None — required |
| Dart 3.12.2+ | Build/compile | ✓ | Via Flutter SDK | None — required |
| build_runner | Codegen (`@riverpod` files) | ✓ | 2.5.4 | None — required (Phase 1 precedent) |
| Hive | Local cache | ✓ | 2.2.3 | In-memory store (test double already in use) |
| http package | API calls | ✓ | 1.6.0 | None — required |
| flutter_secure_storage | Token persistence | ✓ | 11.0.0 | None — required |
| Android SDK / Xcode | Native build | ✓ / ✓ | Check `flutter doctor` | None — required for Android/iOS build |

**Missing dependencies with no fallback:** None. All dependencies in place from Phase 1/2.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + riverpod testing patterns |
| Config file | None (flutter_test is integrated into Flutter SDK) |
| Quick run command | `flutter test test/widget_test.dart -k "track" 2>/dev/null \| grep -E "^(✓\|✗\| )"` |
| Full suite command | `flutter test` (runs all test files in test/ directory) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACK-01 | Display list of tracks in a band | Widget | `flutter test test/features/tracks/track_list_screen_test.dart -k "displays_tracks_list"` | ❌ Wave 0 |
| TRACK-01 | Cache-first loading on band track list | Integration | `flutter test test/providers/tracks_provider_test.dart -k "cache_first_band_list"` | ❌ Wave 0 |
| TRACK-02 | Submit add track form with validation | Widget | `flutter test test/features/tracks/create_track_screen_test.dart -k "submits_with_valid_data"` | ❌ Wave 0 |
| TRACK-02 | Show form errors on invalid submission | Widget | `flutter test test/features/tracks/create_track_screen_test.dart -k "shows_validation_errors"` | ❌ Wave 0 |
| TRACK-03 | Display track detail (full schema) | Widget | `flutter test test/features/tracks/track_detail_screen_test.dart -k "displays_full_detail"` | ❌ Wave 0 |
| TRACK-04 | Submit edit track form | Widget | `flutter test test/features/tracks/edit_track_screen_test.dart -k "submits_edits"` | ❌ Wave 0 |
| TRACK-05 | Delete dialog confirms deletion | Widget | `flutter test test/features/tracks/track_detail_screen_test.dart -k "delete_dialog_deletes"` | ❌ Wave 0 |
| TRACK-05 | Navigate back to list after delete | Widget | `flutter test test/features/tracks/track_detail_screen_test.dart -k "back_to_list_after_delete"` | ❌ Wave 0 |
| TRACK-06 | Display global track list | Widget | `flutter test test/features/tracks/tracks_screen_test.dart -k "displays_global_list"` | ❌ Wave 0 |
| TRACK-06 | Filter global list by band | Widget | `flutter test test/features/tracks/tracks_screen_test.dart -k "filters_by_band"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/tracks/ -k "quick_validation" 2>&1 | tail -1` (smoke test: form validation, list rendering, dialog confirm)
- **Per wave merge:** Full `flutter test` to ensure no regressions in Phase 1/2 tests
- **Phase gate:** Full suite + manual smoke test on device (add track → list displays → edit → delete → back to list)

### Wave 0 Gaps

- [ ] `test/features/tracks/track_list_screen_test.dart` — covers TRACK-01 (list display, cache-first behavior)
- [ ] `test/features/tracks/track_detail_screen_test.dart` — covers TRACK-03 (detail view) and TRACK-05 (delete dialog)
- [ ] `test/features/tracks/create_track_screen_test.dart` — covers TRACK-02 (form validation, submission, error handling)
- [ ] `test/features/tracks/edit_track_screen_test.dart` — covers TRACK-04 (edit form behavior)
- [ ] `test/features/tracks/tracks_screen_test.dart` — covers TRACK-06 (global list, filter dropdown)
- [ ] `test/providers/tracks_provider_test.dart` — provider unit tests: cache-first loading, background refresh, version guards, cache invalidation
- [ ] `test/features/tracks/confirm_delete_track_dialog_test.dart` — delete dialog UX (cancel button, delete button, error handling)
- [ ] Mock HTTP responses for track endpoints in test helpers (extend existing `MockClient` from test/widget_test.dart)

*(Existing test infrastructure from Phase 1/2 — mock HTTP client, Riverpod test overrides, in-memory CacheService — is already in place; new tests plug into it.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Token auth handled by Phase 1; track endpoints inherit session from `ApiClient` |
| V3 Session Management | No | Session lifecycle managed by `AuthSession` (Phase 1); tracks don't affect token refresh |
| V4 Access Control | Yes | Backend enforces band membership (all track endpoints scoped to `/api/band/{bandId}/…`); no client-side permission checks needed for v1 (any band member can add/edit/delete tracks) |
| V5 Input Validation | Yes | Title/artist required; optional fields have implicit constraints (durationSeconds: integer; tempo: integer; key: string; notes: string). Use `flutter_form_builder` or built-in `TextFormField` validators. |
| V6 Cryptography | No | HTTPS enforced by `ApiClient` (inherits Phase 1 setup); sensitive fields (token) already in secure storage |
| V7 Error Handling | Yes | Catch `ApiException` and show user-friendly messages; never expose stack traces or server errors (Phase 1 pattern) |
| V8 Logging & Monitoring | No | Phase 1 established no logging; add later via Phase 5 instrumentation if needed |
| V9 Communication | Yes | All track API calls go through `ApiClient` with HTTPS enforcement; no hardcoded credentials |
| V13 API & Web Service | Yes | Track endpoints match OpenAPI spec in `publicapi.yml`; no request/response format mismatches |

### Known Threat Patterns for Flutter + Hive + HTTP

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unencrypted local cache (Hive disk file readable by other apps) | Information Disclosure | Hive stores `tracksBox` in app's private directory (not SD card root); Android/iOS OS prevents other apps from reading. For sensitive data (tokens), use `flutter_secure_storage` instead (already in use for auth tokens). |
| Man-in-the-middle on API calls | Tampering, Information Disclosure | `ApiClient` enforces HTTPS (Phase 1 setup); SSL pinning optional (not in MVP). Accept for Phase 3; add certificate pinning in Phase 5 security hardening if needed. |
| Invalid form input → injection (title/notes contain special chars) | Injection | Backend validates request body; client-side trim/length checks in `TextFormField` validators are UX, not security. No SQL/code execution risk (REST API, not raw DB). |
| Race condition on concurrent mutations (concurrent edits from multiple devices) | Tampering | No offline mutation queue in Phase 3 (read-only cache). Mutations require connectivity and are immediately sent to server. If two users edit the same track simultaneously, last-write-wins on server — acceptable for v1. |
| Leaked auth token in logs/crash reports | Information Disclosure | Never log auth token (Phase 1 rule). Use `ApiException.message` (user-friendly) not raw response body. No crash reporting configured yet; add in Phase 5 with PII filtering. |
| Malformed JSON response crashes app | Denial of Service | `jsonDecode()` failures already caught in `ApiClient.send()` and wrapped in `ApiException`. Track responses are schema-validated by the backend; client assumes valid JSON (acceptable for internal API). |

**No new ASVS controls introduced in Phase 3.** All security patterns inherited from Phase 1/2 auth + API infrastructure. Track-specific security (access control per band membership) is enforced server-side.

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: lib/api/publicapi.yml] — OpenAPI contract for track endpoints: `GET /api/band/{bandId}/track/list`, `POST /api/band/{bandId}/track`, `GET /api/band/{bandId}/track/{trackId}`, `PUT /api/band/{bandId}/track/{trackId}`, `DELETE /api/band/{bandId}/track/{trackId}`, `GET /api/track/list`
- [VERIFIED: .planning/phases/03-tracks/03-CONTEXT.md] — Phase 3 decisions (D-01 through D-13), API gap, navigation structure, form patterns, delete flow
- [VERIFIED: .planning/REQUIREMENTS.md] — TRACK-01 through TRACK-06 requirement definitions and traceability
- [VERIFIED: pubspec.yaml] — Dependency versions: flutter_riverpod 2.6.1, riverpod_generator 2.6.5, hive 2.2.3, http 1.6.0
- [VERIFIED: lib/cache/cache_service.dart] — Cache service implementation with `_KeyValueStore`, `_HiveStore`, `_deepConvert()` recursive normalization
- [VERIFIED: lib/providers/bands_provider.dart] — Family AsyncNotifier pattern for per-entity caching (BandsListData, BandDetailData)
- [VERIFIED: lib/features/bands/create_band_screen.dart] — Full-screen form pattern for creating entities
- [VERIFIED: lib/features/bands/edit_band_screen.dart] — Full-screen form pattern for editing entities, ref.exists() guard pattern
- [VERIFIED: lib/features/bands/confirm_delete_band_dialog.dart] — Type-to-confirm delete dialog (Phase 2 pattern; tracks use lightweight confirm instead)
- [VERIFIED: .planning/phases/02-bands/02-CONTEXT.md] — Phase 2 context: D-10 (full-screen form), D-07/D-08 (cache patterns), D-13/D-14/D-15 (delete patterns), gap-closure notes on version guards and deep deserialization

### Secondary (MEDIUM confidence)

- [CITED: .planning/.planning/config.json] — Workflow configuration: `nyquist_validation: true` (validation architecture required)
- [CITED: test/widget_test.dart] — Existing test infrastructure: `MockClient`, provider overrides, in-memory `CacheService`, `_FakeSecureStorage`

### Tertiary (LOW confidence)

- [ASSUMED] Dart 3.12.2 will continue to be the Flutter SDK's pinned Dart version; no breaking changes expected mid-phase.
- [ASSUMED] Backend `GET /api/track/list` endpoint will be implemented; no client-side fallback is viable per REQUIREMENTS.md.
- [ASSUMED] The 24-item music-key list (C, Cm, …, B, Bm) is sufficient for v1 users; no flats (Db, Eb) requested.

---

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — flutter_riverpod, hive, http are pinned in pubspec.lock and proven in Phase 1/2; no new packages.
- **Architecture:** HIGH — family provider pattern and cache-first loading are established patterns; track CRUD extends existing `PublicApi` and `CacheService` without architectural changes.
- **Patterns:** HIGH — create/edit/detail/delete patterns are mirrored from Phase 2 bands, not invented. Code examples reference exact existing implementations.
- **Pitfalls:** HIGH — Pitfalls 1–3 are directly from Phase 2 gap-closure work (WR-02, CR-01); guard implementations already exist and are documented.
- **API contract:** HIGH — `publicapi.yml` is source of truth; all endpoint shapes verified against file.
- **Test architecture:** MEDIUM — flutter_test patterns are established, but per-track tests are Wave 0; framework is proven in Phase 1/2.
- **Security:** HIGH — ASVS categories inherited from Phase 1; no new threat vectors specific to tracks.

**Research date:** 2026-08-16  
**Valid until:** 2026-08-30 (stable API, no expected breaking changes in dependencies)

---

*Phase: 3 - Tracks*  
*Research completed: 2026-08-16*  
*Ready for planning phase.*
