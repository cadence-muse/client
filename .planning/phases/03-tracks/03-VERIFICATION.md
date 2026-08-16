---
phase: 03-tracks
verified: 2026-08-16T15:30:00Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/6
  gaps_closed:
    - "A band member can edit a track's info (title/artist/duration/tempo/key/notes) and have the changes persist (CR-01 + CR-02)"
    - "After a successful track mutation, changes made from the per-band detail/list screens are visible in the global cross-band Tracks tab (CR-03)"
    - "The global Tracks tab shows affordances for navigation that work when activated (WR-01)"
  gaps_remaining: []
  regressions:
    - "NF-01 (new, warning-level): the CR-01 guard + CR-02 always-send-all-fields fix interact so that opening EditTrackScreen on a track whose `key` is outside the 24-value musicalKeys list and saving ANY change silently clears that key (null is now explicitly sent). Strictly better than the pre-fix crash, but it is silent data loss on the same edge case CR-01 was raised for."
human_verification:
  - test: "Against the real backend, edit a track that has Duration=200 and Notes set, clear both fields, save, then navigate away and back (and force-refresh the global Tracks tab)."
    expected: "Duration shows '—' and Notes is gone — the server honored the explicit JSON `null` as 'clear this field', not as 'no change'."
    why_human: "The CR-02 fix is proven only at the request-body level (widget test asserts the exact PUT JSON contains explicit nulls). Whether the server's merge semantics actually treat JSON `null` as a clear is an external-service contract inferred from `nullable: true` in publicapi.yml — it cannot be verified from this repo. If the server instead rejects or ignores nulls, CR-02 is not actually closed."
  - test: "Decide on NF-01: with a track whose key is a value outside lib/features/tracks/track_formatting.dart's 24-entry musicalKeys list (e.g. 'F#m(maj7)'), open Edit, change only the title, and save."
    expected: "Team decision — currently the track's key is silently wiped to null. Options: (a) accept (only this client writes keys today, so unreachable in practice), (b) append the unrecognized value as an extra dropdown item so it round-trips, (c) omit `key` from the PUT when the incoming value was unrecognized."
    why_human: "Judgment call on acceptable data loss for an interop edge case; not mechanically decidable. Reachability depends on whether any non-Cadence client will write track keys during this milestone."
notes:
  - "REQUIREMENTS.md's status table (lines 113-118) still lists TRACK-01 and TRACK-03 as 'Gaps Found'. Both were VERIFIED in the prior pass and re-verified here; the stale rows are a leftover of commit 019f08b's blanket revert, not a code gap. Orchestrator should set TRACK-01..TRACK-06 to Complete."
  - "ROADMAP.md marks Phase 3 as 'mode: mvp' but its goal is not in User Story form ('As a ..., I want to ..., so that ...'). Verified against the phase's 5 explicit Success Criteria instead, consistent with the prior pass and with Phases 1-2, which share the same convention. Flagged informationally only."
---

# Phase 03: Tracks Management Verification Report

**Phase Goal:** Band members can maintain their band's song catalog.
**Verified:** 2026-08-16T15:30:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure plan 03-04 (merge `dbd5907`)

---

## Goal Achievement

### Observable Truths

Truths are the 5 Success Criteria from ROADMAP.md Phase 3 (the roadmap contract), each checked against the code on `main` at `dbd5907` — not against SUMMARY claims.

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|--------------------|--------|----------|
| 1 | User can view the list of tracks in a band | ✓ VERIFIED | `lib/features/tracks/track_list_screen.dart` renders `trackListDataProvider(bandId)` (cache-first, `lib/providers/tracks_provider.dart:24-106`); reached from `band_detail_screen.dart:183`. Behavioral tests: `test/features/tracks/track_list_screen_test.dart` (4 tests — populated list, empty state, error+retry, navigation). |
| 2 | User can add a new track to a band (title/artist required; duration, tempo, key, notes optional) | ✓ VERIFIED | `create_track_screen.dart` → `PublicApi.createBandTrack` (`public_api.dart:127-148`, optional fields omitted when unset — correct for create, no old value to clear). Tests assert required-field validation, exact POST body, error handling, and (new) WR-02 non-numeric rejection: `test/features/tracks/create_track_screen_test.dart` (6 tests). |
| 3 | User can view a track's detail page | ✓ VERIFIED | `track_detail_screen.dart:54-100` renders title/artist/duration/tempo/key/notes from `trackDetailDataProvider`; reached from both the per-band list (`track_list_screen.dart:92`) and the global tab (`tracks_screen.dart:103`). Tests: `test/features/tracks/track_detail_screen_test.dart` (5 tests). |
| 4 | User can edit a track's info and delete a track from the band | ✓ VERIFIED | **Edit:** `edit_track_screen.dart` now (a) guards `_selectedKey` against unrecognized values (`:53-55`, CR-01) and (b) sends all 6 fields unconditionally via `updateBandTrack` (`public_api.dart:165-188`, CR-02), then patches `trackDetailDataProvider` and invalidates both list providers. Behavioral tests assert the exact PUT body including explicit `null`s (`edit_track_screen_test.dart:175-207`) and no-throw + null dropdown on an unknown key (`:96-119`). **Delete:** `confirm_delete_track_dialog.dart` calls `deleteBandTrack`, patches the per-band list via `removeFromList`, invalidates the global list, double-pops. Tests: `confirm_delete_track_dialog_test.dart` (6 tests). ⚠️ See NF-01 and human item 1. |
| 5 | User can view all tracks across every band they belong to on a global Tracks tab, optionally filtered to one band | ✓ VERIFIED | `lib/features/songs/tracks_screen.dart` mounted at `root_scaffold.dart:18` (tab index 1), watching `userTracksListDataProvider` (`tracks_provider.dart:230-301`, cache-first, filter-reactive). Filter dropdown re-fetches with `?bandId=` (`tracks_screen_test.dart:146`). All three mutation flows now guard-invalidate the global provider (CR-03), each with a call-count regression test. "View bands" empty-state CTA now switches to the Bands tab (WR-01), proven end-to-end in `test/widget_test.dart:123-181` asserting `NavigationBar.selectedIndex == 2`. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

Every truth above is behavior-dependent (state transitions, cache-invalidation invariants, navigation transitions). Each is backed by a passing behavioral test, not symbol presence — see Behavioral Spot-Checks.

---

### Gap Closure (prior VERIFICATION.md)

| Gap | Prior status | Current status | Code evidence | Test evidence |
|-----|--------------|----------------|---------------|---------------|
| **CR-01** EditTrackScreen crashes on a key outside `musicalKeys` | ✗ FAILED | ✓ CLOSED | `edit_track_screen.dart:53-55` — `musicalKeys.contains(...) ? ... : null` guard before the value reaches `DropdownButtonFormField.initialValue` (`:209`) | `edit_track_screen_test.dart:96` — builds with `key: 'F#m(maj7)'`, asserts `takeException()` is null and `dropdown.initialValue` is null |
| **CR-02** Cleared optional fields silently kept stale | ✗ FAILED | ✓ CLOSED (client side) | `public_api.dart:165-188` — all 6 fields sent unconditionally; `title`/`artist` now `required` non-nullable. Contract confirmed against `publicapi.yml:799-817` (`UpdateBandTrackRequestBody` marks durationSeconds/tempo/key/notes `nullable: true`) | `edit_track_screen_test.dart:175` — clearing Duration/Tempo/Notes produces the exact body `{"title":...,"artist":...,"durationSeconds":null,"tempo":null,"key":"C","notes":null}`. Server-side honoring of null is human item 1. |
| **CR-03** Mutations never refresh the global Tracks tab | ✗ FAILED | ✓ CLOSED | `create_track_screen.dart:81-83`, `edit_track_screen.dart:138-140`, `confirm_delete_track_dialog.dart:57-59` — each `ref.exists(userTracksListDataProvider)`-guarded `ref.invalidate(...)`. Guard is correct: prevents instantiating (and network-fetching) a global tab the user never opened | Three call-count tests (one per mutation flow) mount a real `userTracksListDataProvider` watcher and assert `/api/track/list` is re-hit after the mutation |
| **WR-01** "View bands" button was `onPressed: () {}` | ✗ FAILED | ✓ CLOSED | New `lib/providers/navigation_provider.dart` `SelectedTabIndex` notifier; `root_scaffold.dart` converted to `ConsumerWidget` reading it for both `IndexedStack.index` and `NavigationBar.selectedIndex`; `tracks_screen.dart:141-142` calls `setIndex(2)`. Index 2 = Bands confirmed against `root_scaffold.dart:16-21` and `:40-44` | `test/widget_test.dart:123` — full `CadenceApp` boot, tap Tracks tab, tap "View bands", assert `NavigationBar.selectedIndex == 2`. Plus `test/providers/navigation_provider_test.dart` |
| **WR-02** Duration/Tempo silently discarded non-numeric input | ⚠️ WARNING | ✓ CLOSED | `_wholeNumberValidator` in both `edit_track_screen.dart:73-77` and `create_track_screen.dart`, wired as the `validator` on both numeric fields; empty stays valid (fields remain optional) | `create_track_screen_test.dart:174` (Duration) and `edit_track_screen_test.dart:295` (Tempo) — assert the error renders and **no API call is made** |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/providers/tracks_provider.dart` | TrackListData / TrackDetailData / UserTracksListData / SelectedBandIdFilter | ✓ VERIFIED | 301 lines; cache-first + version-guard on all three data providers; wired to 6 screens |
| `lib/providers/navigation_provider.dart` | `SelectedTabIndex` notifier (new in 03-04) | ✓ VERIFIED | Present with `.g.dart`; imported by `root_scaffold.dart` and `tracks_screen.dart`; unit-tested |
| `lib/features/tracks/track_list_screen.dart` | Per-band track list | ✓ VERIFIED | Wired from `band_detail_screen.dart:183`; data flows from `trackListDataProvider` |
| `lib/features/tracks/create_track_screen.dart` | Track creation form | ✓ VERIFIED | Wired from FAB + empty-state; WR-02 validators + CR-03 invalidate present |
| `lib/features/tracks/track_detail_screen.dart` | Detail view + edit/delete actions | ✓ VERIFIED | Renders all 6 fields; routes to Edit and Delete |
| `lib/features/tracks/edit_track_screen.dart` | Track edit form | ✓ VERIFIED | CR-01 guard, CR-02 always-send, CR-03 invalidate, WR-02 validators all present |
| `lib/features/tracks/confirm_delete_track_dialog.dart` | Delete confirm dialog | ✓ VERIFIED | CR-03 invalidate present; per-band list patched via `removeFromList` |
| `lib/features/songs/tracks_screen.dart` | Global cross-band Tracks tab | ✓ VERIFIED | Filter dropdown + band-badge rows + working "View bands" CTA |
| `lib/navigation/root_scaffold.dart` | 4-tab shell | ✓ VERIFIED | Converted to `ConsumerWidget`; no dual source of truth for tab index |
| `lib/api/public_api.dart` | Track CRUD API methods | ✓ VERIFIED | `listBandTracks`, `getBandTrack`, `createBandTrack`, `updateBandTrack`, `deleteBandTrack`, `listUserTracks` — all match `publicapi.yml` |
| `lib/cache/cache_service.dart` | Hive-backed track cache | ✓ VERIFIED | `readBandTracks`/`writeBandTracks`, `readBandTrackDetail`/`writeBandTrackDetail`, `readUserTracks`/`writeUserTracks` |

No stubs, no orphans — every artifact is imported and exercised by at least one screen and one test.

---

## Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `BandDetailScreen` | `TrackListScreen` | "Tracks" ListTile (`band_detail_screen.dart:183`) | ✓ WIRED |
| `TrackListScreen` | `CreateTrackScreen` | FAB (`:30`) + empty-state button (`:63`) | ✓ WIRED |
| `TrackListScreen` | `TrackDetailScreen` | Row tap (`:92`) | ✓ WIRED |
| `TrackDetailScreen` | `EditTrackScreen` | AppBar edit icon (`:35`), passes full `currentTrack` | ✓ WIRED |
| `TrackDetailScreen` | `ConfirmDeleteTrackDialog` | Delete ListTile (`:97`) | ✓ WIRED |
| `TracksScreen` | `TrackDetailScreen` | Row tap with per-row `bandId` (`:103`) | ✓ WIRED |
| `EditTrackScreen` submit | `PublicApi.updateBandTrack` | PUT `/api/band/{id}/track/{id}`, all 6 fields | ✓ WIRED |
| `EditTrackScreen` submit | `trackDetailDataProvider` | `.updateFields(patch)`, `ref.exists`-guarded | ✓ WIRED |
| Create / Edit / Delete | `trackListDataProvider(bandId)` | invalidate / `removeFromList` | ✓ WIRED |
| Create / Edit / Delete | `userTracksListDataProvider` | `ref.exists`-guarded `ref.invalidate` (CR-03) | ✓ WIRED |
| `TracksScreen` "View bands" | `RootScaffold` tab index | `selectedTabIndexProvider.notifier.setIndex(2)` | ✓ WIRED |
| `TracksScreen` filter | `userTracksListDataProvider` | `selectedBandIdFilterProvider` watched in `build()` → auto-rebuild | ✓ WIRED |

---

## Data-Flow Trace (Level 4)

| Screen | Data source | Query | Real data | Status |
|--------|-------------|-------|-----------|--------|
| `TrackListScreen(bandId)` | `listBandTracks` → Hive cache | `GET /api/band/{bandId}/track/list` | Yes — cache-first + silent background refresh | ✓ FLOWING |
| `TrackDetailScreen` | `getBandTrack` → Hive cache | `GET /api/band/{bandId}/track/{trackId}` | Yes — cache-first, patched in place on edit | ✓ FLOWING |
| `TracksScreen` (global) | `listUserTracks(bandIdFilter)` → Hive cache | `GET /api/track/list[?bandId=]` | Yes — cache-first, filter-reactive, **and now invalidated on every mutation** | ✓ FLOWING (was ⚠️ FLOWING_BUT_STALE) |

No hardcoded literals, static returns, or hollow props found in any rendered value.

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite green on `main` after merge | `flutter test` (run once) | `+145: All tests passed!` | ✓ PASS |
| Static analysis clean | `flutter analyze` | 5 infos, 0 warnings/errors — 4 `use_null_aware_elements` in `createBandTrack`'s intentional conditional guards, 1 `prefer_final_fields` on `UserTracksListData._version` | ✓ PASS |
| Gap-closure commits on `main` | `git log --oneline` | `5442431`, `687657b`, `93cae88`, `c611a34`, `8e44655`, merge `dbd5907` all present | ✓ PASS |
| CR-01 regression test exists and passes | named test in `edit_track_screen_test.dart` | pass (in suite run) | ✓ PASS |
| CR-02 exact-PUT-body test | named test in `edit_track_screen_test.dart` | pass — asserts explicit nulls | ✓ PASS |
| CR-03 refetch-count tests (×3) | create / edit / delete test files | pass | ✓ PASS |
| WR-01 end-to-end tab switch | `widget_test.dart` | pass — `selectedIndex == 2` | ✓ PASS |
| WR-02 validator tests (×2) | create + edit test files | pass — no API call on invalid input | ✓ PASS |

Probe execution: SKIPPED — this project has no `scripts/*/tests/probe-*.sh` convention; `flutter test` is the verification driver and was run once here.

---

## Requirements Coverage

| Requirement | Source plan | Status | Evidence |
|-------------|-------------|--------|----------|
| **TRACK-01** view list of tracks in a band | 03-01 | ✓ SATISFIED | Truth 1 |
| **TRACK-02** add a track (title/artist required; rest optional) | 03-01, 03-04 | ✓ SATISFIED | Truth 2 + WR-02 closure |
| **TRACK-03** view track detail | 03-01 | ✓ SATISFIED | Truth 3 |
| **TRACK-04** edit a track's info | 03-02, 03-04 | ✓ SATISFIED (was BLOCKED) | Truth 4 — CR-01 + CR-02 closed; server-null semantics pending human item 1 |
| **TRACK-05** delete a track from a band | 03-02 | ✓ SATISFIED | Truth 4 (delete half) |
| **TRACK-06** global cross-band Tracks tab, filterable | 03-03, 03-04 | ✓ SATISFIED (was BLOCKED) | Truth 5 — CR-03 + WR-01 closed |

No orphaned requirements: REQUIREMENTS.md maps exactly TRACK-01..TRACK-06 to Phase 3, and all six are claimed across the four plans.

**Bookkeeping:** REQUIREMENTS.md lines 113-118 still show TRACK-01 and TRACK-03 as `Gaps Found`. Both were VERIFIED in the prior pass and again here — the stale rows are collateral from commit `019f08b`'s blanket revert. All six should read `Complete`.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/tracks/edit_track_screen.dart` | 53-55, 91, 105 | CR-01 null-guard combined with CR-02 always-send: an unrecognized incoming `key` becomes `null` in the form and is then explicitly sent as `null` on save | ⚠️ WARNING (NF-01) | Editing *anything* on a track whose key is outside the 24-value list silently wipes that key. Strictly better than the prior crash, but it is silent data loss on precisely the edge case CR-01 was raised for. Unreachable while this Flutter client is the only writer of `key`. See human item 2. |
| `lib/providers/tracks_provider.dart` | 238 | `UserTracksListData._version` is declared and captured but never incremented (no local-mutation method on this notifier) | ℹ️ INFO | Dead guard — harmless, but `prefer_final_fields` flags it. The version-guard machinery is copy-pasted from `TrackListData`, which does mutate. |
| `lib/api/public_api.dart` | 142-145 | `if (x != null) 'x': x` conditional guards in `createBandTrack` | ℹ️ INFO | Intentional and documented (no old value to clear on create); flagged only by the `use_null_aware_elements` lint. Pre-existing. |

No `TODO` / `FIXME` / `XXX` / `TBD` / `HACK` / `PLACEHOLDER` markers, no no-op handlers, and no hardcoded-empty render values anywhere in `lib/features/tracks/`, `lib/features/songs/`, `lib/providers/tracks_provider.dart`, `lib/providers/navigation_provider.dart`, or `lib/navigation/root_scaffold.dart`.

---

## Human Verification Required

### 1. Server honors explicit JSON `null` as "clear this field"

**Test:** Against the real backend, edit a track that has Duration=200 and Notes set. Clear both fields, save, navigate away and back, and force-refresh the global Tracks tab.
**Expected:** Duration shows `—` and Notes is gone.
**Why human:** The CR-02 fix is proven only at the request-body level — the widget test asserts the exact PUT JSON contains explicit `null`s. Whether the server's merge semantics treat JSON `null` as a clear (rather than ignoring or rejecting it) is an external-service contract inferred from `nullable: true` in `publicapi.yml:806-817`. It cannot be verified from this repo. If the server ignores nulls, CR-02 is not actually closed and TRACK-04 regresses.

### 2. Decide on NF-01 — silent key wipe on unrecognized key values

**Test:** With a track whose `key` is outside `lib/features/tracks/track_formatting.dart`'s 24-entry `musicalKeys` list (e.g. `F#m(maj7)`), open Edit, change only the title, and save.
**Expected:** Team decision. Current behavior silently clears the key. Options: (a) accept — only this client writes keys today, so it is unreachable in practice; (b) append the unrecognized value as an extra dropdown item so it round-trips (this was the alternative the prior report suggested for CR-01); (c) omit `key` from the PUT when the incoming value was unrecognized.
**Why human:** Judgment call on acceptable data loss for an interop edge case. Reachability depends on whether a non-Cadence client will write track keys during this milestone — a product/backend question, not a code question.

---

## Deferred Items

None. No Phase 3 concern is addressed by Phase 4 (Setlists) or Phase 5 (Offline Trust & Connectivity UX). NF-01 is not deferred — it is a live warning awaiting a decision, not scheduled work.

---

## Gaps Summary

**No blocking gaps.** All 5 ROADMAP Success Criteria are verified against the codebase with passing behavioral tests, and all 5 previously-reported gaps (CR-01, CR-02, CR-03, WR-01, WR-02) are closed in code with dedicated regression tests that assert the actual fixed behavior — not merely that the files changed.

Two items keep this short of an unconditional `passed`:

1. The CR-02 fix's correctness ultimately depends on server-side merge semantics that no client-side test can prove. The client now provably sends the right bytes; whether the server does the right thing with them needs one manual check.
2. NF-01, a new warning-level interaction between the CR-01 and CR-02 fixes, produces silent data loss on tracks with non-standard key values. It does not block any Success Criterion and is an improvement over the pre-fix crash, but it deserves an explicit accept-or-fix decision rather than being absorbed silently into a green verdict.

Both are recorded as human-verification items per the Step 9 decision tree (rule 2 applies; rule 1 does not fire).

---

_Verified: 2026-08-16T15:30:00Z_
_Verifier: Claude (gsd-verifier)_
