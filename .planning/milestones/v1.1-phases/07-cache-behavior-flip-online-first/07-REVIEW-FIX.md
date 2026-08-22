---
phase: 07-cache-behavior-flip-online-first
fixed_at: 2026-08-22T08:26:52Z
review_path: .planning/phases/07-cache-behavior-flip-online-first/07-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 07: Code Review Fix Report

**Fixed at:** 2026-08-22T08:26:52Z
**Source review:** .planning/phases/07-cache-behavior-flip-online-first/07-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (critical + warning): 5
- Fixed: 4
- Skipped: 1

**Verification environment:** all fixes were edited and verified inside an isolated git
worktree (`.claude/worktrees/rf-07-44589-1787386242`, branch `gsd-reviewfix/07-44589`), then
fast-forward-merged onto `main`. `dart analyze` was run per-file immediately after each edit
(all clean); the full `flutter test` suite (422 tests) was run once after all fixes were
applied and passed. These numbers are reproducible from the `main` branch after the
worktree/branch cleanup below, since the isolated worktree shared full git history with
`main` and its commits were fast-forwarded in.

## Fixed Issues

### CR-01: WR-02's local-mutation protection guards in-memory state but not the persisted cache — a stale background refresh can silently revert the on-disk cache

**Files modified:** `lib/providers/tracks_provider.dart`, `lib/providers/setlists_provider.dart`, `lib/providers/bands_provider.dart`, `test/providers/tracks_provider_test.dart`
**Commit:** `87db766`
**Applied fix:** Restructured every `_doRefresh()` (`TrackListData`, `TrackDetailData`, `SetlistListData`, `SetlistDetailData`, `BandsListData`, `BandDetailData`) to inline its own fetch instead of calling the shared `_fetchAndCache()` helper, and to check `_version` **before** writing to the cache — a stale response (superseded by a local mutation while the fetch was in flight) is now discarded entirely, including its cache write and `syncedAt` bump, instead of only skipping the `state` assignment. Updated `BandsListSyncedAt`'s doc comment (previously documented the *opposite*, pre-fix behavior as intentional) to reflect the corrected invariant. Added cache-read assertions (`cacheService.readBandTracks`/`readBandTrackDetail`) to the existing WR-02 regression tests in `tracks_provider_test.dart` for both the list and detail provider shapes, proving the persisted cache now matches the in-memory `state` after the race. Verified via `dart analyze` (clean) and `flutter test test/providers/tracks_provider_test.dart test/providers/setlists_provider_test.dart test/providers/bands_provider_test.dart test/providers/band_detail_provider_test.dart` (all passing, including the new assertions).

### CR-02: Stale band-filter selection crashes `DropdownButton` on `TracksScreen`/`SetlistsScreen` after the filtered band disappears from the bands list

**Files modified:** `lib/features/songs/tracks_screen.dart`, `lib/features/setlists/setlists_screen.dart`, `test/features/tracks/tracks_screen_test.dart`, `test/features/setlists/setlists_screen_test.dart`
**Commit:** `aea2cca`
**Applied fix:** In both `_buildFilterDropdown` methods, compute `effectiveBandId` by clamping the persisted filter (`selectedBandIdFilterProvider`/`selectedSetlistBandIdFilterProvider`) to `null` whenever it no longer matches any id in the current `bands` list, and feed that clamped value into `DropdownButton.value` instead of the raw provider value. The persisted filter provider itself is left untouched (so it "sticks" if the band reappears), only the rendered dropdown value is defended. Added a regression widgetTest to each screen's test file that selects a band, then invalidates `bandsListDataProvider` with that band removed from the response, and asserts the dropdown falls back to `null` ("All bands") without `pumpAndSettle` rethrowing the `DropdownButton` assertion. Verified via `dart analyze` (clean) and `flutter test test/features/tracks/tracks_screen_test.dart test/features/setlists/setlists_screen_test.dart` (18 tests, all passing).

### WR-01: `refresh()`'s in-flight dedup can silently swallow a follow-up refetch triggered by a second, independent mutation

**Files modified:** `lib/providers/setlists_provider.dart`, `lib/features/setlists/setlist_detail_screen.dart`, `test/providers/setlists_provider_test.dart`
**Commit:** `8acf589`
**Applied fix:** Added an optional `force` parameter to `SetlistListData.refresh()`/`SetlistDetailData.refresh()`. Plain UI-triggered refreshes (no `force`) keep the original in-flight dedup behavior exactly as before, so "tap refresh twice quickly" still collapses into one network call (verified against the pre-existing "two rapid refresh() calls" tests, which pass unchanged). `force: true` — now used by `SetlistDetailScreen._removeTrack`'s post-mutation resync calls — queues one more `_doRefresh()` run via a `_refreshPending` flag if a refresh is already in flight when it's requested, so a forced caller's `await` is guaranteed a fetch that started no earlier than its own call, instead of resolving against a stale in-flight response. Added a provider-level regression test simulating two forced `refresh()` calls racing an in-flight fetch, asserting the second call is not silently absorbed and the final state reflects the up-to-date server response. Verified via `dart analyze` (clean) and `flutter test test/providers/setlists_provider_test.dart test/features/setlists/setlist_detail_screen_test.dart` (77 tests, all passing).

### WR-02: `syncedAt` is bumped even when the paired cache write silently failed

**Files modified:** `lib/cache/cache_service.dart`, `lib/providers/tracks_provider.dart`, `lib/providers/setlists_provider.dart`, `lib/providers/bands_provider.dart`, `lib/providers/homepage_provider.dart`, `lib/providers/profile_provider.dart`, `test/providers/auth_provider_test.dart`
**Commit:** `e692025`
**Applied fix:** Changed all 10 `CacheService.writeX` methods to return `Future<bool>` (`true` on a confirmed write, `false` if the write threw and was swallowed) instead of `Future<void>`. Updated every call site across the five provider files (`_fetchAndCache`/inlined `_doRefresh` fetch paths and every local-mutation method: `removeFromList`, `updateFields`, `reorderTracks`, `renameBand`, `patchBandOwner`, `updateName`, `rotateInviteCode`) to only bump the paired `XSyncedAt` provider when the write returned `true`. Fire-and-forget (`unawaited`) call sites were changed to chain a `.then((wrote) { if (wrote) ...})` continuation so the syncedAt bump stays conditional without blocking the caller. Updated the `_FakeCacheService` test double in `test/providers/auth_provider_test.dart` (the only other `CacheService` implementer in the codebase) to match the new `Future<bool>` signatures. Verified via `dart analyze lib/ test/` (clean, zero issues across the whole codebase) and the full `flutter test` suite (422 tests, all passing) — confirming the return-type change didn't break any existing call site or test double. No dedicated fault-injection regression test was added: `CacheService.inMemory()`'s backing `_InMemoryStore.put()` never throws, so reproducing a write failure would require adding a new fault-injectable test double to `cache_service.dart`'s public surface, which is a larger change than this finding's fix warranted; the fix's correctness instead rests on the exhaustive full-suite pass plus the mechanical, symmetric nature of the `wrote ? bump : skip` pattern applied identically at all 15+ call sites.

## Skipped Issues

### WR-03: The entire `XSyncedAt` provider family is defined, tested, and continuously updated but never consumed by any screen

**File:** `lib/providers/bands_provider.dart`, `lib/providers/tracks_provider.dart`, `lib/providers/setlists_provider.dart`, `lib/providers/homepage_provider.dart`, `lib/providers/profile_provider.dart`
**Reason:** The finding's own Fix section offers two divergent remediations of substantially different scope: (1) design and build a new "last synced" UI indicator wired into 7+ screens (a net-new feature, not a bug fix), or (2) delete all 10 `XSyncedAt` provider classes plus every `.set(...)` call site across the 5 provider files this fixer just extensively touched for WR-02 (whose fix depends on those exact call sites), plus their dedicated tests. Neither is a narrowly-scoped, low-risk automated fix: option 1 requires product/UI design judgment this agent isn't positioned to make unilaterally, and option 2 is a wide-blast-radius deletion that would directly conflict with and partially undo the WR-02 commit (`e692025`) made moments earlier in this same run. Re-verified the finding is still accurate post-fix (`grep -rln "SyncedAtProvider" lib/features/` still returns nothing; all 10 provider classes still exist with no consumer). Left for human decision — recommend discussing with the user whether to build the "last synced" UI or remove the dead surface area before the phase is considered fully clean.
**Original issue:** `BandsListSyncedAt`, `BandDetailSyncedAt`, `TrackListSyncedAt`, `TrackDetailSyncedAt`, `UserTracksSyncedAt`, `SetlistListSyncedAt`, `SetlistDetailSyncedAt`, `UserSetlistsSyncedAt`, `HomepageSyncedAt`, and `ProfileSyncedAt` are ten separate notifier classes, each `.set(...)` on every fetch/mutation across all six data providers — but no screen in `lib/` ever `watch`es or `read`s any of them. They exist only as tested, maintained infrastructure with no UI consumer.

---

_Fixed: 2026-08-22T08:26:52Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
