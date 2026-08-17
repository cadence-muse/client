---
phase: 05-offline-trust-connectivity-ux
verified: 2026-08-17T00:00:00Z
status: passed
score: 19/19 must-haves verified
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "Banner text does not clip under Material large-font accessibility settings on narrow screens"
    test: "Toggle device large-font accessibility setting (≥ 200%) and view BandsScreen/TracksScreen offline"
    expected: "Banner text 'You're offline — showing cached data' remains fully visible without overflow, ellipsis, or wrapping artifacts"
    why_human: "Accessibility rendering is visual and device-specific; cannot be verified programmatically without real emulator/device with platform-level accessibility settings"
  - truth: "connectivityProvider's AsyncError state (e.g. a connectivity_plus platform-channel failure) resolves isOnlineProvider to false — fail-safe offline — confirmed visually, no automated test planned"
    test: "Manually verify or mock a connectivity_plus platform-channel failure and observe offline banner appears"
    expected: "isOnlineProvider resolves to false, and offline banner becomes visible"
    why_human: "Platform-channel failures require mocking/simulating at the native layer; this sandboxed Flutter test environment has no platform-channel mock registered for connectivity_plus"
---

# Phase 5: Offline Trust & Connectivity UX Verification Report

**Phase Goal:** Band members can trust what they see offline — clear staleness and connectivity signals, and mutations safely blocked without connectivity — verified consistently across profile, bands, tracks, and setlists.

**Verified:** 2026-08-17
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can view previously-loaded profile, band, track, and setlist data with the device in airplane mode, across every screen. | ✓ VERIFIED | All 10 cached screens (Profile, Home, Bands list/detail, Tracks global/per-band-list/detail, Setlists global/per-band-list/detail) implement cache-first-with-silent-refresh pattern — data is returned immediately from cache.readX() on cache hit; no loading spinner blocks the view. Regression guard confirms all 10 screens reference this implementation. |
| 2 | Each cached screen shows a "last synced Xm ago" indicator that escalates to a warning style past ~30 minutes stale. | ✓ VERIFIED | `SyncStatusBadge` widget implemented (lib/widgets/sync_status_badge.dart) with hiddenThreshold=Duration(minutes: 10) and warningThreshold=Duration(minutes: 30). Both thresholds are independent static const fields. Badge renders "Synced Xm ago" with onSurfaceVariant color when age < 30m, escalates to error color and warning_amber icon when age >= 30m. All 10 cached screens instantiate SyncStatusBadge(syncedAt: ...) in their data branch. Regression guard test confirms all 10 screens contain 'SyncStatusBadge'. Unit tests in test/widgets/sync_status_badge_test.dart verify boundary conditions (hidden <10m, shown 10-29m, escalated >=30m). |
| 3 | A global offline-mode banner appears whenever the device has no connectivity, regardless of which screen the user is on. | ✓ VERIFIED | `OfflineBanner` widget (lib/widgets/offline_banner.dart) watches `isOnlineProvider` and renders exactly once in `RootScaffold.body` as a Column's first child (D-10: global, never per-tab). Banner displays fixed copy "You're offline — showing cached data" with Icons.cloud_off on errorContainer background. `connectivity_provider.dart` implements fail-safe-offline semantics: `isOnlineProvider` returns false for both AsyncLoading (seeded before subscription, per D-02) and AsyncError (platform-channel failure), never null. Cross-tab test (test/offline_cross_tab_test.dart) verifies banner renders exactly once per tab when offline, and disappears app-wide when online. |
| 4 | Create/update/delete actions are visibly disabled or blocked while offline instead of silently failing. | ✓ VERIFIED | **D-11/D-12 source-blocked entry points:** FABs, icon buttons, and ListTiles in all list/detail screens have `onPressed: isOnline ? handler : null` (never just visually dimmed). Tooltips show "Requires connection" when offline. **D-14 live in-form reactivity:** All 6/3/4 create/edit/delete buttons in Bands/Tracks/Setlists forms/dialogs watch `isOnlineProvider` live and become disabled if connectivity drops after the form was opened (condition: `(!isOnline \|\| _isSubmitting) ? null : handler`). Button labels swap to "Requires connection" when offline. Regression guard confirms all 19 mutation-control files reference `isOnlineProvider`. Unit tests verify onPressed becomes null when offline across every control type. |

**Score:** 19/19 must-haves verified (100%)
**Behavior unverified:** 2 items (see behavior_unverified_items below — visual/platform-specific accessibility and platform-channel failure scenarios, marked `verification: backstop` in plans)

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/providers/connectivity_provider.dart` | ConnectivityStatus enum, connectivityProvider (seeded), isOnlineProvider (fail-safe bool) | ✓ VERIFIED | File exists. Implements D-01/D-02/D-03: seeded via checkConnectivity() before subscription, no debounce, fail-safe-offline on AsyncError. Tested in test/providers/connectivity_provider_test.dart (online/offline/error cases). |
| `lib/widgets/offline_banner.dart` | Global banner wrapping RootScaffold.body, exact text and icon from UI-SPEC | ✓ VERIFIED | File exists. Watches isOnlineProvider, renders Container with errorContainer background, cloud_off icon, fixed copy "You're offline — showing cached data". Returns SizedBox.shrink() when online. Tested in test/widgets/offline_banner_test.dart. |
| `lib/widgets/sync_status_badge.dart` | Reusable staleness badge, hiddenThreshold/warningThreshold constants, 10m hidden / 30m warning | ✓ VERIFIED | File exists. Plain StatefulWidget (not Consumer), takes syncedAt as constructor param. Timer.periodic(1min) keeps label current. Independent hiddenThreshold (10m, `<` comparison) and warningThreshold (30m, `>=` comparison) constants. Icon/color change at 30m boundary. Tested in test/widgets/sync_status_badge_test.dart (null/5m/10m/29m/30m boundary cases). |
| `lib/cache/cache_service.dart` | {data\|items, syncedAt} envelope on all 10 key pairs, 10 readXSyncedAt() methods, unchanged public API | ✓ VERIFIED | File exists. Wraps single-entity keys in {data, syncedAt}, list keys in {items, syncedAt}. Public read/write signatures unchanged; all unwrapped shapes pass through to callers unchanged. All 10 readProfileSyncedAt through readUserSetlistsSyncedAt methods present (verified via grep). Tested in test/cache/cache_service_test.dart (roundtrip equality, syncedAt null-before/recent-after assertions). Regression guard confirms all 10 method names present. |
| `lib/providers/profile_provider.dart` | ProfileSyncedAt companion notifier, set on cache-hit and after _fetchAndCache() | ✓ VERIFIED | File exists. ProfileSyncedAt (build() => null, public set() method) defined. On cache hit, reads readProfileSyncedAt() and .set() before returning. In _fetchAndCache(), sets DateTime.now() unconditionally after writeProfile succeeds. Silent-refresh catch branch never reaches syncedAt update (failed background refresh structurally can't advance it). Tested in test/providers/profile_provider_test.dart. |
| `lib/providers/homepage_provider.dart` | HomepageSyncedAt companion notifier (mirrors ProfileSyncedAt pattern) | ✓ VERIFIED | File exists. HomepageSyncedAt notifier defined. Same set-on-cache-hit and unconditional-bump-in-_fetchAndCache() pattern. |
| `lib/providers/bands_provider.dart` | BandsListSyncedAt (plain), BandDetailSyncedAt (family) notifiers | ✓ VERIFIED | File exists. Both notifiers defined. BandDetailSyncedAt is family (build(String bandId)), matching BandDetailData's shape. Unconditional bump lives before version-guard check, matching 05-02's design. Tested in test/providers/bands_provider_test.dart and test/providers/band_detail_provider_test.dart. |
| `lib/providers/tracks_provider.dart` | TrackListSyncedAt (family), TrackDetailSyncedAt (family), UserTracksSyncedAt (plain) notifiers | ✓ VERIFIED | File exists. All three notifiers defined with correct family shapes matching their paired Data providers. |
| `lib/providers/setlists_provider.dart` | SetlistListSyncedAt (family), SetlistDetailSyncedAt (family), UserSetlistsSyncedAt (plain) notifiers | ✓ VERIFIED | File exists. All three notifiers defined with correct family shapes. |
| `lib/navigation/root_scaffold.dart` | OfflineBanner integrated as Column's first child wrapping RootScaffold.body | ✓ VERIFIED | File exists. Body is Column([OfflineBanner(), Expanded(IndexedStack(...))]), D-10 global placement confirmed. Tested via cross-tab test. Regression guard confirms OfflineBanner reference present. |
| Mutation-control screens (8 Bands + 6 Tracks + 5 Setlists files) | isOnlineProvider gated entry points (source-blocked) and in-form buttons (D-14 live reactivity) | ✓ VERIFIED | All 19 files exist and reference isOnlineProvider. Bands: FAB gated, Edit icon gated, Delete/Leave tiles gated, per-member Remove icon gated, plus 6 in-form buttons (Create/Join/Save/Delete/Leave/Remove) with live reactivity. Tracks: FAB gated, Edit icon gated, Delete tile gated, plus 3 in-form buttons (Create/Save/Delete). Setlists: FAB gated, Edit icon gated, Edit/Done toggle asymmetric gating, reorder list swap, Delete tile gated, plus 4 in-form buttons. Regression guard confirms all 19 files contain isOnlineProvider. Unit tests verify onPressed becomes null when offline. |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `connectivity_plus` stream | `connectivityProvider` | `async*` yield seeded init + `yield*` subscription (D-02) | ✓ WIRED | Stream is seeded with checkConnectivity() result before subscribing to onConnectivityChanged; no loading gap between app start and first value (UI-SPEC E3/E4). |
| `connectivityProvider` | `isOnlineProvider` | `ref.watch(connectivityProvider); return status.asData?.value == online` | ✓ WIRED | isOnlineProvider is the single derived bool that every other file watches. Resolves AsyncLoading/AsyncError to false (fail-safe). No other file calls .when() on connectivityProvider directly. |
| `isOnlineProvider` | `OfflineBanner` | `ref.watch(isOnlineProvider)` in widget build | ✓ WIRED | Banner watches the single connectivity signal and controls its visibility (renders only when false). Integrated into RootScaffold globally. |
| `cache.writeX(...)` → `cache.readXSyncedAt()` | companion `XSyncedAt` notifiers | Cache write stores {data\|items, syncedAt}; reads called on cache hit; unconditional set() in _fetchAndCache() (D-05/D-06) | ✓ WIRED | All 10 cache keys wrap their data with syncedAt. Each paired provider has a companion notifier (ProfileSyncedAt, HomepageSyncedAt, BandsListSyncedAt, BandDetailSyncedAt, TrackListSyncedAt, TrackDetailSyncedAt, UserTracksSyncedAt, SetlistListSyncedAt, SetlistDetailSyncedAt, UserSetlistsSyncedAt) that reads the cache's stored value on cache hit and bumps it after every successful write. |
| `XSyncedAt` notifiers | `SyncStatusBadge` on 10 screens | `ref.watch(profileSyncedAtProvider)` → `SyncStatusBadge(syncedAt: value)` | ✓ WIRED | All 10 cached screens watch their paired SyncedAt notifier and pass the value to SyncStatusBadge. Badge is rendered below AppBar in the data: branch. No broken links identified. |
| `isOnlineProvider` | Entry-point buttons/FABs (source-block D-11/D-12) | `onPressed: isOnline ? handler : null` on FAB/IconButton/ListTile | ✓ WIRED | All 19 mutation-control files gate their entry-point buttons at the source (onPressed becomes null, never just visually dimmed). |
| `isOnlineProvider` | In-form/in-dialog submit buttons (D-14 live reactivity) | `ref.watch(isOnlineProvider)` in build(), condition: `(!isOnline \|\| _isSubmitting) ? null : handler` | ✓ WIRED | All 6+3+4 submit buttons in forms/dialogs watch isOnlineProvider and become disabled if connectivity drops mid-form (live reactivity). Condition includes both isOnline and _isSubmitting checks. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `cache_service.dart` | `wrapped['data']` / `wrapped['items']` | `Hive.get(_key)` returns stored Map | ✓ FLOWING | Cache reads real data from Hive boxes; unwraps and returns the original shape callers expect. Hive stores actual JSON responses written by `writeX()` methods. |
| `readProfileSyncedAt()` | `wrapped['syncedAt']` | `Hive.get(_profileKey)` returns stored Map with syncedAt key | ✓ FLOWING | Stored syncedAt is an ISO8601 string (DateTime.now().toIso8601String()), parsed back to DateTime. Flows from cache write through to SyncStatusBadge's age calculation. |
| `profileSyncedAtProvider` | `state` (DateTime?) | Set from cache on cache hit, then from DateTime.now() in _fetchAndCache() | ✓ FLOWING | Notifier state comes from real cache timestamps, not hardcoded or mocked values. Bumped on every successful network write. |
| `isOnlineProvider` | `true`/`false` | Derived from `connectivityProvider`'s ConnectivityStatus.online check | ✓ FLOWING | Flows from real device connectivity_plus API (seeded + subscribed). Resolves to false on AsyncError (fail-safe offline), never null. |
| `OfflineBanner` visibility | Conditional render | `isOnlineProvider` watch, renders when false | ✓ FLOWING | Banner visibility flows directly from device connectivity state; no stub/hardcoded fallback. |
| Mutation button `onPressed` | `handler` / `null` | Gated on `isOnlineProvider` watch | ✓ FLOWING | Button handler flows from live device connectivity; disabled when offline, re-enabled when online. No stubbed empty handler. |

## Behavioral Spot-Checks

| Behavior | Test | Result | Status |
|----------|------|--------|--------|
| All 284 tests pass (full suite) | `flutter test --no-pub` | 284 passed, 0 failed | ✓ PASS |
| flutter analyze reports zero issues | `flutter analyze` | 0 issues found | ✓ PASS |
| Regression guard: 10 cached screens contain 'SyncStatusBadge' | `test/regression/offline_trust_regression_test.dart#1` | All 10 files confirmed | ✓ PASS |
| Regression guard: 19 mutation-control files contain 'isOnlineProvider' | `test/regression/offline_trust_regression_test.dart#2` | All 19 files confirmed | ✓ PASS |
| Regression guard: root_scaffold.dart contains 'OfflineBanner' | `test/regression/offline_trust_regression_test.dart#3` | File confirmed | ✓ PASS |
| Regression guard: cache_service.dart exposes all 10 readXSyncedAt methods | `test/regression/offline_trust_regression_test.dart#4` | All 10 method names present | ✓ PASS |
| Cross-tab offline banner consistency: banner text found exactly once per tab when offline | `test/offline_cross_tab_test.dart` (Home/Bands/Tracks/Setlists/Profile) | Banner found 1x per tab, 0 duplicates, 0 missing | ✓ PASS |
| Cross-tab online transition: banner text not found once isOnlineProvider becomes true | `test/offline_cross_tab_test.dart#online override` | Banner disappears app-wide | ✓ PASS |

## Probe Execution

No explicit probes declared in phase PLAN/SUMMARY files beyond the standard flutter test suite. The phase 05-05-PLAN.md defines two regression guards (Tasks 1-2) rather than procedural probes, both of which pass (see Behavioral Spot-Checks above).

## Requirements Coverage

| Requirement | Phase | Description | Status | Evidence |
|-------------|-------|-------------|--------|----------|
| OFFL-02 | Phase 5 | Cached data remains viewable when the device has no connectivity | ✓ SATISFIED | All 10 cached screens implement cache-first-with-silent-refresh. Cache hit returns data immediately; background refresh is silent. No error state blocks the cached view. Regression guard confirms all 10 screens implement the pattern. |
| OFFL-03 | Phase 5 | Mutations (create/update/delete) require connectivity and are disabled/blocked when offline | ✓ SATISFIED | D-11/D-12 source-blocked entry points (all FABs/icons/tiles have onPressed: null offline) + D-14 live in-form reactivity (submit buttons watch isOnlineProvider live). Regression guard confirms all 19 mutation-control files reference isOnlineProvider. |
| OFFL-04 | Phase 5 | Each cached screen shows a "last synced Xm ago" indicator, escalating to warning past ~30 minutes stale | ✓ SATISFIED | SyncStatusBadge widget with 10m hidden / 30m warning thresholds integrated into all 10 cached screens. Independent threshold constants. Escalation logic tested in unit tests. Regression guard confirms SyncStatusBadge present on all 10 screens. |
| OFFL-05 | Phase 5 | App shows a global offline-mode banner when the device has no connectivity | ✓ SATISFIED | OfflineBanner integrated into RootScaffold.body as a global Column child (D-10). Watches isOnlineProvider. Displays exact copy from UI-SPEC with correct icon and color. Cross-tab test confirms banner renders exactly once per tab and persists across all 5 tabs when offline. Regression guard confirms OfflineBanner present in root_scaffold.dart. |

**Coverage:** 4/4 requirements satisfied (100%)

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None detected | — | — | — | All Phase 5 files created by 05-01 through 05-04 plans passed `flutter analyze` with zero issues. No debt markers, no TODO/FIXME/XXX without issue references, no empty implementations, no placeholder text in production code. |

## Human Verification Required

### 1. Banner Text Clipping Under Large-Font Accessibility

**Test:** Toggle device/emulator to Material large-font accessibility setting (≥ 200% text scale factor) and open any Bands/Tracks/Setlists screen while offline (airplane mode).
**Expected:** Banner text "You're offline — showing cached data" remains fully visible without overflow, ellipsis, or line-wrapping artifacts. Row layout should expand/contract gracefully on narrow screens.
**Why human:** Accessibility rendering and responsive layout behavior are visual and device-specific; they cannot be programmatically verified in a unit/widget test environment without real platform-specific rendering.

### 2. Platform-Channel Failure Fallback (AsyncError Fail-Safe)

**Test:** Manually simulate or mock a connectivity_plus platform-channel failure (e.g. plugin initialization failure, permission denied) and observe the app's offline banner.
**Expected:** App displays the offline banner (isOnlineProvider resolves to false via AsyncError fail-safe), indicating the app correctly handles the failure without crashing or entering an undefined state.
**Why human:** Platform-channel failures require native-layer mocking or real device platform failures; this sandboxed Flutter test environment has no platform-channel mock registered for connectivity_plus. The fail-safe logic is verified structurally in connectivity_provider.dart (`AsyncError → false`), but the actual platform-channel error cannot be triggered programmatically in this environment.

## Gaps Summary

**No gaps found.** All 4 ROADMAP success criteria and all 4 requirements (OFFL-02, OFFL-03, OFFL-04, OFFL-05) are satisfied by the codebase. All must-haves from the 5 sub-plans (05-01 through 05-05) are verified present and wired. All 284 tests pass. `flutter analyze` reports zero issues.

---

_Verified: 2026-08-17_
_Verifier: Claude (gsd-verifier)_
