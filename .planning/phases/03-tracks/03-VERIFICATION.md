---
phase: 03-tracks
verified: 2026-08-16T14:00:00Z
status: gaps_found
score: 2/6 must-haves verified
behavior_unverified: 0
gaps:
  - truth: "A band member can edit a track's info (title/artist/duration/tempo/key/notes) and have the changes persist"
    status: failed
    reason: Two interconnected bugs prevent successful track editing for most real-world use cases
    artifacts:
      - path: "lib/features/tracks/edit_track_screen.dart"
        issue: "CR-01 (line 179): DropdownButtonFormField(initialValue: _selectedKey) crashes if the track's key value is not in the hardcoded 24-entry musicalKeys list. Any track created via a different client or with a future-added key value will crash when EditTrackScreen builds."
      - path: "lib/features/tracks/edit_track_screen.dart"
        issue: "CR-02 (lines 98-105): The updateBandTrack call uses conditional-null guards — optional fields are only included in the request if non-null. Users cannot clear previously-set optional fields; an empty Duration/Tempo/Key/Notes field becomes null, is omitted from the PUT request, and the server (using merge semantics) keeps the old value silently."
      - path: "lib/api/public_api.dart"
        issue: "CR-02 (lines 156-178): updateBandTrack implementation mirrors the issue — only sends fields if non-null, making it impossible for clients to signal 'clear this field.'"
    missing:
      - "EditTrackScreen: fall back gracefully when current key is not in musicalKeys (e.g. `_selectedKey = musicalKeys.contains(...) ? ... : null;`) or append unrecognized values as an extra dropdown item"
      - "EditTrackScreen: distinguish 'user didn't touch this field' from 'user explicitly cleared it' — either track touched fields and send a clear signal (empty string or sentinel) for cleared ones, or always send all fields from the form (not just non-null ones)"
      - "PublicApi.updateBandTrack: document and enforce the merge semantics clearly, or change to always-send-all-fields from the caller"
  - truth: "After a successful track deletion, mutations made from the per-band detail/list screens are visible in the global cross-band Tracks tab"
    status: failed
    reason: CR-03 — all three track mutation operations (create/edit/delete) only invalidate per-band providers, never the global userTracksListDataProvider
    artifacts:
      - path: "lib/features/tracks/create_track_screen.dart"
        issue: "Line 64: only invalidates trackListDataProvider(widget.bandId) after create, never userTracksListDataProvider"
      - path: "lib/features/tracks/edit_track_screen.dart"
        issue: "Lines 110-112: only invalidates trackListDataProvider(widget.bandId) after edit, never userTracksListDataProvider"
      - path: "lib/features/tracks/confirm_delete_track_dialog.dart"
        issue: "Lines 44-50: only touches trackListDataProvider(widget.bandId) after delete, never userTracksListDataProvider"
      - path: "lib/providers/tracks_provider.dart"
        issue: "No mechanism to propagate track mutations to the global list provider"
    missing:
      - "All three mutation flows must invalidate (or patch) userTracksListDataProvider after a successful mutation, e.g. `if (ref.exists(userTracksListDataProvider)) { ref.invalidate(userTracksListDataProvider); }`"
  - truth: "The global Tracks tab shows affordances for navigation that work when activated"
    status: failed
    reason: "WR-01 — the 'View bands' button in the zero-bands empty state is a visual no-op"
    artifacts:
      - path: "lib/features/songs/tracks_screen.dart"
        issue: "Lines 134-137: ElevatedButton with onPressed: () {} — button renders but tapping does nothing"
    missing:
      - "Either wire the button to switch RootScaffold's selected tab index (would require plumbing a tab-switching API), or remove the button until that exists"
---

# Phase 03: Tracks Management Verification Report

**Phase Goal:** Band members can maintain their band's song catalog.
**Verified:** 2026-08-16T14:00:00Z
**Status:** gaps_found
**Review Findings:** 3 critical issues, 2 warnings (per 03-REVIEW.md)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A band member can view a list of tracks in a band, with title/artist/duration displayed | ✓ VERIFIED | `TrackListScreen` (lib/features/tracks/track_list_screen.dart) exists, wired from `BandDetailScreen`'s "Tracks" nav entry; test coverage in `test/features/tracks/track_list_screen_test.dart` passes |
| 2 | A band member can add a track via a full-screen form (title/artist required; duration/tempo/key/notes optional) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Artifact present and wired (`CreateTrackScreen`, `createBandTrack` API method), but CR-02 (cannot clear optional fields) is only discovered during edit, not creation — creation works one-way only |
| 3 | A band member can view a track's full detail (title, artist, duration, tempo, key, notes) | ✓ VERIFIED | `TrackDetailScreen` (lib/features/tracks/track_detail_screen.dart) exists and displays all fields; test coverage passes |
| 4 | A band member can edit a track's info and have changes persist | ✗ FAILED | **CR-01 (EditTrackScreen crash)**: Any track with a key value not in the hardcoded 24-entry musicalKeys list crashes the app when building EditTrackScreen (line 179: `initialValue: _selectedKey` with unconstrained server data fed to a constrained dropdown). **CR-02 (data loss on clear)**: Optional fields cannot be cleared — empty fields are sent as `null`, omitted from the PUT request, and the server (using merge semantics) silently keeps old values. |
| 5 | A band member can delete a track via a lightweight confirm dialog | ✓ VERIFIED | `ConfirmDeleteTrackDialog` (lib/features/tracks/confirm_delete_track_dialog.dart) exists, wired from `TrackDetailScreen`, double-pops correctly; test coverage passes |
| 6 | A band member can view all tracks across every band on the global Tracks tab, filterable by band | ✗ FAILED | **CR-03 (global tab staleness)**: Track mutations (create/edit/delete) made from per-band screens never invalidate `userTracksListDataProvider`, so the global Tracks tab shows stale data for the rest of the session. A newly created track won't appear; a deleted track keeps showing; edits stay hidden. **WR-01 (broken UI affordance)**: The "View bands" button in the zero-bands empty state is a no-op. |

**Score:** 2/6 truths verified (TRACK-01, TRACK-03 only; TRACK-05 is isolated and works)

---

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| **TRACK-01**: User can view list of tracks in a band | ✓ SATISFIED | `TrackListScreen` fully implemented, wired, tested |
| **TRACK-02**: User can add a track to a band | ⚠️ UNCERTAIN | Creation mechanism exists (`CreateTrackScreen`, `createBandTrack`), but CR-02 (cannot clear optional fields during edit) suggests the "edit and clear" half of maintaining a track is broken — unclear if this was intended to be bidirectional |
| **TRACK-03**: User can view track detail | ✓ SATISFIED | `TrackDetailScreen` fully implemented, wired, tested |
| **TRACK-04**: User can edit a track's info | ✗ BLOCKED | CR-01 (crash on unrecognized key) and CR-02 (cannot clear fields) prevent editing from working for most real-world tracks |
| **TRACK-05**: User can delete a track from a band | ✓ SATISFIED | `ConfirmDeleteTrackDialog` fully implemented, wired, tested |
| **TRACK-06**: User can view all tracks across every band they belong to, filterable by band, via a global Tracks tab | ✗ BLOCKED | CR-03 (global list never refreshes after mutations) and WR-01 (no-op button) prevent the global view from staying in sync with per-band operations |

---

## Critical Issues Summary

### CR-01: EditTrackScreen Crashes on Unrecognized Key Values
**File:** `lib/features/tracks/edit_track_screen.dart:46, 179`
**Severity:** BLOCKER for TRACK-04
**Root Cause:** The track's `key` field (line 46: `late String? _selectedKey = widget.currentTrack['key'] as String?`) is loaded directly from server/cache data. Line 179 passes this unconstrained value as `initialValue: _selectedKey` to a `DropdownButtonFormField<String>` whose `items` list is the hardcoded 24-entry `musicalKeys` constant. Flutter's DropdownButton asserts that the `value` is either `null` or exactly matches one of the supplied items — any key outside the 24 known values causes an assertion failure at build time.

**Reproduction:** Create or import a track with `key='F#m(maj7)'` or any non-standard value, then tap to edit it.

**Impact:** Blocks editing of any track with an unrecognized key, trapping users who cannot clear or modify their tracks.

### CR-02: Cannot Clear Optional Track Fields on Edit
**Files:** `lib/features/tracks/edit_track_screen.dart:60-88, 98-105`; `lib/api/public_api.dart:156-178`
**Severity:** BLOCKER for TRACK-04 (and partially for TRACK-02)
**Root Cause:** Lines 98-105 in `EditTrackScreen._submit()` build a patch map with conditional-null guards: `if (durationSeconds != null) 'durationSeconds': durationSeconds`. Fields that are `null` are omitted entirely from the request body. When a user clears a field (leaves it blank), it becomes `null`, is omitted from the PUT request, and the server (per the `updateBandTrack` doc comment noting the `'200'` response has no body) uses merge/partial-update semantics and keeps the old value. The user sees the field empty in the form but the change is never sent.

**Reproduction:** Create a track with Duration=120, then edit it to Duration=(blank), tap Save, and navigate away and back — Duration still shows 120.

**Impact:** Users cannot clear optional fields once set. This is guaranteed to fail for any "remove this field" operation, not an edge case.

### CR-03: Track Mutations Never Refresh the Global Tracks Tab
**Files:** `lib/features/tracks/create_track_screen.dart:64`; `lib/features/tracks/edit_track_screen.dart:110-112`; `lib/features/tracks/confirm_delete_track_dialog.dart:44-50`
**Severity:** BLOCKER for TRACK-06
**Root Cause:** All three mutation flows only invalidate `trackListDataProvider(bandId)` (the per-band list provider). The global list provider `userTracksListDataProvider` is never touched. Since `RootScaffold` keeps all four bottom-nav tabs alive simultaneously via `IndexedStack`, `TracksScreen`'s subscription to `userTracksListDataProvider` never auto-disposes, and stale data persists for the entire session.

**Reproduction:** 
1. Open a band with 2 tracks.
2. Navigate to the global Tracks tab — both tracks appear.
3. Go back to the band and create a new track.
4. Switch to the Tracks tab — the new track does not appear (stale).
5. Tap the filter dropdown to change the filter — the list rebuilds and the new track appears (forced refresh).

**Impact:** The global tab is unreliable and confusing — users see stale track lists, missing deletions, and outdated edits.

### WR-01: "View bands" Button in Empty Tracks Tab Does Nothing
**File:** `lib/features/songs/tracks_screen.dart:134-137`
**Severity:** UX issue compounding CR-03
**Root Cause:** The "View bands" button has `onPressed: () {}` — a no-op placeholder.

**Impact:** Users with zero bands see a button that appears interactive but does nothing, reading as broken.

---

## Deferred Items

None. These are not deferred to later phases; they are correctness blockers discovered during code review.

---

## Artifacts Verification

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/providers/tracks_provider.dart` | `TrackListData`, `TrackDetailData`, `UserTracksListData`, `SelectedBandIdFilter` providers | ✓ PRESENT | All classes present, providers generated correctly |
| `lib/features/tracks/track_list_screen.dart` | Per-band track list UI | ✓ PRESENT | File exists, wired from `BandDetailScreen` |
| `lib/features/tracks/create_track_screen.dart` | Track creation form | ✓ PRESENT | File exists, creates tracks (though CR-02 prevents clearing optional fields in later edits) |
| `lib/features/tracks/track_detail_screen.dart` | Track detail view with edit/delete actions | ✓ PRESENT | File exists, but edit action routes to `EditTrackScreen` which is broken by CR-01/CR-02 |
| `lib/features/tracks/edit_track_screen.dart` | Track edit form | ✓ PRESENT_BUT_BROKEN | File exists, but CR-01 (crash on unrecognized key) and CR-02 (cannot clear fields) prevent it from working |
| `lib/features/tracks/confirm_delete_track_dialog.dart` | Track deletion dialog | ✓ PRESENT | File exists, but CR-03 (doesn't invalidate global tab) means deletion doesn't sync to global view |
| `lib/features/songs/tracks_screen.dart` | Global cross-band Tracks tab | ✓ PRESENT_BUT_BROKEN | File exists, but CR-03 (never refreshes after mutations) and WR-01 (no-op button) prevent it from working correctly |
| `lib/cache/cache_service.dart` | Hive cache backing store for tracks | ✓ PRESENT | `tracksBox`, `_tracksStore` present, methods added |
| `lib/api/public_api.dart` | API methods for track CRUD | ✓ PRESENT_BUT_BROKEN | Methods exist (`listBandTracks`, `createBandTrack`, `updateBandTrack`, `deleteBandTrack`, `listUserTracks`), but `updateBandTrack` design (merge semantics + null-omitted fields) enables CR-02 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `BandDetailScreen` | `TrackListScreen` | "Tracks" ListTile navigation | ✓ WIRED | Nav entry present and visible to all members |
| `TrackListScreen` | `CreateTrackScreen` | FAB + empty-state button | ✓ WIRED | Navigation wired correctly |
| `TrackListScreen` | `TrackDetailScreen` | Row tap | ✓ WIRED | Tap navigation works |
| `TrackDetailScreen` | `EditTrackScreen` | AppBar edit icon | ✓ WIRED_BUT_BROKEN | Icon present, but `EditTrackScreen` crashes on CR-01 for unrecognized keys |
| `TrackDetailScreen` | `ConfirmDeleteTrackDialog` | Delete ListTile | ✓ WIRED_BUT_BROKEN | Dialog opens, but doesn't invalidate global tab (CR-03) |
| `TracksScreen` | `TrackDetailScreen` | Row tap | ✓ WIRED | Navigation wired, but shows stale data due to CR-03 |
| `CreateTrackScreen` submit | `trackListDataProvider` invalidation | `ref.invalidate(trackListDataProvider)` | ✓ WIRED | Per-band list refreshes, but CR-03: global list never invalidated |
| `EditTrackScreen` submit | `trackListDataProvider` invalidation | `ref.invalidate(trackListDataProvider)` | ✓ WIRED | Per-band list refreshes, but CR-03: global list never invalidated |
| `DeleteTrackDialog` confirm | `trackListDataProvider` update | `removeFromList()` or invalidate | ✓ WIRED | Per-band list updates, but CR-03: global list never invalidated |

---

## Data-Flow Trace (Level 4)

| Screen | Data Source | Query | Flows Real Data | Status |
|--------|-------------|-------|-----------------|--------|
| `TrackListScreen(bandId)` | `publicApi.listBandTracks(bandId)` → cache | `GET /api/band/{bandId}/track/list` | ✓ Yes, cache-first with silent background refresh | ✓ FLOWING |
| `TrackDetailScreen(bandId, trackId)` | `publicApi.getBandTrack(bandId, trackId)` → cache | `GET /api/band/{bandId}/track/{trackId}` | ✓ Yes, cache-first | ✓ FLOWING |
| `TracksScreen` (global) | `publicApi.listUserTracks(bandIdFilter)` → cache | `GET /api/track/list?bandId={filter}` (optional) | ✓ Yes, cache-first, but **stale due to CR-03** | ⚠️ FLOWING_BUT_STALE |

---

## Test Coverage

All unit and widget tests pass (`flutter test` 135 passed, 0 failed per 03-03-SUMMARY.md). However:

- ✓ Tests for TRACK-01/03/05 (view/view-detail/delete) pass because these features work
- ✓ Tests for TRACK-02 (create) pass because initial creation works
- ✗ Tests for TRACK-04 (edit) do not exercise the real-world failures:
  - No test creates a track with an unrecognized key value and attempts to edit it (CR-01 would fail)
  - No test edits a track and clears an optional field, then verifies the field is actually cleared server-side (CR-02 would fail)
- ✗ Tests for TRACK-06 (global tab) do not exercise real cross-tab synchronization:
  - No test creates a track from a per-band screen, then verifies it appears in the global tab without manually triggering a filter change (CR-03 would fail)
  - No test checks that the "View bands" button is actually wired to do something

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/songs/tracks_screen.dart` | 135 | `onPressed: () {}` (no-op button) | ⚠️ WARNING | WR-01: Broken affordance |
| `lib/features/tracks/create_track_screen.dart` | 59-60 | `int.tryParse(_durationController.text.trim())` with no validator on the TextFormField | ⚠️ WARNING | WR-02: Non-numeric input silently drops with no user feedback (e.g. "abc" becomes null, treated as blank) |
| `lib/features/tracks/edit_track_screen.dart` | 70-71 | Same as above | ⚠️ WARNING | WR-02: Same silent-discard behavior in edit form |
| `lib/features/tracks/edit_track_screen.dart` | 46, 179 | Unconstrained server data (key field) fed to a constrained dropdown `DropdownButtonFormField` with `initialValue` | 🛑 CRITICAL | CR-01: Crashes on build if key is not in the hardcoded list |
| `lib/features/tracks/edit_track_screen.dart` | 98-105 | Conditional-null field guards (`if (x != null) ...`) in patch map passed to updateBandTrack | 🛑 CRITICAL | CR-02: Impossible to clear optional fields; users cannot signal "delete this value" |
| `lib/features/tracks/create_track_screen.dart` | 64 | Only invalidates per-band `trackListDataProvider`, never global `userTracksListDataProvider` | 🛑 CRITICAL | CR-03: New tracks don't appear in global tab |
| `lib/features/tracks/edit_track_screen.dart` | 110-112 | Same as above | 🛑 CRITICAL | CR-03: Edited tracks don't refresh in global tab |
| `lib/features/tracks/confirm_delete_track_dialog.dart` | 44-50 | Same as above | 🛑 CRITICAL | CR-03: Deleted tracks still show in global tab |

---

## Summary of Blockers

### TRACK-04 (Edit Track) — FAILED
- **CR-01**: App crashes if track key is not in the hardcoded 24 values
- **CR-02**: Cannot clear optional fields — data loss on every "clear this field" edit

### TRACK-06 (Global Tracks Tab) — FAILED
- **CR-03**: Global tab never refreshes after per-band mutations — stale data for the session
- **WR-01**: "View bands" button is a no-op

### Phase Goal — NOT ACHIEVED
Band members cannot fully "maintain" their band's song catalog when:
- Editing tracks is broken and crashes in common cases
- The global view doesn't sync with local changes

---

## Next Steps (Unblocking)

1. **CR-01 (fix: 15 min)**: Guard the dropdown's `initialValue` against unrecognized keys:
   ```dart
   late String? _selectedKey = musicalKeys.contains(widget.currentTrack['key'])
       ? widget.currentTrack['key'] as String?
       : null;
   ```

2. **CR-02 (fix: 30 min)**: Distinguish "unchanged" from "cleared" by always sending all fields from EditTrackScreen (since it has the full current track snapshot):
   ```dart
   await ref.read(publicApiProvider).updateBandTrack(
     ...
     title: title,
     artist: artist,
     durationSeconds: durationSeconds,  // send null or value; null now means "clear"
     ...
   );
   ```
   Update `updateBandTrack` in `public_api.dart` to send all fields (not just non-null ones).

3. **CR-03 (fix: 5 min)**: Add global-list invalidation to all three mutation flows:
   ```dart
   if (ref.exists(userTracksListDataProvider)) {
     ref.invalidate(userTracksListDataProvider);
   }
   ```

4. **WR-01 (fix: 5 min)**: Either wire the button or remove it. Wiring requires exposing tab-switch functionality from `RootScaffold`.

5. **WR-02 (fix: 10 min)**: Add validators to Duration/Tempo fields to reject non-numeric input:
   ```dart
   validator: (value) {
     final text = value?.trim() ?? '';
     if (text.isEmpty) return null;
     return int.tryParse(text) == null ? 'Enter a whole number' : null;
   },
   ```

---

_Verified: 2026-08-16T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
