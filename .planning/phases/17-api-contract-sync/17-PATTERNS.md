# Phase 17: API Contract Sync - Pattern Map

**Mapped:** 2026-08-27
**Files analyzed:** 5 files (modified)
**Analogs found:** 5 / 5 matches

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `lib/api/public_api.dart` | service/API facade | request-response | itself (listBandTracks pattern at lines 173-185) | exact |
| `lib/features/tracks/track_list_screen.dart` | screen/component | request-response + UI render | `add_setlist_tracks_dialog.dart` | pattern-match |
| `lib/features/setlists/setlist_list_screen.dart` | screen/component | request-response + UI render | `add_setlist_tracks_dialog.dart` | pattern-match |
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | dialog/component | request-response + result render | itself (needs D-03 fix) | exact |
| `lib/features/auth/login_screen.dart` | screen/component + form validation | request-response + validation | itself (validator at lines 136-138) | exact |

## Pattern Assignments

### `lib/api/public_api.dart` (service, request-response)

**Analog:** `lib/api/public_api.dart` — `listBandTracks` method (lines 173-185)

**Migrate listUserTracks and listUserSetlists from POST+body to GET+queryParameters**

**Current pattern (POST with body — LINES 281-292):**
```dart
/// Returns tracks across every band the current user belongs to
/// (`UserTrackListItem` — id/title/artist/durationSeconds/bandId/bandName),
/// optionally narrowed to a single band via [bandIdFilter].
Future<List<Map<String, dynamic>>> listUserTracks({
  String? bandIdFilter,
  String? searchQuery,
}) async {
  final response = await _client.send(
    'POST',
    '/api/track/list',
    queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
    body: {'searchQuery': ?searchQuery},  // ← searchQuery in body
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Target pattern (GET with queryParameters — COPY FROM LINES 173-185):**
```dart
/// Returns a band's tracks (`TrackListItem` — id/title/artist +
/// optional durationSeconds). [searchQuery] is sent as a `searchQuery` 
/// query parameter when non-empty.
Future<List<Map<String, dynamic>>> listBandTracks(
  String bandId, {
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/track/list',
    queryParameters: (searchQuery == null || searchQuery.isEmpty)
        ? null
        : {'searchQuery': searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Key changes for `listUserTracks` and `listUserSetlists`:**
- Change method from `'POST'` to `'GET'`
- Move `searchQuery` from `body` to `queryParameters` (same pattern as `listBandTracks`)
- Include both `bandIdFilter` and `searchQuery` in `queryParameters` map using if-expressions
- Remove `body` parameter entirely

**Applied to:**
- `listUserTracks` (currently lines 281-292) → migrate to GET + queryParameters pattern
- `listUserSetlists` (currently lines 437-448) → migrate to GET + queryParameters pattern (mirrors listUserTracks exactly per existing comment at line 434)

---

### `lib/features/tracks/track_list_screen.dart` (screen, request-response)

**Analog:** `lib/features/setlists/add_setlist_tracks_dialog.dart` — debounce + online-gate pattern (lines 73-84)

**Add search TextField with debounced API calls**

**Imports pattern (from dialog):**
```dart
import 'dart:async';  // ← Add this for Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/connectivity_provider.dart';  // ← Add isOnlineProvider
import '../../providers/tracks_provider.dart';
```

**Current structure:** `TrackListScreen` is a `ConsumerWidget` — needs to become `ConsumerStatefulWidget` to manage search state and timers.

**Debounce pattern (COPY LINES 73-84 from add_setlist_tracks_dialog.dart):**
```dart
class _TrackListScreenState extends ConsumerState<TrackListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();  // Critical: prevent memory leaks
    super.dispose();
  }

  // Immediate local update + 300ms debounced network call (only while online)
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounceTimer?.cancel();
    if (!ref.read(isOnlineProvider)) return;  // Skip network if offline
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;  // Safety check before async callback
      ref
          .read(publicApiProvider)
          .listUserTracks(searchQuery: _searchQuery)
          .catchError((_) => <Map<String, dynamic>>[]);  // Fallback on error
    });
  }
```

**UI pattern (inline TextField above ListView, from add_setlist_tracks_dialog.dart lines 173-180):**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final tracksAsync = ref.watch(trackListDataProvider(bandId));
  final isOnline = ref.watch(isOnlineProvider);
  final l10n = AppLocalizations.of(context)!;

  return Scaffold(
    appBar: AppBar(title: Text(l10n.navTracks)),
    body: Column(  // ← Wrap existing body with Column to add search field
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.addSetlistTracksSearchHint,  // Reuse existing l10n key or create new
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: tracksAsync.when(
            data: (tracks) => _buildContent(context, tracks),
            // ... loading/error states unchanged
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(...),
  );
}
```

**State filtering logic (from add_setlist_tracks_dialog.dart lines 155-160):**
```dart
// Offline: filter via substring match; Online: use server results if available
if (!isOnline && _searchQuery.isNotEmpty) {
  availableTracks = [
    for (final track in availableTracks)
      if (trackMatchesSearchQuery(track, _searchQuery)) track,
  ];
}
```

---

### `lib/features/setlists/setlist_list_screen.dart` (screen, request-response)

**Analog:** `lib/features/setlists/add_setlist_tracks_dialog.dart` — debounce + online-gate pattern (lines 73-84)

**Add search TextField with debounced API calls**

**Pattern:** Identical to `track_list_screen.dart` above, but calls `listUserSetlists` instead of `listUserTracks`.

**Imports** — add `dart:async` and `connectivity_provider`:
```dart
import 'dart:async';
import '../../providers/connectivity_provider.dart';
```

**Debounce callback (same structure as tracks screen):**
```dart
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  _debounceTimer?.cancel();
  if (!ref.read(isOnlineProvider)) return;
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    ref
        .read(publicApiProvider)
        .listUserSetlists(searchQuery: _searchQuery)  // ← Call setlists endpoint
        .catchError((_) => <Map<String, dynamic>>[]);
  });
}
```

**No other differences from track_list_screen pattern.**

---

### `lib/features/setlists/add_setlist_tracks_dialog.dart` (dialog, request-response + result render)

**Analog:** This file itself — already has debounce + online-gate pattern; needs D-03 fix to render results.

**Fix the discarded search response (D-03)**

**Current broken pattern (LINES 73-84 — response is discarded):**
```dart
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  _debounceTimer?.cancel();
  if (!ref.read(isOnlineProvider)) return;
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    ref
        .read(publicApiProvider)
        .listBandTracks(widget.bandId, searchQuery: _searchQuery)
        .catchError((_) => <Map<String, dynamic>>[]);  // ← Result thrown away!
  });
}
```

**Fixed pattern (capture and render results):**
```dart
List<Map<String, dynamic>> _serverSearchResults = [];  // ← Add state var at class level

void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  _debounceTimer?.cancel();
  if (!ref.read(isOnlineProvider)) return;
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    ref
        .read(publicApiProvider)
        .listBandTracks(widget.bandId, searchQuery: _searchQuery)
        .then((results) {
          if (!mounted) return;
          setState(() => _serverSearchResults = results);  // ← Render results
        })
        .catchError((e) {
          // Continue showing local-filtered list on error
          debugPrint('Search error: $e');
        });
  });
}
```

**Update list display logic (CURRENT LINES 155-160):**
```dart
// OLD (always uses local filter offline, ignores server results):
if (!isOnline && _searchQuery.isNotEmpty) {
  availableTracks = [
    for (final track in availableTracks)
      if (trackMatchesSearchQuery(track, _searchQuery)) track,
  ];
}

// NEW (use server results while online, fallback to local filter):
if (isOnline && _serverSearchResults.isNotEmpty) {
  // Show server results when online and search returned data
  availableTracks = _serverSearchResults;
} else if (!isOnline && _searchQuery.isNotEmpty) {
  // Offline: filter via substring match
  availableTracks = [
    for (final track in availableTracks)
      if (trackMatchesSearchQuery(track, _searchQuery)) track,
  ];
}
```

---

### `lib/features/auth/login_screen.dart` (screen, request-response + form validation)

**Analog:** This file itself — password validator at lines 136-138 (needs D-04 fix)

**Fix password validator to gate minLength-8 to signup mode only**

**Current broken validator (LINES 136-138 — blocks login with short passwords):**
```dart
validator: (value) => (value == null || value.length < 8)
    ? l10n.commonAtLeast8Chars
    : null,
```

**Fixed validator (D-04 — condition on signup mode):**
```dart
validator: (value) {
  // Only enforce 8-char minimum in signup mode
  if (isSignUp && (value == null || value.length < 8)) {
    return l10n.commonAtLeast8Chars;
  }
  // Both modes require non-empty
  if (value == null || value.isEmpty) {
    return l10n.loginPasswordRequiredError;
    // OR if loginPasswordRequiredError doesn't exist, reuse:
    // return l10n.required;  // Check app_localizations.dart for exact key
  }
  return null;
},
```

**Context:** The validator is part of the password `TextFormField` (CURRENT LINES 127-139).
- `isSignUp` variable already exists at line 89: `final isSignUp = _mode == _AuthMode.signUp;`
- No new imports needed
- No change to ChangePasswordScreen (already correct per D-05)

---

## Shared Patterns

### Debounce + Online-Gating Pattern
**Source:** `lib/features/setlists/add_setlist_tracks_dialog.dart` (lines 73-84)
**Apply to:** New search UIs in `track_list_screen.dart` and `setlist_list_screen.dart`

```dart
// State variables (add to StatefulWidget):
final _searchController = TextEditingController();
String _searchQuery = '';
Timer? _debounceTimer;

// Disposal (critical):
@override
void dispose() {
  _searchController.dispose();
  _debounceTimer?.cancel();  // Prevent memory leaks
  super.dispose();
}

// Debounce callback:
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);      // Immediate local update (no debounce)
  _debounceTimer?.cancel();                  // Cancel any pending request
  if (!ref.read(isOnlineProvider)) return;   // Skip if offline
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;                    // Safety check
    ref
        .read(publicApiProvider)
        .listUserTracks(searchQuery: _searchQuery)  // Network call here
        .catchError((_) => <Map<String, dynamic>>[]);
  });
}
```

**Key invariants:**
1. Immediate `setState` (no debounce delay) for UI responsiveness
2. Timer-debounced network call (deferred 300ms after last keystroke)
3. Check `isOnlineProvider` *before* Timer setup to skip offline requests entirely
4. `if (!mounted) return;` before any setState in async callback (prevents "setState called after dispose" errors)
5. `.catchError()` fallback to empty list (network errors don't break search UX)
6. Timer cancellation in dispose() (prevents stale callbacks and memory leaks)

### Offline Fallback Search Pattern
**Source:** `lib/features/setlists/add_setlist_tracks_dialog.dart` (lines 155-160 + line 18 helper function)
**Apply to:** New search UIs in `track_list_screen.dart` and `setlist_list_screen.dart` (if offline support desired)

```dart
// Import the substring matcher:
import '../../features/setlists/add_setlist_tracks_dialog.dart' show trackMatchesSearchQuery;

// In build/display logic:
if (!isOnline && _searchQuery.isNotEmpty) {
  availableTracks = [
    for (final track in availableTracks)
      if (trackMatchesSearchQuery(track, _searchQuery)) track,
  ];
}
```

The `trackMatchesSearchQuery` helper (add_setlist_tracks_dialog.dart lines 18-23) handles case-insensitive substring matching on track title + artist.

### GET + Query Parameters API Pattern
**Source:** `lib/api/public_api.dart` → `listBandTracks` (lines 173-185)
**Apply to:** Migration of `listUserTracks` and `listUserSetlists`

```dart
// Pattern:
Future<List<Map<String, dynamic>>> methodName(
  String resourceId, {
  String? optionalFilter,
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',  // ← Not POST
    '/api/endpoint/$resourceId/resource/list',
    queryParameters: (searchQuery == null || searchQuery.isEmpty)
        ? null
        : {'searchQuery': searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Key invariants:**
- Use `'GET'` not `'POST'` for read-only filtering
- Move optional filters from `body` to `queryParameters` map
- Check for empty/null before including in queryParameters (avoid sending empty strings)
- Use if-expressions for conditional map entries: `{if (condition) 'key': value}`
- ApiClient.send() handles URL encoding of queryParameters automatically

### Conditional Form Validator Pattern
**Source:** `lib/features/auth/login_screen.dart` (lines 136-138, needs D-04 fix)
**Apply to:** Any form validator that changes rules based on context

```dart
validator: (value) {
  // Gate strict rules to specific mode/context
  if (isSignUp && (value == null || value.length < 8)) {
    return l10n.commonAtLeast8Chars;  // Strict for signup
  }
  // Common requirement for both modes
  if (value == null || value.isEmpty) {
    return l10n.required;  // Require non-empty always
  }
  return null;
}
```

**Key invariants:**
- Check context/mode first (e.g., `isSignUp`)
- Apply strict rules conditionally
- Apply common baseline rules (non-empty) to all paths
- Return l10n key (never hardcoded strings)

---

## No Analog Found

None. All changes reference existing, verified patterns from the codebase.

---

## Metadata

**Analog search scope:** `lib/api/`, `lib/features/*/`, `lib/providers/`
**Files scanned:** 8 key files
**Pattern extraction method:** Code inspection + line reference verification
**Date mapped:** 2026-08-27
**Confidence:** HIGH — all patterns extracted from existing, working code with line-number references

---

## Summary by Decision

| Decision | Pattern Source | Target File(s) |
|----------|---|---|
| **D-01** (Search UI + GET migration) | `add_setlist_tracks_dialog.dart` (debounce) + `public_api.dart` (GET pattern) | `track_list_screen.dart`, `setlist_list_screen.dart`, `public_api.dart` |
| **D-02** (Reuse debounce) | `add_setlist_tracks_dialog.dart` lines 73-84 | `track_list_screen.dart`, `setlist_list_screen.dart` |
| **D-03** (Render search results) | `add_setlist_tracks_dialog.dart` (fix `.catchError()` discard) | `add_setlist_tracks_dialog.dart` lines 73-84 |
| **D-04** (Password validator gate) | `login_screen.dart` validator at lines 136-138 (fix conditional) | `login_screen.dart` lines 127-139 |
| **D-05** (No ChangePassword change) | `change_password_screen.dart` (verified correct) | No action needed |

