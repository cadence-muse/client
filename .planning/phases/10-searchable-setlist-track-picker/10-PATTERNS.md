# Phase 10: Searchable Setlist Track Picker - Pattern Map

**Mapped:** 2026-08-22
**Files analyzed:** 3 files (1 screen component, 1 service method, 1 spec file)
**Analogs found:** 3 / 3 (100% coverage)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | component (dialog) | request-response + local filtering | Self (existing) + `lib/features/bands/edit_band_screen.dart` (TextEditingController) | exact |
| `lib/api/public_api.dart` | service (API wrapper) | request-response | Self (existing) + `listUserTracks()` method pattern | exact |
| `lib/api/publicapi.yml` | config (OpenAPI spec) | specification | Self (existing) + `ListBandTracks` operation | exact |

---

## Pattern Assignments

### `lib/features/setlists/add_setlist_tracks_dialog.dart` (component, request-response + filtering)

**Primary Analog:** `lib/features/setlists/add_setlist_tracks_dialog.dart` (existing file being modified)

**Secondary Analog for TextEditingController pattern:** `lib/features/bands/edit_band_screen.dart`

#### Import pattern (add to existing imports)
**Source:** `lib/features/bands/edit_band_screen.dart:1-8`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';
```

*(Existing imports already present; no new import paths needed — only Flutter Material + dart:async Timer)*

#### TextEditingController lifecycle pattern
**Source:** `lib/features/bands/edit_band_screen.dart:26-36`

```dart
class _EditBandScreenState extends ConsumerState<EditBandScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.currentName);

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
```

**Apply to:** Add search controller initialization and disposal in `_AddSetlistTracksDialogState`:

```dart
class _AddSetlistTracksDialogState
    extends ConsumerState<AddSetlistTracksDialog> {
  // ... existing fields ...
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();  // Per CLAUDE.md conventions
    _debounceTimer?.cancel();      // Clean up in-flight debounce
    super.dispose();
  }
```

#### Existing dialog state pattern
**Source:** `lib/features/setlists/add_setlist_tracks_dialog.dart:34-44`

```dart
class _AddSetlistTracksDialogState
    extends ConsumerState<AddSetlistTracksDialog> {
  static const int _maxSetlistTracks = 100;

  final Set<String> _selectedTrackIds = {};
  bool _isSubmitting = false;
  String? _errorMessage;
```

**Keep unchanged** — these fields remain as-is; only add the search field fields above.

#### Error handling pattern (existing)
**Source:** `lib/features/setlists/add_setlist_tracks_dialog.dart:80-88`

```dart
    on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Failed to add tracks. Try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
```

**Keep as-is** — reuse existing error handling for `_submit()`.

#### Search field rendering pattern (new TextField to insert)
**Source:** Material Design + RESEARCH.md Pattern 1

```dart
TextField(
  controller: _searchController,
  onChanged: _onSearchChanged,
  decoration: InputDecoration(
    hintText: 'Search by title or artist',
    prefixIcon: const Icon(Icons.search),
  ),
),
```

**Insert into:** `AlertDialog.content` Column, above the existing `ListView.builder` (lines 110-163 in current file).

#### Debounce timer pattern (new method to add)
**Source:** `dart:async` Timer, per RESEARCH.md Pattern 3

```dart
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  
  // Cancel existing debounce timer on each keystroke
  _debounceTimer?.cancel();
  
  // Reset timer: after 300ms of no new keystroke, proceed (D-04)
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    // Trigger API request if online; offline filtering happens in build()
    if (mounted) {
      setState(() {}); // Trigger rebuild to apply local filter offline
    }
  });
}
```

#### Online/offline branching pattern for search filtering
**Source:** `lib/features/setlists/add_setlist_tracks_dialog.dart:92-94` (existing isOnlineProvider usage)

**Combined with:** `lib/providers/tracks_provider.dart:56-86` (online-first caching) + RESEARCH.md Pattern 2

```dart
@override
Widget build(BuildContext context) {
  final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));
  final isOnline = ref.watch(isOnlineProvider);  // Per D-05

  return AlertDialog(
    // ... title, etc ...
    content: SizedBox(
      width: double.maxFinite,
      child: tracksAsync.when(
        data: (tracks) {
          // Filter by tracks not already in setlist (existing logic)
          final availableTracks = [
            for (final track in tracks)
              if (!widget.currentTrackIds.contains(track['id'] as String))
                track,
          ];
          
          // Offline: apply client-side substring filter (D-05)
          if (!isOnline && _searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            availableTracks.retainWhere((track) {
              final title = (track['title'] as String).toLowerCase();
              final artist = (track['artist'] as String).toLowerCase();
              return title.contains(query) || artist.contains(query);
            });
          }
          
          // Show "No tracks match" message only when offline search yields zero results (D-07)
          if (!isOnline && _searchQuery.isNotEmpty && availableTracks.isEmpty) {
            return const Center(child: Text('No tracks match your search'));
          }
          
          // Existing "No more tracks available" message (when list is genuinely empty, unrelated to search)
          if (availableTracks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No more tracks available'),
            );
          }
          
          // ... rest of existing CheckboxListTile list rendering ...
        },
        // ... loading/error branches unchanged ...
      ),
    ),
  );
}
```

**Key distinction:** Online (D-05): trust server response as-is, no client-side re-filtering. Offline: apply local substring match to cached list only. See CONTEXT.md D-05/D-06 for the product tradeoff rationale.

---

### `lib/api/public_api.dart` (service, request-response)

**Analog:** `lib/api/public_api.dart` itself — existing method with optional parameter pattern

#### Method signature with optional query parameter
**Source:** `lib/api/public_api.dart:268-279` (listUserTracks — reference pattern for optional searchQuery)

```dart
/// Returns tracks across every band the current user belongs to
/// (`UserTrackListItem` — id/title/artist/durationSeconds/bandId/bandName),
/// optionally narrowed to a single band via [bandIdFilter]. `GET`->`POST`
/// migration per the `fe72e78` schema update; `bandIdFilter` remains a
/// query parameter (`BandIdFilter` is still `in: query`). [searchQuery] is
/// accepted by the wire schema (`ListUserTracksRequestBody`) but not yet
/// driven by any UI in this phase — no search input exists yet (distinct
/// from Phase 10's `SETL-12`, a different endpoint's `searchQuery`).
Future<List<Map<String, dynamic>>> listUserTracks({
  String? bandIdFilter,
  String? searchQuery,
}) async {
  final response = await _client.send(
    'POST',
    '/api/track/list',
    queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
    body: {'searchQuery': ?searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

#### Modify listBandTracks to match pattern (Phase 10 modification)
**Current code:** `lib/api/public_api.dart:169-172`

```dart
/// Returns a band's tracks (`TrackListItem` — id/title/artist +
/// optional durationSeconds).
Future<List<Map<String, dynamic>>> listBandTracks(String bandId) async {
  final response = await _client.send('GET', '/api/band/$bandId/track/list');
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Modify to (Phase 10, D-03):**

```dart
/// Returns a band's tracks (`TrackListItem` — id/title/artist +
/// optional durationSeconds). [searchQuery] is a client-side spec extension
/// (Phase 10, SETL-12, D-03) — the backend currently ignores it and returns
/// the full unfiltered list, accepted as forward-compatible wiring for when
/// backend filtering lands. The client branches behavior on [isOnlineProvider]
/// (D-05): online trusts server response as-is; offline applies local
/// substring filtering (title+artist match, case-insensitive, D-02).
Future<List<Map<String, dynamic>>> listBandTracks(
  String bandId, {
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/track/list',
    queryParameters: searchQuery == null || searchQuery.isEmpty
        ? null
        : {'searchQuery': searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

#### Query parameter handling (already supported by ApiClient)
**Source:** `lib/api/api_client.dart:32-41`

```dart
  Future<Map<String, dynamic>?> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
```

**Note:** No changes needed to ApiClient — the `queryParameters` parameter is already supported and properly encodes query strings via `Uri.replace()`. Simply pass the map to the `send()` method from `listBandTracks()`.

---

### `lib/api/publicapi.yml` (config/specification)

**Analog:** `lib/api/publicapi.yml` itself — existing OpenAPI operation

#### Current ListBandTracks operation
**Source:** `lib/api/publicapi.yml:288-304`

```yaml
  /api/band/{bandId}/track/list:
    get:
      operationId: ListBandTracks
      summary: List all band tracks
      security:
        - sessionAuth: [ ]
      parameters:
        - $ref: '#/components/parameters/BandId'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ListBandTracksResponseBody'
        '400':
          $ref: '#/components/responses/BadRequest'
```

#### Modify to add searchQuery parameter (Phase 10, D-03)

Add a new `searchQuery` parameter to the `parameters` list (after BandId):

```yaml
  /api/band/{bandId}/track/list:
    get:
      operationId: ListBandTracks
      summary: List all band tracks
      description: |
        Returns all tracks in the band. The optional `searchQuery` parameter
        (Phase 10, client-side spec extension) is accepted but currently
        ignored by the backend (forward-compatible for future server-side
        filtering). For client-side filtering behavior, see implementation
        notes in the Dart method.
      security:
        - sessionAuth: [ ]
      parameters:
        - $ref: '#/components/parameters/BandId'
        - name: searchQuery
          in: query
          required: false
          schema:
            type: string
          description: |
            Search by track title or artist (substring, case-insensitive).
            Consistent with ListUserTracksRequestBody's documented searchQuery
            behavior (D-02 in Phase 10). Backend currently ignores this
            parameter and returns the full unfiltered list; client applies
            offline-only local filtering per D-05.
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ListBandTracksResponseBody'
        '400':
          $ref: '#/components/responses/BadRequest'
```

---

## Shared Patterns

### Online/Offline Branching Signal
**Source:** `lib/providers/connectivity_provider.dart:37-41`

```dart
/// The single value every other file in this phase watches — no other file
/// should call `.when()` on [connectivityProvider] directly. Resolves to
/// `true` only for `AsyncData(ConnectivityStatus.online)`; both
/// `AsyncLoading` and `AsyncError` (including a `connectivity_plus`
/// platform-channel failure) resolve to `false` — fail-safe offline default.
@riverpod
bool isOnline(IsOnlineRef ref) {
  final status = ref.watch(connectivityProvider);
  return status.asData?.value == ConnectivityStatus.online;
}
```

**Apply to:** All online/offline conditionals in Phase 10 (search filtering, request debounce).

### String Matching (Case-Insensitive Substring)
**Source:** D-02 + Dart built-ins (no existing codebase pattern, standard library)

```dart
final query = _searchQuery.toLowerCase();
final filtered = availableTracks.where((track) {
  final title = (track['title'] as String).toLowerCase();
  final artist = (track['artist'] as String).toLowerCase();
  return title.contains(query) || artist.contains(query);
}).toList();
```

**Apply to:** All offline search filtering logic in `add_setlist_tracks_dialog.dart`.

**Why:** Simple substring matching is performant and sufficient for D-02's requirements; no regex or Unicode normalization needed.

### Debounce Timer Pattern
**Source:** `dart:async` Timer (standard library, no existing project pattern)

```dart
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  
  _debounceTimer?.cancel();  // Cancel previous timer
  
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    // Proceed after 300ms idle (D-04)
    if (mounted) setState(() {});
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();  // Clean up on widget disposal
  super.dispose();
}
```

**Apply to:** Search field `onChanged` handler in `add_setlist_tracks_dialog.dart`.

**Rationale:** 300ms debounce per D-04; simple Timer sufficient for single 300ms parameter (no Debouncer utility needed this phase).

---

## Integration Points Summary

| File | Integration | Details |
|------|-------------|---------|
| `add_setlist_tracks_dialog.dart` | UI layer: search field + debounce + offline filtering | Add TextField + TextEditingController + Timer + online/offline branching logic |
| `public_api.dart` | Service layer: API method signature | Extend `listBandTracks()` with optional `searchQuery` parameter |
| `publicapi.yml` | Spec layer: contract documentation | Add `searchQuery` query parameter to `ListBandTracks` operation (D-03) |

**Note:** `trackListDataProvider(bandId)` in `lib/providers/tracks_provider.dart` remains unchanged (keyed by bandId only per CONTEXT.md Claude's Discretion) — search filtering is applied locally in the dialog widget, not via a new provider family.

---

## Metadata

**Analog search scope:** `lib/features/` (screens/components), `lib/api/` (HTTP/spec), `lib/providers/` (state management)

**Files scanned:** 15+ source files

**Pattern extraction date:** 2026-08-22

**Confidence breakdown:**
- TextEditingController lifecycle: HIGH (verified in edit_band_screen.dart)
- Query parameter handling: HIGH (verified in api_client.dart + listUserTracks pattern)
- Online/offline branching: HIGH (established in Phase 7-9, already used in add_setlist_tracks_dialog.dart)
- Debounce Timer: HIGH (standard library, no project-specific pattern needed)
- Case-insensitive substring matching: HIGH (standard Dart, sufficient for D-02)

---

*Phase 10 pattern mapping complete. Planner can now reference analog patterns in task-level plans.*
