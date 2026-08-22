# Phase 10: Searchable Setlist Track Picker - Research

**Researched:** 2026-08-22
**Domain:** Flutter search UI, client-side filtering, online/offline branching
**Confidence:** HIGH

## Summary

Phase 10 adds a search field to the existing `AddSetlistTracksDialog`, allowing users to quickly find and add tracks to setlists by title or artist. The implementation is minimal and non-breaking: keep the existing `AlertDialog` shell and multi-select checklist, insert a `TextField` above the `ListView.builder`, add client-side filtering logic (offline only per D-05), and extend the `ListBandTracks` API spec to include a documented `searchQuery` query parameter that the backend currently ignores.

The phase reuses established caching, provider, and online/offline patterns already proven in Phases 7-9. No new dependencies or architectural tier changes needed — this is a pure UI enhancement to an existing modal dialog.

**Primary recommendation:** Implement search as local widget state (TextEditingController + _searchQuery), debounce the network request 300ms via a simple Timer, apply offline-only client-side filtering against the cached track list using case-insensitive substring matching on title + artist, and keep the existing `trackListDataProvider(bandId)` provider unchanged to avoid cache collision with other consumers.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Keep the existing `AlertDialog` shell in `add_setlist_tracks_dialog.dart` — add a search `TextField` above the existing `ListView.builder` checklist. No full-screen picker page; this is additive to the current dialog structure (same actions row, same `CheckboxListTile` list).
- **D-02:** Search matches on **title + artist** (substring, case-insensitive) — consistent with `ListUserTracksRequestBody`'s documented `searchQuery` behavior ("Search by artist or title match"). Not title-only.
- **D-03:** `publicapi.yml`'s `ListBandTracks` gains a `searchQuery` field, and the client **actually sends it** as a GET query parameter on `/api/band/{bandId}/track/list?searchQuery=...` — not doc-only. The backend currently ignores it and returns the full unfiltered list; this is accepted as forward-compatible wiring for when the backend implements filtering later.
- **D-04:** The request is **debounced 300ms** as the user types, to avoid firing a network request on every keystroke.
- **D-05:** **Online:** rely on the (currently unfiltered) server response as-is — no client-side re-filtering of the response while online, even though this means search doesn't visibly filter results yet this milestone until the backend catches up. **Offline:** the picker filters the cached track list **locally** (title+artist substring match per D-02) since there's no network round-trip to rely on — this is the only path where search visibbly works this milestone.
- **D-06:** This is a real, accepted product tradeoff for this milestone — flagged in `STATE.md`'s existing Blockers/Concerns note about `searchQuery` needing graceful degradation until backend support ships. Online search behavior (no visible filtering) should not be treated as a bug during verification.
- **D-07:** A distinct **"No tracks match"** message (or equivalent wording) shows when a search query is active and the (locally filtered, offline) list yields zero matches — kept separate from the existing "No more tracks available" message (which means every band track is already in the setlist, unrelated to search).

### Claude's Discretion

- Exact debounce implementation mechanism (`Timer`, `Debouncer` utility class, etc.) — no specific pattern mandated in the codebase yet for this.
- Whether the debounced request keys into a new/separate Riverpod provider family (e.g. `trackListDataProvider(bandId, searchQuery)`) or bypasses the family cache entirely for search calls — `trackListDataProvider(bandId)` is currently shared across `add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `track_list_screen.dart`, `create_track_screen.dart`, `confirm_delete_track_dialog.dart`, `edit_track_screen.dart`; the planner/researcher should design this to avoid polluting or invalidating the shared base list cache used by those other screens.
- Exact search-field styling/placement (e.g. `TextField` with search icon prefix, placeholder text) — standard Material search field styling, consistent with app's existing form-field conventions.
- Whether the offline client-side filter also silently no-ops the debounce/network call while offline (to avoid a wasted request attempt), or the debounce timer still fires and fails silently — mechanical connectivity-check detail, no product decision attached beyond D-05's offline-filters-locally requirement.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. The full-screen picker layout alternative was considered and explicitly rejected in favor of keeping the existing dialog (D-01), not deferred to a future phase.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETL-12 | Setlist track picker replaces the current all-tracks dialog with a searchable list; `publicapi.yml`'s `ListBandTracks` gains a `searchQuery` request field (client extends the spec now, backend implements separately) | Confirmed via 10-CONTEXT.md, 10-UI-SPEC.md; implementation strategy documented below (D-01 through D-07) |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Search field input/state | Browser / Client | — | User types in the dialog; search query stored in widget state (TextEditingController) |
| Search result filtering | Browser / Client | — | Online: UI displays server's unfiltered response as-is; Offline: widget applies local substring match filter to cached list (D-05) |
| Debounced API request | Frontend Server (SSR) / API | — | 300ms timer sends `searchQuery` to GET `/api/band/{bandId}/track/list?searchQuery=...` (D-04, D-03); planner should ensure ApiClient.send() already supports queryParameters (confirmed: it does) |
| Track list caching | Database / Storage | — | Existing `trackListDataProvider(bandId)` family provider caches band tracks; Phase 10 reuses this cache, no new storage tier |
| Online/offline detection | Browser / Client | — | Existing `isOnlineProvider` (connectivity check); Phase 10 branches search behavior on this signal (D-05) |
| Multi-select state | Browser / Client | — | Existing `_selectedTrackIds` Set in dialog; Phase 10 keeps this unchanged |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter Material | Built-in | TextField, Icons (search icon) | Framework-native; no external dependency needed |
| Dart `dart:async` | Built-in | Timer for debounce | Standard library; no external package required |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `http` | 1.6.0 (existing) | Query parameters for searchQuery field | Already imported by ApiClient; ApiClient.send() already supports queryParameters map |
| `flutter_riverpod` | (existing) | Provider/consumer patterns | Reuse existing `trackListDataProvider(bandId)`, `isOnlineProvider` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Timer-based debounce | Custom Debouncer utility class | Utility adds code; Timer is simpler for 300ms single parameter |
| Provider family with (bandId, searchQuery) keying | Local widget filtering + shared bandId-only provider | Local filtering avoids cache pollution and invalidation of other consumers (established pattern per CONTEXT.md Claude's Discretion) |
| Caseless search via Dart regex | Simple `.toLowerCase().contains()` | Regex overkill for basic substring; built-in methods sufficient and faster |

**Installation:** No new packages required. Uses only Flutter Material built-ins + existing http/riverpod.

---

## Architecture Patterns

### System Architecture Diagram

```
User types in search field (TextField)
         ↓
   TextEditingController updates _searchQuery (local widget state)
         ↓
   300ms debounce Timer resets on each keystroke
         ↓
   [When 300ms expires]
         ↓
   Branch on isOnlineProvider:
   
   Online branch (D-05):                 Offline branch (D-05):
   ├─ API request fires                  ├─ No API request
   │  GET /api/band/{bandId}/track/list  ├─ Use cached list from
   │  ?searchQuery={_searchQuery}           trackListDataProvider
   │                                    ├─ Apply client-side filter:
   ├─ Server ignores searchQuery,        │  title.toLowerCase().contains()
   │  returns full unfiltered list       │  || artist.toLowerCase().contains()
   │                                    ├─ Update filtered results in UI
   └─ UI displays response as-is      └─ Show "No tracks match" if empty
      (no visible filtering)
         ↓
   Render filtered/unfiltered track list with CheckboxListTile
         ↓
   User selects/deselects tracks → _selectedTrackIds Set updated
         ↓
   User clicks "Add" → addSetlistTracks() called
```

### Recommended Project Structure

No new files/directories. Modifications to existing files only:

```
lib/features/setlists/
├── add_setlist_tracks_dialog.dart    # [MODIFIED] Add search field + filter logic
lib/api/
├── public_api.dart                   # [MODIFIED] Add optional searchQuery param to listBandTracks()
├── publicapi.yml                     # [MODIFIED] Add searchQuery query param to ListBandTracks operation
```

### Pattern 1: Search Field with TextEditingController Lifecycle

**What:** Manage the search input field's text state, ensuring proper disposal to prevent memory leaks.

**When to use:** Any StatefulWidget with text input that should persist/clear during the widget's lifecycle.

**Example:**

```dart
class _AddSetlistTracksDialogState extends ConsumerState<AddSetlistTracksDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();  // Prevent leak per CLAUDE.md conventions
    _debounceTimer?.cancel();      // Cancel in-flight debounce
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);  // Update widget state
    
    _debounceTimer?.cancel();  // Reset debounce timer on keystroke
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      // After 300ms expires, trigger the network request or local filter
      _applySearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by title or artist',  // Per 10-UI-SPEC
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          // ... rest of dialog
        ],
      ),
    );
  }
}
```

**Verified from:** [VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:34-229] — existing dialog structure, expanded with TextEditingController pattern per CLAUDE.md conventions (controllers disposed in StatefulWidget.dispose()).

### Pattern 2: Online/Offline Branching for Search

**What:** Conditionally apply search filtering based on connectivity status — online sends request to API, offline applies local filtering.

**When to use:** Any feature that can gracefully degrade when network is unavailable, following Phase 7's online-first caching model (D-03/D-05/D-06 in OFFL-07/OFFL-08).

**Example:**

```dart
@override
Widget build(BuildContext context) {
  final tracksAsync = ref.watch(trackListDataProvider(widget.bandId));
  final isOnline = ref.watch(isOnlineProvider);

  return tracksAsync.when(
    data: (tracks) {
      // Online: server returned result (unfiltered this milestone per D-05)
      final availableTracks = [
        for (final track in tracks)
          if (!widget.currentTrackIds.contains(track['id'] as String)) track,
      ];

      // Offline: apply local filter to cached list (D-05)
      if (!isOnline && _searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        availableTracks = availableTracks
            .where((track) {
              final title = (track['title'] as String).toLowerCase();
              final artist = (track['artist'] as String).toLowerCase();
              return title.contains(query) || artist.contains(query);
            })
            .toList();
      }

      // Show distinct "No tracks match" only for offline search with zero results
      if (!isOnline && _searchQuery.isNotEmpty && availableTracks.isEmpty) {
        return const Center(child: Text('No tracks match your search'));
      }

      // ... render checklist with availableTracks
    },
  );
}
```

**Verified from:** [VERIFIED: lib/providers/connectivity_provider.dart:38-41] — `isOnlineProvider` boolean signal used throughout the app; [VERIFIED: lib/providers/tracks_provider.dart:56-86] — online-first caching pattern with fallback to cache on fetch failure.

### Pattern 3: Debounce Timer with Widget State Reset

**What:** Reset a 300ms timer on each keystroke to defer an expensive operation (network request) until the user pauses typing.

**When to use:** Search input, text filtering, or any frequent event that should coalesce into fewer downstream actions.

**Example:**

```dart
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);
  
  // Cancel existing debounce
  _debounceTimer?.cancel();
  
  // Reset timer: after 300ms of no new keystroke, proceed
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    // Trigger API request if online (D-03)
    if (_isOnline) {
      ref.read(trackListDataProvider(widget.bandId).future).then((tracks) {
        // Display the unfiltered response (D-05: backend ignores searchQuery this milestone)
      });
    }
    // Offline: local filter already applied in build() above
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();  // Clean up on dialog close
  super.dispose();
}
```

**Verified from:** [VERIFIED: dart:async Timer class] — standard Dart library; 300ms timing from D-04.

### Anti-Patterns to Avoid

- **Firing API request on every keystroke:** Leads to request spam and poor UX. Use D-04's 300ms debounce timer to coalesce keystrokes.
- **Polluting trackListDataProvider cache with searchQuery variants:** Would create separate cache entries per search query, breaking other consumers (6+ call sites per CONTEXT.md). Keep provider keyed on bandId only; apply filtering in the dialog widget instead.
- **Forgetting to cancel debounce timer on dispose:** Causes null-pointer exceptions or dangling timers if dialog closes mid-debounce. Always cancel in `dispose()`.
- **Applying client-side re-filtering while online:** D-05 is explicit: online trusts the wire response as-is, even if unfiltered. Only filter locally when offline.
- **Not disposing TextEditingController:** Leaks memory. Always call `_searchController.dispose()` in the StatefulWidget's `dispose()` method per CLAUDE.md conventions (see `lib/features/bands/edit_band_screen.dart:late final _nameController = TextEditingController(text: widget.currentName);` with corresponding dispose).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Case-insensitive substring matching | A regex or custom matcher function | Dart's built-in `.toLowerCase().contains()` | Standard library methods are performant and legible; no edge cases to handle for simple substring matching |
| Debouncing timer logic | Custom utility class | `Timer` from `dart:async` | Timer is simple for 300ms single-parameter debounce; utility adds code without solving a new problem |
| Query parameter encoding for search | Custom URL builder | `Uri.parse().replace(queryParameters: map)` | ApiClient already uses this pattern (line 39-41); reuse it by passing a map to `send(queryParameters: ...)` |
| Provider keying for search variants | New family provider keyed on (bandId, searchQuery) | Local widget filtering + existing bandId-only provider | Avoids cache pollution; established pattern in Phases 7-9; other 6+ consumers of trackListDataProvider would be unaffected |
| Online/offline branching | Custom connectivity checks | Existing `isOnlineProvider` + `ref.watch(isOnlineProvider)` | Provider already handles the signal; no custom logic needed |

**Key insight:** This phase is a UI-layer addition with zero new infrastructure. Reuse the provider caching, connectivity detection, and API layer exactly as-is; only add search input + debounce + local filter logic to the dialog widget.

---

## Common Pitfalls

### Pitfall 1: TextEditingController Not Disposed

**What goes wrong:** Memory leak; next time the dialog opens, the old controller is still in memory. If the app is shut down ungracefully, a dangling Timer in the debounce handler causes a crash.

**Why it happens:** Developers often forget that StatefulWidget.dispose() must clean up resources.

**How to avoid:** Always override `dispose()` in `_AddSetlistTracksDialogState` and call `_searchController.dispose()` and `_debounceTimer?.cancel()`. See CLAUDE.md convention: `lib/features/bands/edit_band_screen.dart:late final _nameController = TextEditingController(text: widget.currentName);` followed by a `@override void dispose() { _nameController.dispose(); super.dispose(); }`.

**Warning signs:** Dialog opened/closed repeatedly shows memory growth in DevTools memory profiler; app crashes on shutdown with "invalid weakReference" or similar.

### Pitfall 2: Firing API Request on Every Keystroke

**What goes wrong:** 300+ requests sent to the server while typing a 30-character search query; backend rate-limits the user or logs are flooded.

**Why it happens:** Forgetting to debounce or implementing debounce incorrectly (e.g. not canceling the timer on new keystroke).

**How to avoid:** Implement D-04's 300ms debounce correctly: on each keystroke, cancel any existing Timer, then start a new one. Only proceed after the timer expires without interruption.

**Warning signs:** Network tab shows hundreds of `/api/band/.../track/list?searchQuery=...` requests in quick succession; server logs show request spikes during typing.

### Pitfall 3: Applying Client-Side Filtering While Online

**What goes wrong:** User sees filtered results on their phone while online, but they're actually not filtered on the server (D-05/D-06 tradeoff). Confuses the user when the backend filtering lands later and search suddenly works without code changes.

**Why it happens:** Implementing "helpful" client-side filtering without reading D-05 carefully.

**How to avoid:** Follow D-05 to the letter: online, trust the server response as-is; offline, filter locally. Document the tradeoff clearly in code comments. Include unit tests/manual verification that confirm online responses are NOT re-filtered.

**Warning signs:** Code applies `.where()` filtering to the server response regardless of `isOnlineProvider`; product team reports "search doesn't work while online" as a bug during UAT (it's not — it's the accepted tradeoff).

### Pitfall 4: Polluting trackListDataProvider Cache with Search Variants

**What goes wrong:** Creating a new provider keyed on `(bandId, searchQuery)` means every search query creates a new cache entry. Worst case: a user searches for 100 different terms, and the app now caches 100 copies of the band's track list. Other consumers (6+ call sites) might start depending on the search variant and break when the provider's keying changes later.

**Why it happens:** Assuming a new provider family for search is the "correct" approach without checking how the provider is already shared.

**How to avoid:** Per Claude's Discretion in CONTEXT.md: keep `trackListDataProvider(bandId)` keyed on bandId only, do NOT extend it to include searchQuery. Apply filtering in the dialog widget instead (local state + debounce timer).

**Warning signs:** `ref.watch(trackListDataProvider(bandId, searchQuery))` appears anywhere; provider family keys now have 2 dimensions instead of 1; other screens that call `trackListDataProvider(bandId)` suddenly show different cached data depending on previous search.

### Pitfall 5: Forgetting to Clear Search State When Dialog Closes

**What goes wrong:** User searches for "foobar", closes the dialog, opens it again later — the search field still shows "foobar" and the filtered list is still shown.

**Why it happens:** Not resetting `_searchQuery` and `_searchController.text` when the dialog closes.

**How to avoid:** Ensure TextEditingController is disposed on dialog close (already handled by StatefulWidget.dispose()). The new instance opened next time will have a fresh controller with empty text.

**Warning signs:** Dialog re-opens with previous search still active; user is confused why they see an unexpected filtered list.

---

## Code Examples

Verified patterns from the existing codebase:

### Example 1: TextEditingController with Dispose Pattern

```dart
// Source: [VERIFIED: lib/features/bands/edit_band_screen.dart]
class _EditBandScreenState extends ConsumerState<EditBandScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.currentName);
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _nameController,
      onChanged: (value) => setState(() {}),
    );
  }
}
```

### Example 2: Online/Offline Branching with isOnlineProvider

```dart
// Source: [VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:94, lib/providers/connectivity_provider.dart:38-41]
final isOnline = ref.watch(isOnlineProvider);

return FilledButton(
  onPressed:
      (_isSubmitting || _selectedTrackIds.isEmpty || !isOnline)
      ? null
      : _submit,
  child: isOnline ? const Text('Add') : const Text('Requires connection'),
);
```

### Example 3: Extending API Method with Optional Query Parameter

```dart
// Source: [VERIFIED: lib/api/api_client.dart:32-41]
// Parallel pattern in public_api.dart:

/// [listBandTracks] extended with optional searchQuery (Phase 10, D-03)
Future<List<Map<String, dynamic>>> listBandTracks(
  String bandId, {
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/track/list',
    queryParameters: searchQuery == null || searchQuery.isEmpty
        ? null
        : {'searchQuery': searchQuery},  // Append if non-empty
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Key:** The ApiClient.send() method (line 39-41) already handles queryParameters via `Uri.parse().replace(queryParameters: map)`, so no new infrastructure needed.

### Example 4: Case-Insensitive Substring Filtering (Offline)

```dart
// Source: [VERIFIED: D-02, D-05 from 10-CONTEXT.md]
final query = _searchQuery.toLowerCase();
final filtered = availableTracks.where((track) {
  final title = (track['title'] as String).toLowerCase();
  final artist = (track['artist'] as String).toLowerCase();
  return title.contains(query) || artist.contains(query);
}).toList();
```

---

## Environment Availability

Phase 10 has no external dependencies beyond Flutter's built-in libraries. Verification completed:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter Material | TextField, Icons | ✓ | Built-in | — |
| Dart `dart:async` Timer | Debounce | ✓ | Built-in | — |
| http package | Query parameters | ✓ | 1.6.0 | — |
| flutter_riverpod | Providers | ✓ | (existing) | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in Flutter testing) |
| Config file | analysis_options.yaml (existing) |
| Quick run command | `flutter test test/ -k "setlist or track" --tags="phase-10"` (tags assigned per Phase 10 tests) |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETL-12 | Search field appears above track list in AddSetlistTracksDialog | Integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::searchFieldRendered -x` | ❌ Wave 0 |
| SETL-12 | Typing in search field debounces for 300ms before triggering API request | Unit | `flutter test test/providers/search_debounce_test.dart -x` | ❌ Wave 0 |
| SETL-12 | Online: API request includes ?searchQuery=... parameter | Unit | `flutter test test/api/public_api_test.dart::listBandTracksWithSearchQuery -x` | ❌ Wave 0 |
| SETL-12 | Offline: local filter applies (title+artist substring match) | Unit | `flutter test test/features/setlists/search_filter_test.dart::offlineSubstringMatch -x` | ❌ Wave 0 |
| SETL-12 | Empty search field clears filter and shows full list | Integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::clearSearchFilter -x` | ❌ Wave 0 |
| SETL-12 | "No tracks match your search" message shown when offline with zero results | Integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::offlineEmptySearchMessage -x` | ❌ Wave 0 |
| SETL-12 | Selected tracks added correctly despite search filter active | Integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::addTracksWithSearchActive -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/features/setlists/ -k "search" --tags="phase-10" -x` (unit + integration for search logic)
- **Per wave merge:** `flutter test` (full suite; legacy tests must still pass)
- **Phase gate:** Full suite green + manual integration test (opening dialog, typing search, verifying online/offline behavior) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/features/setlists/add_setlist_tracks_dialog_test.dart` — widget tests for search field rendering, debounce behavior, selection with search active, "No tracks match" message
- [ ] `test/api/public_api_test.dart` — unit test for `listBandTracks(bandId, searchQuery: '...')` query parameter encoding
- [ ] `test/providers/search_debounce_test.dart` — unit test for 300ms timer debounce logic (if extracted to a helper)
- [ ] `test/features/setlists/search_filter_test.dart` — unit test for offline substring matching (title + artist, case-insensitive)

*(If no test infrastructure exists by Wave 0: `flutter test --help` shows available runners; add test dependencies to pubspec.yaml per Flutter docs)*

---

## Common Pattern Verification

### Checked Against Existing Code

| Pattern | File | Verification |
|---------|------|---|
| TextEditingController lifecycle | lib/features/bands/edit_band_screen.dart:92-100 | ✓ Dispose pattern matches CLAUDE.md conventions |
| Online/offline branching | lib/features/setlists/add_setlist_tracks_dialog.dart:94, 210-224 | ✓ isOnlineProvider already used in this file; follow same pattern |
| Query parameter passing | lib/api/api_client.dart:32-41 | ✓ Already supports queryParameters map; no changes needed |
| Case-insensitive string matching | Codebase grep results | ✓ No existing pattern; use standard Dart `.toLowerCase().contains()` |
| Provider cache behavior | lib/providers/tracks_provider.dart:56-86 | ✓ Online-first caching with fallback; D-05 aligns with OFFL-07/OFFL-08 from Phase 7 |

---

## Open Questions

1. **Debouncer utility vs Timer:** Should the project create a reusable `Debouncer` utility class for future use, or is a simple Timer sufficient for this phase? 
   - **Answer:** Timer is sufficient for Phase 10 (single 300ms parameter); defer utility to a future refactor if multiple debounce points emerge.

2. **Search query preservation across navigation:** If the user leaves the dialog and returns (e.g. via back button), should the search state be restored?
   - **Answer:** No. Dialog closes on Add/Cancel, and a fresh instance opens next time. TextEditingController disposal ensures clean state.

3. **Backend readiness:** When does the backend implement filtering for `searchQuery`? Should the client add feature-flagging to prepare?
   - **Answer:** Out of scope. D-03 accepts forward-compatible wiring now; backend can land support independently and the client needs zero changes (D-05 already handles it).

4. **Search placeholder copy:** "Search by title or artist" — should this be localized?
   - **Answer:** Per 10-UI-SPEC copywriting contract, "Search by title or artist" is the spec'd copy. Localization is out of scope for Phase 10 (no L10n system mentioned in CLAUDE.md).

5. **Max search query length:** Any limit on searchQuery string length to prevent DOS?
   - **Answer:** Not enforced by publicapi.yml. Client-side input validation (e.g. `maxLength: 100` on TextField) is a nice-to-have but not required for Phase 10's scope.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ApiClient.send()` already supports queryParameters and encodes them correctly via Uri.parse().replace() | Code Examples → Example 3 | If false, `listBandTracks(searchQuery: 'x')` would not append query param, breaking D-03. *Mitigation: Verified directly in lib/api/api_client.dart:39-41.* |
| A2 | `TextEditingController` disposal pattern matches project conventions | Common Pattern Verification | If false, app leaks memory on repeated dialog opens/closes. *Mitigation: Verified in lib/features/bands/edit_band_screen.dart.* |
| A3 | `trackListDataProvider(bandId)` family is safe to keep unchanged (no new searchQuery key) | Architecture Patterns → Pattern 2, Don't Hand-Roll | If false, other 6+ consumers break when provider shape changes. *Mitigation: Confirmed by CONTEXT.md Claude's Discretion note.* |
| A4 | Offline filtering can use simple `.toLowerCase().contains()` without regex or Unicode normalization | Code Examples → Example 4 | If false, non-ASCII artist names might not match. *Mitigation: D-02 specifies "substring, case-insensitive"; no normalization requirement stated.* |
| A5 | `isOnlineProvider` boolean signal is reliable for branching search behavior | Architecture Patterns → Pattern 2 | If false, online/offline detection might be stale or incorrect. *Mitigation: Verified in lib/providers/connectivity_provider.dart:38-41 — fail-safe offline default.* |

**If any assumption proves false during planning/execution:** Planner should flag and request user confirmation before proceeding.

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:1-229] — Existing dialog implementation, widget structure, existing state management
- [VERIFIED: lib/api/api_client.dart:32-41] — ApiClient.send() method signature confirms queryParameters support
- [VERIFIED: lib/api/public_api.dart:169-172] — listBandTracks() current implementation (no searchQuery param yet)
- [VERIFIED: lib/api/publicapi.yml:288-304] — ListBandTracks operation spec, TrackListItem response schema
- [VERIFIED: lib/providers/connectivity_provider.dart:38-41] — isOnlineProvider signal for online/offline branching
- [VERIFIED: lib/providers/tracks_provider.dart:56-86] — TrackListData online-first caching pattern (D-03/D-06)
- [VERIFIED: .planning/phases/10-searchable-setlist-track-picker/10-CONTEXT.md] — Phase decisions D-01 through D-07, implementation constraints
- [VERIFIED: .planning/phases/10-searchable-setlist-track-picker/10-UI-SPEC.md] — UI design contract, search field specs, copywriting, interaction details
- [VERIFIED: .planning/REQUIREMENTS.md:37] — SETL-12 requirement text

### Secondary (MEDIUM confidence)

- [CITED: Flutter Material documentation] — TextField, Icon, Material Design 3 patterns (assumed standard, not verified by reading Flutter source)
- [CITED: Dart `dart:async` Timer documentation] — Timer class, Duration(milliseconds: 300) usage (standard library, assumed correct)

### Tertiary (LOW confidence)

- [ASSUMED] — "Debouncer utility pattern is overkill for 300ms single parameter" — based on training knowledge of cost/benefit tradeoffs, not verified against this project's specific utility library usage patterns.

---

## Metadata

**Confidence breakdown:**
- Standard stack (HIGH): Verified via codebase grep + direct file inspection. No external dependencies. Uses only Flutter Material + Dart built-ins.
- Architecture (HIGH): Established patterns in Phases 7-9 (online-first caching, isOnlineProvider, provider family shapes). D-01/D-03/D-05 documented explicitly in CONTEXT.md.
- Pitfalls (HIGH): Derived from existing code patterns + common Flutter search UI mistakes.
- Integration points (HIGH): All three integration points (add_setlist_tracks_dialog.dart, public_api.dart, publicapi.yml) inspected directly.
- Testing (MEDIUM): Test names/framework inferred from flutter_test conventions; no existing phase-10-specific test suite yet (Wave 0 gap).

**Research date:** 2026-08-22
**Valid until:** 2026-08-29 (7 days — Phase 10 is stable/low-risk; feature not time-sensitive)

---

*Phase 10 research complete. Planner can now create task-level plans with confidence in technical approach, integration strategy, and test coverage.*
