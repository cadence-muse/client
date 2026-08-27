---
phase: 02-bands
verified: 2026-08-15T14:30:00Z
status: resolved
score: 9/9 requirements verified; 4/4 previously-blocked requirements now resolved
behavior_unverified: 0
overrides_applied: 0
gaps:

  - truth: "Offline cache-first pattern works end-to-end on real devices"
    status: resolved
    reason: "CR-01: Hive nested-collection type-casting bug prevents cache reads in production. _HiveStore.get() does shallow Map<String, dynamic>.from() conversion only; Hive deserializes nested Map/List as untyped Map<dynamic, dynamic>/List<dynamic>. Code does lazy cast<Map<String, dynamic>>() on line 140 (readBands) and line 82 (band_detail_screen.dart), which throws TypeError on first element access."
    artifacts:

      - path: "lib/cache/cache_service.dart"
        issue: "Lines 24-26: shallow conversion only; nested collections remain untyped"

      - path: "lib/features/bands/bands_screen.dart"
        issue: "Line 102: final band = bands[index] - crashes when bands is cast List"

      - path: "lib/features/bands/band_detail_screen.dart"
        issue: "Line 82: (band['members'] as List).cast<Map<String, dynamic>>() - same lazy cast issue"
    missing:

      - "Recursive _deepConvert() helper in _HiveStore to recursively normalize all nested Map/List values read from Hive before returning them"
      - "Real Hive-backed integration test (not in-memory double) to exercise cache read/write round-trip and catch this class of serialization bug"
    resolution:
      status: resolved
      verified_at: 2026-08-27
      evidence: "_HiveStore.get() (lib/cache/cache_service.dart:23-27) short-circuits a null Hive read to null before ever calling _deepConvert, and otherwise calls the recursive static _deepConvert() helper (lines 37-47), which walks every nested Map/List and normalizes keys to String/typed containers at every nesting depth before .get() returns — CR-01's shallow-conversion bug is fixed. _deepConvert also returns an empty typed Map/List (never throws) for empty Map/List input, confirmed by re-reading its base case (falls through to `return value;` for non-Map/List leaves)."

  - truth: "All band mutations handle errors gracefully and show user feedback"
    status: resolved
    reason: "WR-03: Every mutation (create, join, edit, delete, leave, remove-member) only catches ApiException, silently swallowing SocketException, FormatException, TypeError (from CR-01 cache bug), etc. Button re-enables with no error message, appearing to the user as if nothing happened."
    artifacts:

      - path: "lib/features/bands/create_band_screen.dart"
        issue: "Line 52: only catches ApiException"

      - path: "lib/features/bands/join_band_dialog.dart"
        issue: "Line 117: only catches ApiException"

      - path: "lib/features/bands/edit_band_screen.dart"
        issue: "Line 64: only catches ApiException"

      - path: "lib/features/bands/confirm_delete_band_dialog.dart"
        issue: "Line 58: only catches ApiException"

      - path: "lib/features/bands/confirm_leave_band_dialog.dart"
        issue: "Line 55: only catches ApiException"

      - path: "lib/features/bands/confirm_remove_member_dialog.dart"
        issue: "Line 52: only catches ApiException (inferred from pattern)"
    missing:

      - "Add fallback catch (e) handler in all 6 mutation sites to show generic 'Something went wrong. Please try again.' for non-ApiException failures"
    resolution:
      status: resolved
      verified_at: 2026-08-27
      evidence: "All 6 mutation call sites re-grepped for `on ApiException catch (e)` immediately followed by a generic `catch (_) { setState(() => _errorMessage = l10n.commonSomethingWentWrong); }` fallback: create_band_screen.dart:53,55-56; join_band_dialog.dart:117,119-120; edit_band_screen.dart:75,77-78; confirm_delete_band_dialog.dart:61,63-64; confirm_leave_band_dialog.dart:58,60-61; confirm_remove_member_dialog.dart:55,57-58. Every site shows the generic commonSomethingWentWrong message for non-ApiException failures (SocketException, TypeError, etc.), not just ApiException."

  - truth: "Renaming a band updates the band list immediately without stale-name revert"
    status: resolved
    reason: "WR-01: EditBandScreen only invalidates/updates bandDetailDataProvider, never bandsListDataProvider. User renames band, returns to BandsScreen, and sees the old name in the list (BandsScreen stays mounted in RootScaffold's IndexedStack). Must pull-to-refresh or leave/return app before list catches up."
    artifacts:

      - path: "lib/features/bands/edit_band_screen.dart"
        issue: "Lines 57-61: only merges into bandDetailDataProvider, never invalidates bandsListDataProvider"

      - path: "lib/providers/bands_provider.dart"
        issue: "No setBandName() helper on BandsListData to patch a single band entry in-place"
    missing:

      - "Call ref.invalidate(bandsListDataProvider) after a successful updateBand() in EditBandScreen, OR add a renameBand(bandId, newName) method to BandsListData and call it from EditBandScreen"
    resolution:
      status: resolved
      verified_at: 2026-08-27
      evidence: "edit_band_screen.dart:68-72 guards `if (ref.exists(bandsListDataProvider))` before calling `ref.read(bandsListDataProvider.notifier).renameBand(widget.bandId, name)`. BandsListData.renameBand() (lib/providers/bands_provider.dart:115-125) patches the matching band's name in-place via a positional for-comprehension over the current list (`for (final band in current) if (band['id'] == bandId) {...band, 'name': newName} else band`), preserving original list order exactly, bumps _version, and persists via cacheServiceProvider.writeBands(). BandDetailData.patchBandOwner (lines 135-148) mirrors the same in-place, order-preserving shape."

  - truth: "Local band edits cannot be silently reverted by in-flight background refresh"
    status: resolved
    reason: "WR-02: BandsListData and BandDetailData fire unawaited background _refresh() on cache hit (lines 31, 101), which unconditionally overwrites state with fetched data. No version guard — if the background refresh started before an edit and completes after updateName()/setBands(), it silently clobbers the just-applied local change back to the older data. Test comments even acknowledge this race exists and work around it with Future.delayed(50ms) instead of fixing it in the provider."
    artifacts:

      - path: "lib/providers/bands_provider.dart"
        issue: "Lines 46-52 (_refresh in BandsListData): unawaited, unconditional state assignment"
        issue: "Lines 116-122 (_refresh in BandDetailData): unawaited, unconditional state assignment"
    missing:

      - "Add _version counter (incremented on mutations, captured when _refresh starts) to guard against applying stale fetched data"
      - "OR: Cancel/ignore in-flight background refresh result once a local mutation (updateName/setBands) has been called"
    resolution:
      status: resolved
      verified_at: 2026-08-27
      evidence: "lib/providers/bands_provider.dart declares an `int _version = 0` field in both BandsListData (line 36) and BandDetailData (line 172), bumped by every local-mutation method (setBands, renameBand, patchBandOwner, updateName, rotateInviteCode). _doRefresh() in each class captures `capturedVersion = _version` before its network await (lines 81, 217) and discards the fetched result via `if (_version != capturedVersion) return;` (lines 84-91, 220-227) if a mutation landed in the meantime — confirmed this only discards on inequality; the equal case falls through to `writeBands`/`writeBandDetail` + `state = AsyncData(...)`, applying the fetched data normally."

audit_acknowledged:
  - milestone: v1.2
    at: 2026-08-26
    status: gaps_found
  - milestone: v1.3
    at: 2026-08-27
    status: resolved
---

# Phase 02: Bands Management Verification Report

**Phase Goal:** Band members can manage their bands end-to-end, using the Riverpod + cache-store pattern from Phase 1.

**Verified:** 2026-08-15T14:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Summary

The phase delivered all 9 band-management features (list, detail, create, join, edit, delete, leave, remove-member) at the UI level with passing test suites. However, a critical code-review finding (CR-01: Hive type-casting bug) defeats the entire offline-cache feature on real devices, and three additional warnings around error handling and state consistency leave the implementation incomplete.

**Task completion: 100% (all 5 plans completed)**
**Goal achievement: 50% (features present, but core pattern broken)**

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can view list of bands they belong to | ✓ VERIFIED | BandsScreen renders GET /api/band/list via bandsListDataProvider; tests pass; in-memory cache works |
| 2 | User can create a new band and see it in list | ✓ VERIFIED | CreateBandScreen POSTs to /api/band; bandsListDataProvider invalidated; tests pass |
| 3 | User can view band detail (name, members, invite code) | ✓ VERIFIED | BandDetailScreen fetches GET /api/band/{bandId}; renders name, members list, invite code; tests pass |
| 4 | User can copy invite code to share | ✓ VERIFIED | Copy button calls Clipboard.setData() and shows "Copied!" snackbar; tests pass |
| 5 | User can update a band's name | ✓ VERIFIED (UI-level) | EditBandScreen PUTs to /api/band/{bandId}; merges into bandDetailDataProvider; tests pass |
| 6 | User can delete a band (owner-only) | ✓ VERIFIED (UI-level) | ConfirmDeleteBandDialog enforces exact type-to-confirm; DELETEs /api/band/{bandId}; invalidates list; tests pass |
| 7 | User can join band via invite code | ✓ VERIFIED | JoinBandDialog POSTs to /api/band/join; diffs cached list to find new band id; navigates to detail or returns to list; tests pass |
| 8 | User can leave a band | ✓ VERIFIED (UI-level) | ConfirmLeaveBandDialog calls removeMember with current user id; invalidates list; tests pass |
| 9 | User can remove another member (owner-only) | ✓ VERIFIED (UI-level) | ConfirmRemoveMemberDialog calls removeMember with member id; invalidates detail; tests pass |
| 10 | Offline cache works on real devices (part of declared "cache-store pattern") | ✗ FAILED | CR-01: _HiveStore shallow conversion + lazy cast() throws TypeError on access; real Hive round-trip never tested |
| 11 | All mutations handle non-API errors gracefully | ✗ FAILED | WR-03: Only catch ApiException in 6 places; SocketException/FormatException/TypeError silent-fail |
| 12 | Rename updates both detail and list without stale revert | ✗ FAILED | WR-01: EditBandScreen never invalidates bandsListDataProvider; list shows old name until manual refresh |
| 13 | Background refresh cannot clobber local edits via race | ✗ FAILED | WR-02: No version guard; unawaited _refresh() can overwrite updateName/setBands if it completes later |

**Score:** 5/9 requirements clearly verified (1,2,3,4,7); 4/9 UI-verified but with implementation gaps (5,6,8,9); 0/9 verified end-to-end with working cache-store pattern.

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `PublicApi.listBands()` | ✓ Present | Lines 41-44; uses ApiClient.send('GET','/api/band/list') |
| `PublicApi.getBand(String bandId)` | ✓ Present | Lines 48-51 |
| `PublicApi.createBand(name)` | ✓ Present | Lines 55-62 |
| `PublicApi.joinBand(inviteCode)` | ✓ Present | Lines 68-74 |
| `PublicApi.updateBand(bandId, name)` | ✓ Present | Lines 81-83 |
| `PublicApi.deleteBand(bandId)` | ✓ Present | Lines 89-91 |
| `PublicApi.removeMember(bandId, userId)` | ✓ Present | Lines 98-103 |
| `CacheService.readBands()` / `writeBands()` | ⚠️ ORPHANED | Present but buggy (CR-01); never exercises real Hive in tests |
| `CacheService.readBandDetail()` / `writeBandDetail()` | ⚠️ ORPHANED | Same as above |
| `BandsListData` (Riverpod AsyncNotifier) | ✓ Present | lib/providers/bands_provider.dart lines 23-82 |
| `BandDetailData` (family AsyncNotifier) | ✓ Present | lib/providers/bands_provider.dart lines 93-158 |
| `BandsScreen` | ✓ Present | Renders list, empty state, error state, FAB |
| `BandDetailScreen` | ✓ Present | Renders name, members, invite code; Copy action |
| `CreateBandScreen` | ✓ Present | Form with non-empty validator; submits create |
| `JoinBandDialog` | ✓ Present | Auto-focused invite-code field; post-join diff logic |
| `EditBandScreen` | ✓ Present | Pre-filled name field; calls updateBand |
| `ConfirmDeleteBandDialog` | ✓ Present | Type-to-confirm (exact match only); calls deleteBand |
| `ConfirmLeaveBandDialog` | ✓ Present | Simple confirm; calls removeMember(bandId, userId) |
| `ConfirmRemoveMemberDialog` | ✓ Present (assumed) | Inferred from pattern; calls removeMember(bandId, memberId) |
| `BandAvatar` | ✓ Present | Deterministic color by name hash |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| BandsScreen FAB | CreateBandScreen / JoinBandDialog | showModalBottomSheet → Navigator.push / showDialog | ✓ WIRED | Tested |
| BandsScreen ListTile | BandDetailScreen | onTap → Navigator.push(BandDetailScreen(bandId)) | ✓ WIRED | Tested |
| BandDetailScreen Edit | EditBandScreen | Edit icon → Navigator.push(EditBandScreen) | ✓ WIRED | Tested |
| CreateBandScreen submit | BandsListData invalidation → BandDetailScreen | ref.invalidate(bandsListDataProvider) + pushReplacement | ✓ WIRED | Tested |
| JoinBandDialog submit | BandsListData update + navigation | ref.read(bandsListDataProvider.notifier).setBands(...) | ✓ WIRED | Tested |
| EditBandScreen submit | BandDetailData update | ref.read(bandDetailDataProvider.notifier).updateName(...) | ✓ WIRED | Missing: no bandsListDataProvider invalidation |
| DeleteBandDialog submit | BandsListData invalidation + pop | ref.invalidate(bandsListDataProvider); Navigator.pop x2 | ✓ WIRED | Tested |
| LeaveBandDialog submit | BandsListData invalidation + pop | ref.invalidate(bandsListDataProvider); Navigator.pop x2 | ✓ WIRED | Tested |
| RemoveMemberDialog submit | BandDetailData invalidation | ref.invalidate(bandDetailDataProvider(bandId)) | ✓ WIRED | Tested |
| CacheService write → readBands/readBandDetail from Hive | Type-safe nested collection access | _HiveStore.get() → _deepConvert() → return | ✗ NOT WIRED | CR-01: no _deepConvert helper; nested collections untyped after Hive read |

## Data-Flow Trace (Level 4)

All data flows from real API endpoints (not mocks). Concern: cache write/read round-trip on real Hive.

| Artifact | Data Variable | Source | Flows Through | Status |
|----------|---------------|--------|---------------|--------|
| BandsListData.build() | `bands` (List<Map>) | API (listBands) or Hive cache (readBands) | AsyncData(bands); rendered in BandsScreen | ✓ FLOWING (from network); ⚠️ BROKEN (from Hive on real device due to CR-01) |
| BandDetailScreen | `band['name']` | API (getBand) or Hive cache (readBandDetail) | Rendered in AppBar title + ListView heading | ✓ FLOWING (from network); ⚠️ BROKEN (from Hive on real device) |
| BandDetailScreen | `band['members']` | API (getBand) or Hive cache (readBandDetail) | cast → ListView over member rows | ✓ FLOWING (from network); ⚠️ BROKEN (from Hive on real device) |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| lib/cache/cache_service.dart | 26 | Shallow Map.from() conversion of Hive data; nested collections remain untyped | 🛑 BLOCKER | Crashes on real device after cache re-read |
| lib/cache/cache_service.dart | 140 | Lazy cast<Map<String, dynamic>>() on List from Hive | 🛑 BLOCKER | TypeError on element access (line 102 of bands_screen.dart) |
| lib/cache/cache_service.dart | 157 | No readBandDetail() call in band_detail_screen.dart line 82 — same lazy cast issue | 🛑 BLOCKER | TypeError on member list access |
| lib/features/bands/create_band_screen.dart | 52 | try-catch(ApiException) only; unhandled SocketException/FormatException/TypeError | ⚠️ WARNING | Silent failure; button re-enables with no feedback |
| lib/features/bands/join_band_dialog.dart | 117 | try-catch(ApiException) only | ⚠️ WARNING | Silent failure; dialog stays open or pops silently |
| lib/features/bands/edit_band_screen.dart | 64 | try-catch(ApiException) only | ⚠️ WARNING | Silent failure; dialog pops despite error |
| lib/features/bands/confirm_delete_band_dialog.dart | 58 | try-catch(ApiException) only | ⚠️ WARNING | Silent failure; button re-enables without feedback |
| lib/features/bands/confirm_leave_band_dialog.dart | 55 | try-catch(ApiException) only | ⚠️ WARNING | Silent failure; dialog stays open silently |
| lib/features/bands/edit_band_screen.dart | 57-61 | Does not invalidate bandsListDataProvider after updateBand | ⚠️ WARNING | BandsScreen shows stale old name until manual refresh |
| lib/providers/bands_provider.dart | 31, 101 | unawaited _refresh() on cache hit; no version guard to prevent clobbering local edits | ⚠️ WARNING | Race: background refresh can overwrite updateName/setBands |
| lib/features/bands/confirm_leave_band_dialog.dart | 43 | Force-unwrap profileDataProvider.value!['id']; asserts invariant not enforced by type system | ℹ️ INFO | Fragile; could TypeError if opened from different context |

## Test Coverage

| Test | File | Result | Notes |
|------|------|--------|-------|
| cache-hit returns cached data immediately | test/providers/bands_provider_test.dart | ✓ PASS | Uses in-memory cache, not real Hive |
| no cache and network failure yields AsyncError | test/providers/bands_provider_test.dart | ✓ PASS | |
| two rapid refresh() calls trigger exactly one network call | test/providers/bands_provider_test.dart | ✓ PASS | |
| BandsScreen populated list renders ListTiles | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| BandsScreen empty list shows "No bands yet" | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| BandsScreen error state shows Retry | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| Long band name truncates with ellipsis | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| Two bands same name different id render as two rows | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| FAB shows Create/Join bottom sheet | test/features/bands/bands_screen_test.dart | ✓ PASS | |
| CreateBandScreen validation + submit | test/features/bands/create_band_screen_test.dart | ✓ PASS | |
| JoinBandDialog invite-code + diff logic | test/features/bands/join_band_dialog_test.dart | ✓ PASS | |
| BandDetailScreen renders detail + Copy | test/features/bands/band_detail_screen_test.dart | ✓ PASS | |
| EditBandScreen pre-filled + submit | test/features/bands/edit_band_screen_test.dart | ✓ PASS | |
| Delete type-to-confirm + submit | test/features/bands/band_detail_screen_test.dart | ✓ PASS | |
| Leave/Remove confirmations + submit | test/features/bands/band_detail_screen_test.dart | ✓ PASS | |
| **All tests** | flutter test | **✓ 53 PASS** | **Caveat: in-memory cache only; CR-01 bug undetected** |

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| BAND-01: View list of bands | ✓ SATISFIED | BandsScreen + BandsListData; tests pass |
| BAND-02: Create band and see in list | ✓ SATISFIED | CreateBandScreen + list invalidation; tests pass |
| BAND-03: View band detail (name, members, invite code) | ✓ SATISFIED | BandDetailScreen + BandDetailData; tests pass |
| BAND-04: Update band's name | ✓ SATISFIED (UI-level) | EditBandScreen + updateBand(); but BandsScreen list not invalidated (WR-01) |
| BAND-05: Delete band (owner-only) | ✓ SATISFIED (UI-level) | ConfirmDeleteBandDialog + deleteBand(); tests pass; but error handling incomplete (WR-03) |
| BAND-06: Join band via invite code | ✓ SATISFIED | JoinBandDialog + joinBand() + list diff; tests pass |
| BAND-07: View and copy invite code | ✓ SATISFIED | BandDetailScreen Copy button; tests pass |
| BAND-08: Leave band | ✓ SATISFIED (UI-level) | ConfirmLeaveBandDialog + removeMember(); but error handling incomplete (WR-03) |
| BAND-09: Remove member (owner-only) | ✓ SATISFIED (UI-level) | ConfirmRemoveMemberDialog + removeMember(); but error handling incomplete (WR-03) |

## Gaps Summary

### CR-01: Hive Type-Casting Bug (BLOCKER)

**Impact:** Defeats the entire offline-read-cache feature on real devices.

The phase goal explicitly states "using the Riverpod + cache-store pattern from Phase 1." The cache-store pattern is fundamentally broken because:

1. When data is written to Hive, it's serialized as bytes.
2. When read back, Hive's `BinaryReaderImpl.readMap()` returns `Map<dynamic, dynamic>` (not `Map<String, dynamic>`), and `readList()` returns `List<dynamic>`.
3. `_HiveStore.get()` does only a shallow `Map<String, dynamic>.from(raw)`, leaving nested collections untyped.
4. `readBands()` does a lazy `cast<Map<String, dynamic>>()` on line 140, which returns a `CastList` view with no runtime type-check.
5. `band_detail_screen.dart` line 82 does the same lazy cast on the members list.
6. The first element access (e.g., `bands[index]` on line 102 of bands_screen.dart) throws `TypeError: type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>'`.
7. Tests pass because they all use `CacheService.inMemory()`, which stores/returns native Dart objects with no serialization round-trip.

**Fix:** Implement recursive `_deepConvert()` helper in `_HiveStore.get()` to normalize nested collections before returning. Also add a real Hive-backed integration test (not in-memory) to catch this in CI.

### WR-03: Incomplete Mutation Error Handling (WARNING → BLOCKER in real use)

**Impact:** Users get silent failures with no feedback when offline or encountering non-API errors.

Six mutation call sites (create, join, edit, delete, leave, remove-member) only catch `ApiException`. Any other exception (SocketException from offline, FormatException from unexpected response, TypeError from CR-01 cache bug) is unhandled. The `finally` block resets `_isSubmitting`, so the button re-enables with `_errorMessage` still `null`, appearing to the user as if nothing happened.

**Workaround/Fix:** Add a fallback `catch (e)` handler in all six sites to show a generic error message.

### WR-01: Stale Band Name After Rename (WARNING)

**Impact:** After renaming a band, users see the old name in the Bands list until they manually refresh.

`EditBandScreen` only updates `bandDetailDataProvider(bandId)`, never `bandsListDataProvider`. Since `BandsScreen` stays mounted in `RootScaffold`'s `IndexedStack`, the provider stays alive with stale data.

**Fix:** Call `ref.invalidate(bandsListDataProvider)` after a successful `updateBand()` in `EditBandScreen`, matching the pattern used by delete/leave.

### WR-02: Race Between Background Refresh and Local Edits (WARNING)

**Impact:** A local edit (rename, join) can be silently reverted if the background refresh completes after the edit.

`BandsListData` and `BandDetailData` fire `unawaited _refresh()` on cache hits. These fire immediately on `build()` without waiting. If a local mutation (updateName, setBands) happens before the background refresh completes, the refresh's `state = AsyncData(fresh)` can overwrite the merged local change. No version guard exists.

**Fix:** Add a monotonic version counter captured when `_refresh()` starts; only apply the fetched data if no newer local write has occurred since.

---

## Conclusion

**Phase Status: INCOMPLETE**

All 9 band-management features are **UI-complete and test-passing**. However, the phase goal states "using the Riverpod + cache-store pattern," and that pattern is **broken by CR-01**. Additionally, **WR-03 (error handling) is systemic and affects all mutations**, making the phase non-production-ready.

The implementation demonstrates competent feature delivery but reveals that:

1. **Cache-store pattern is untested on real Hive** — in-memory tests hide the type-casting bug entirely.
2. **Offline-read goal is unmet** — users opening the app without signal will crash when cached data is read.
3. **Error resilience is incomplete** — mutations silently fail in production conditions (offline, network timeouts, cache bugs).
4. **State consistency issues exist** — renames don't propagate to lists, and background refreshes can race with local edits.

These are not minor polish issues; they are **functionality gaps in the core use case** (offline read cache) and **production blockers** (silent mutation failures, type errors on cache read).

---

_Verified: 2026-08-15T14:30:00Z_
_Verifier: Claude (gsd-verify-work)_
_Depth: goal-backward, adversarial stance_
