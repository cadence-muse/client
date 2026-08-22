---
title: Fix 3 stale tests asserting the retired cache-first offline-disabled-tiles pattern
subsystem: test
tags: [tests, offline-first, band-detail, widget-test]
dependency-graph:
  requires: []
  provides: []
  affects:
    - test/features/bands/band_detail_screen_test.dart
    - test/widget_test.dart
tech-stack:
  added: []
  patterns:
    - "online-then-offline two-widget-tree-pump-in-one-test pattern (reused existing wrap() helper's isOnline param)"
key-files:
  created: []
  modified:
    - test/features/bands/band_detail_screen_test.dart
    - test/widget_test.dart
decisions:
  - "Preserved original test coverage intent (owner sees Delete, member sees Leave, Remove icon on member rows) by asserting the enabled/tappable state online, then added a second pump asserting OfflineNoCacheView renders with the tile/icon absent offline"
  - "Bottom-nav test needed isOnlineProvider.overrideWithValue(true) added to its overrides list since BandsListData.build() reads isOnlineProvider directly and had no platform-channel mock in this sandbox, defaulting to the fail-safe false"
metrics:
  duration: 25m
  completed: 2026-08-21
status: complete
actuals:
  tokens: 3300
  tasks: 2
  commits: 2
---

# Fix 3 stale tests asserting the retired cache-first offline-disabled-tiles pattern Summary

Rewrote 2 stale `band_detail_screen_test.dart` tests and added a missing `isOnlineProvider` override to `widget_test.dart`'s bottom-nav test, bringing the 3 pre-existing failures left over from phase 07-01's online-first cache-behavior flip down to 0.

## What Was Built

Phase 07-01 flipped `BandDetailData`/`BandDetailScreen` (and `BandsListData`/`BandsScreen`) from cache-first to online-first: offline-with-nothing-cached now renders `OfflineNoCacheView` instead of the old disabled-but-visible tile pattern, and `BandsListData.build()` reads `isOnlineProvider` directly (fail-safe default: `false`). Three tests were stale relative to this new contract:

1. **`band_detail_screen_test.dart` — "Delete and Leave tiles are disabled while offline"** (renamed to "owner sees an enabled Delete tile online, member sees an enabled Leave tile online; offline shows OfflineNoCacheView instead"): rewrote to pump the owner case online first, asserting the `Delete` `ListTile` is `enabled == true` with `onTap != null` (preserving the "owner sees Delete" intent), then pump a fresh offline `CacheService` and assert `OfflineNoCacheView` renders with no `Delete` tile. Repeated the same online-then-offline sequence for the member/Leave case.
2. **`band_detail_screen_test.dart` — "Remove icon on a member row is disabled while offline"** (renamed to "Remove icon appears on a member row while online; offline shows OfflineNoCacheView instead"): rewrote to assert the `person_remove` `IconButton` has `onPressed != null` while online (preserving "Remove icon exists on member rows" intent), then assert `OfflineNoCacheView` renders with the icon absent while offline.
3. **`widget_test.dart` — "bottom navigation switches between tabs"**: added `isOnlineProvider.overrideWithValue(true)` to the test's `ProviderScope` overrides (alongside the existing `cacheServiceProvider`/`apiClientProvider` overrides) and added the corresponding import. Without it, `BandsListData.build()`'s online-first read of `isOnlineProvider` defaulted to `false`, so the Bands tab silently rendered `OfflineNoCacheView` instead of the seeded `'B.A.T.H.'` band the test expected to find and tap.

Both rewritten tests in `band_detail_screen_test.dart` follow the file's established two-widget-tree-pump-in-one-test pattern (see "Edit icon is disabled while offline and enabled while online" for the shape). No other test in either file was touched, and no non-test source file was modified.

## Deviations from Plan

None — plan executed exactly as written.

## Task Commits

| Task | Name | Commit |
| ---- | ---- | ------ |
| 1 | Rewrite the 2 stale offline-disabled-tile tests in band_detail_screen_test.dart | c68c0b7 |
| 2 | Add missing isOnlineProvider override to widget_test.dart's bottom-nav test | 08f750d |

## Verification

- `flutter analyze`: clean, no issues found.
- `flutter test` (full suite): passed with 0 failures after the fix (previously 3 named failures, exactly the 3 this quick task targets).
- `git diff --stat` confirms changes are limited to `test/features/bands/band_detail_screen_test.dart` and `test/widget_test.dart` — no non-test source file touched.

**Before/after failing-test count:**
- Before: 3 failing tests (`band_detail_screen_test.dart`: "Delete and Leave tiles are disabled while offline...", "Remove icon on a member row is disabled while offline..."; `widget_test.dart`: "bottom navigation switches between tabs")
- After: 0 failing tests

## Self-Check: PASSED

- FOUND: test/features/bands/band_detail_screen_test.dart (modified, commit c68c0b7)
- FOUND: test/widget_test.dart (modified, commit 08f750d)
- FOUND: c68c0b7 in git log
- FOUND: 08f750d in git log
