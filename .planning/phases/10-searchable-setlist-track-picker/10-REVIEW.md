---
phase: 10-searchable-setlist-track-picker
reviewed: 2026-08-22T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/api/public_api.dart
  - lib/api/publicapi.yml
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - test/api/public_api_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/search_filter_test.dart
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-08-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the searchable setlist track picker phase: the new `searchQuery` query
parameter on `ListBandTracks` (`public_api.dart` + `publicapi.yml`), and the
offline-substring-filter / online-debounced-network-call search UI added to
`AddSetlistTracksDialog`. `flutter analyze` is clean and all 34 tests across the
three test files pass. No crashes, security issues, or data-loss risks were
found. The implementation correctly layers "exclude already-in-setlist tracks"
→ "offline substring filter" → "100-track-cap selection guard", and the tests
exercise the debounce timing, online/offline branching, and submit-with-search-
active paths well.

Issues found are all quality/robustness in nature: an unhandled whitespace edge
case in the new substring-match function, a fire-and-forget network call whose
result is unconditionally discarded (by design, but worth flagging as ongoing
cost with zero payoff), a `build()` method that has grown past a size where it's
easily reviewable, and a pre-existing (not introduced by this phase) doc/spec
mismatch discovered while reading the full file.

## Warnings

### WR-01: `trackMatchesSearchQuery` and the debounce gate don't trim whitespace, so padded/whitespace-only queries silently break substring matching

**File:** `lib/features/setlists/add_setlist_tracks_dialog.dart:16-21` (also affects the `_onSearchChanged` empty-check at `:80` and `PublicApi.listBandTracks`'s empty-check at `lib/api/public_api.dart:180-182`)

**Issue:** Neither the new offline matcher nor the "should I fire a debounced
request" check trims the query before comparing:

```dart
bool trackMatchesSearchQuery(Map<String, dynamic> track, String query) {
  if (query.isEmpty) return true;
  final lowerQuery = query.toLowerCase();
  return (track['title'] as String).toLowerCase().contains(lowerQuery) ||
      (track['artist'] as String).toLowerCase().contains(lowerQuery);
}
```

Two concrete consequences:
1. A query with a leading/trailing space (e.g. `' oasis '` — plausible from
   mobile-keyboard auto-space or copy/paste) will no longer match "Oasis"
   because `'oasis'.contains(' oasis ')` is `false`. The user's search
   silently returns fewer/no results even though the intent was an exact
   match.
2. A query that is *only* whitespace (e.g. a single space) is not treated as
   "empty" by `query.isEmpty`, so it (a) still arms the 300ms debounced
   network request while online, and (b) offline, filters the list down to
   only tracks whose title/artist happen to contain a literal space
   character — an inconsistent, hard-to-explain result for what the user
   perceives as "I cleared my search."

**Fix:** Trim once and reuse:

```dart
bool trackMatchesSearchQuery(Map<String, dynamic> track, String query) {
  final trimmedQuery = query.trim().toLowerCase();
  if (trimmedQuery.isEmpty) return true;
  return (track['title'] as String).toLowerCase().contains(trimmedQuery) ||
      (track['artist'] as String).toLowerCase().contains(trimmedQuery);
}
```

and apply `.trim()` to `_searchQuery` (or the value passed in) at the
`_onSearchChanged` empty-check / before calling `listBandTracks`, so the
"is this an empty search" decision is consistent across the offline filter,
the debounce gate, and the outgoing query parameter.

### WR-02: The 300ms-debounced online search request's result is unconditionally discarded — real network calls with zero observable effect

**File:** `lib/features/setlists/add_setlist_tracks_dialog.dart:77-88`

**Issue:**

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
        .catchError((_) => <Map<String, dynamic>>[]);
  });
}
```

Every keystroke (after the 300ms debounce settles) fires a real, authenticated
HTTP GET against the backend, and the response — success or failure — is
thrown away (`catchError` swallows it into an unused empty list; nothing reads
it). This is called out in code comments as intentional forward-compatible
wiring (D-03/D-04/D-05) ahead of server-side filtering support, but as shipped
it is pure cost with no current payoff: it consumes user bandwidth/battery,
adds load to the backend for every band member searching, and any failure is
silently swallowed with no telemetry, so a regression here (e.g. wrong path,
auth issue) would be invisible in production. Since the backend is documented
to ignore the parameter entirely today, this network call currently does
nothing for any user in any state.

**Fix:** Either remove the network call until the backend actually implements
`searchQuery` filtering (re-add it alongside the UI work that consumes the
response), or, if forward-compat wiring is genuinely wanted now, at minimum
guard against firing when the query is unchanged/empty and consider logging
the failure path instead of blanket-swallowing it, so a real backend/auth
regression doesn't go unnoticed:

```dart
_debounceTimer = Timer(const Duration(milliseconds: 300), () {
  if (!mounted) return;
  unawaited(
    ref
        .read(publicApiProvider)
        .listBandTracks(widget.bandId, searchQuery: _searchQuery)
        .catchError((error, stackTrace) {
      // TODO: surface/report instead of silently discarding.
      return <Map<String, dynamic>>[];
    }),
  );
});
```

### WR-03: `build()` has grown to ~164 lines with deep conditional nesting, hurting reviewability

**File:** `lib/features/setlists/add_setlist_tracks_dialog.dart:136-298`

**Issue:** This phase added a `TextField`, an offline-filter branch, and a new
empty-state branch directly inline into an already-large `build()` method,
which is now ~164 lines with a 4-way `if/else if/else if/else` chain nested
inside `AlertDialog` → `SizedBox` → `AsyncValue.when` → `Column`. This is past
the point where changes to one branch (e.g. the next empty-state tweak) are
easy to reason about in isolation, and increases the risk of the kind of
priority-ordering mistakes described in WR-01 (e.g. an "offline + at cap"
combination silently falling into the wrong branch) going unnoticed in review.

**Fix:** Extract the track-list body (the `Column` with the search field,
empty-state branches, and `ListView.builder`) into a private helper method or
a separate stateless widget that takes `tracks`, `isOnline`, `_searchQuery`,
`_selectedTrackIds`, and the remaining-slots count as parameters. No behavior
change required — pure extraction for readability.

## Info

### IN-01: `addSetlistTracks`'s doc comment claims a `'204'` response; `publicapi.yml` specifies `'200'`

**File:** `lib/api/public_api.dart:377-391` (doc comment), cross-referenced against `lib/api/publicapi.yml:551-555`

**Issue:** Pre-existing (not touched by this phase's diff, but encountered
while reading the full file per standard-depth scope). The doc comment says:

> `'204'` no content.

but `publicapi.yml`'s `AddSetlistTracks` operation declares:

```yaml
      responses:
        '200':
          description: Success
        '400':
          $ref: '#/components/responses/BadRequest'
```

This is functionally harmless today — `ApiClient.send()` decides whether to
return `null` based on `response.body.isEmpty`, not `statusCode`, and
`addSetlistTracks()` doesn't use the return value — but the incorrect status
code in the doc comment is misleading for future readers cross-referencing the
spec.

**Fix:** Update the doc comment to say `'200'` (no content schema) to match
`publicapi.yml`, or update `publicapi.yml` to `'204'` if that's the actual
intended contract — whichever matches the real backend response, then keep
them in sync.

### IN-02: No test exercises "select a track offline, then narrow the search so it's hidden, then submit" — verifies the selection isn't silently dropped by filtering

**File:** `test/features/setlists/add_setlist_tracks_dialog_test.dart`

**Issue:** `_submit()` reads directly from `_selectedTrackIds` (unaffected by
the currently-visible/filtered list), which is correct — but there's no test
asserting this. `addTracksWithSearchActive` (line 557) only covers the
*online* case, where the visible list is never filtered in the first place, so
it can't catch a regression where a future change accidentally intersects the
selection with the filtered/visible list before submit.

**Fix:** Add an offline variant: seed two tracks, select one, enter a search
query that filters the *other* (unselected) track out of view, submit, and
assert `addSetlistTracks` was still called with the originally-selected
`trackId` — proving hidden-but-selected tracks survive submission.

---

_Reviewed: 2026-08-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
