---
phase: 09-homepage-quick-actions
reviewed: 2026-08-22T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/features/home/band_picker_sheet.dart
  - lib/features/home/home_screen.dart
  - test/features/home/band_picker_sheet_test.dart
  - test/features/home/home_screen_test.dart
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-08-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the new `band_picker_sheet.dart` (net-new file) and the restructured `home_screen.dart` (Quick Actions layout + band-picker wiring), plus their test files. The happy-path implementation (loading/error/data states, D-05 through D-08/D-11 navigation handoff, `context.mounted` guard after the async `showModalBottomSheet` gap) is correct and well tested. No critical/security defects found. Three warnings center on the band-picker's handling of degenerate states that its own data source (`bandsListDataProvider`) can legitimately produce but that neither the widget nor its tests account for: an empty band list, an unbounded/long band list with no scroll container, and an error state with no real retry path given how `bandsListDataProvider` is kept alive elsewhere in the app.

## Warnings

### WR-01: Band-picker has no empty-state UI, and can silently render blank

**File:** `lib/features/home/band_picker_sheet.dart:33-49`
**Issue:** The `data:` branch renders a `Column` built from `for (final band in bands) ListTile(...)` with no check for `bands.isEmpty`. The picker's gating (`bandsCount > 0`, `home_screen.dart:138,145`) comes from a *different* provider (`homepageDataProvider`'s `bandsCount` field, from `GET /api/homepage`) than the picker's actual data source (`bandsListDataProvider`, from `GET /api/band/list`, `lib/providers/bands_provider.dart`). These are two independently-fetched, independently-cached, online-first providers with no shared version/consistency guarantee — e.g. a stale cached `bandsCount` in `HomepageData`, or the user having just been removed from their only band by another user, produces a state where the "Add Song"/"Add Setlist" buttons are enabled but the sheet's `bandsListDataProvider` resolves to an empty (or now-empty) list. In that window the sheet opens to a blank/near-zero-height surface with no explanation and no way to know why, other than dismissing it.
**Fix:** Add an explicit empty-state branch, e.g.:
```dart
data: (bands) => bands.isEmpty
    ? const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No bands to show. Pull to refresh or try again.'),
      )
    : Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final band in bands) ListTile(...)],
      ),
```

### WR-02: Band-picker's error message implies a retry that isn't actually available

**File:** `lib/features/home/band_picker_sheet.dart:56-59`
**Issue:** On error, the sheet shows "Could not load bands. Please try again." but offers no retry button, and dismissing/reopening the sheet does not actually retrigger a fetch in practice: `bandsListDataProvider` (`BandsListData`, `lib/providers/bands_provider.dart:53`) is `@riverpod` (AutoDispose), but `BandsScreen` (`lib/features/bands/bands_screen.dart:30`) also watches it and is kept permanently mounted inside `RootScaffold`'s `IndexedStack` (`lib/navigation/root_scaffold.dart:34`) — so as long as the app is running with the Bands tab built, the provider never actually disposes between sheet opens, and a cached error state persists. A user hitting this error has no way to recover from within the sheet itself; they must navigate to the Bands tab and use its own Retry button (`bands_screen.dart:56`) before reopening the picker will show data.
**Fix:** Either wire the picker's error branch to a retry action (e.g. `ElevatedButton(onPressed: () => ref.invalidate(bandsListDataProvider), child: const Text('Retry'))`), or soften the copy to not imply an action the sheet doesn't support (e.g. "Could not load bands. Check your connection.").

### WR-03: Band list inside the picker is not wrapped in a scrollable container

**File:** `lib/features/home/band_picker_sheet.dart:34-49`
**Issue:** The picker mirrors `bands_screen.dart`'s `_showCreateJoinMenu` bottom-sheet shape (`Column` with `mainAxisSize: MainAxisSize.min`, no `isScrollControlled`), but that source pattern is a fixed 2-item action menu, not a data-driven list whose length is the user's actual band count. `bands_screen.dart`'s own main list correctly uses `ListView.separated` (`bands_screen.dart:135`) for the same unbounded data. Copying the fixed-menu shape for a variable-length list means a user with enough bands to exceed the sheet's available height will hit a `RenderFlex` overflow with no way to reach the remaining items — there's no test exercising more than 2 bands to catch this.
**Fix:** Wrap the list in a scrollable, sized appropriately for a modal sheet, e.g.:
```dart
data: (bands) => ConstrainedBox(
  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
  child: ListView(
    shrinkWrap: true,
    children: [for (final band in bands) ListTile(...)],
  ),
),
```
(and set `isScrollControlled: true` on the `showModalBottomSheet` call so the sheet can actually grow to use that height).

## Info

### IN-01: Duplicated push-and-branch block for forTrack navigation

**File:** `lib/features/home/band_picker_sheet.dart:68-76`
**Issue:** The `if (forTrack) { ... } else { ... }` block duplicates the `Navigator.of(context).push(MaterialPageRoute(builder: (_) => ...))` scaffolding twice, differing only in the destination widget.
**Fix:** Collapse to a single push with the widget chosen inline:
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => forTrack
        ? CreateTrackScreen(bandId: bandId)
        : CreateSetlistScreen(bandId: bandId),
  ),
);
```

### IN-02: No test coverage for the empty-list / long-list / error-retry gaps

**File:** `test/features/home/band_picker_sheet_test.dart`, `test/features/home/home_screen_test.dart`
**Issue:** Given WR-01/WR-02/WR-03 above, there's no test seeding `bandsListDataProvider` with zero bands while `bandsCount > 0` on the homepage side, none seeding more than 2 bands to check for overflow, and none asserting any retry affordance after an error.
**Fix:** Add coverage once the corresponding warnings are addressed, to lock in the fixed behavior.

---

_Reviewed: 2026-08-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
