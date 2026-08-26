---
phase: 13-string-extraction-screen-localization
plan: 09
subsystem: setlists
tags: [i18n, l10n, setlists, plural-forms]
dependency graph:
  requires: ["13-01"]
  provides: ["setlist_formatting.maxSetlistTracks", "setlist_detail_screen.i18n", "setlists_screen.i18n", "create_setlist_screen.i18n", "add_setlist_tracks_dialog.i18n"]
  affects: ["lib/features/setlists/*"]
tech-stack:
  added: []
  patterns:
    - "Single shared maxSetlistTracks constant in setlist_formatting.dart replaces 3 independently-declared private constants"
    - "AppLocalizations.trackCount()/slotCount() ICU plurals replace pluralizeTracks/tracksAndDuration helpers"
key-files:
  created: []
  modified:
    - lib/features/setlists/setlist_formatting.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - lib/features/setlists/setlists_screen.dart
    - lib/features/setlists/create_setlist_screen.dart
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/features/setlists/setlist_detail_screen_test.dart
    - test/features/setlists/setlists_screen_test.dart
    - test/features/setlists/create_setlist_screen_test.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart
decisions: []
metrics:
  duration: 45min
  completed: 2026-08-26
status: complete
actuals:
  tokens: 15000
  tasks: 3
  commits: 3
---

# Phase 13 Plan 09: Setlist Domain Constant Consolidation + Screen Localization Summary

Consolidated the 3-file-duplicated `_maxSetlistTracks` constant into a single public `maxSetlistTracks` in `setlist_formatting.dart`, deleted the superseded `pluralizeTracks`/`tracksAndDuration` helpers, and fully localized all 4 Setlists-domain screens (detail, global cross-band tab, create, add-tracks dialog) to Russian-plural-correct `AppLocalizations` calls.

## What Was Built

**Task 1 — `setlist_formatting.dart` consolidation + `setlist_detail_screen.dart` + `setlists_screen.dart`:**
- `setlist_formatting.dart`: added public `const int maxSetlistTracks = 100;`; deleted `pluralizeTracks()`/`tracksAndDuration()` (superseded by `AppLocalizations.trackCount()`); dropped the now-unused `track_formatting.dart` import (only `pluralizeTracks`/`tracksAndDuration` needed it — `formatEventDate`/`_monthAbbreviations` don't).
- `setlist_detail_screen.dart`: deleted its private `_maxSetlistTracks`; every string routed through `l10n.*` — fallback title, edit tooltip, done/edit toggle, tracks-header (plain interpolated count per D-12's confirmed non-plural reading), no-tracks empty state, remove-track tooltip/failure snackbar, reorder-failure snackbar, reorder-too-many-tracks message (composed via `l10n.setlistDetailReorderTooManyTracks(l10n.trackCount(maxSetlistTracks))`), add-tracks button, delete tile, and the load-error/retry state.
- `setlists_screen.dart`: full localization of the global cross-band tab — AppBar title (reused `navSetlists`), all-bands filter label, empty-state title/description, load-error/retry, and the trailing tracks+duration text now composed directly as `'${l10n.trackCount(tracksCount)}, ${durationSeconds.asMinutesSeconds}'` (replacing the deleted `tracksAndDuration` helper); imports `track_formatting.dart` directly for the `asMinutesSeconds` extension since `setlist_formatting.dart` no longer re-exports it via that helper.
- Both test files migrated to `tester.strings.*`, including composing `trackCount`/`setlistDetailReorderTooManyTracks` the same way the screens do; added `localizationsDelegates`/`supportedLocales` to each test's `MaterialApp` (the plan's original code didn't specify this test-harness change explicitly, but it's required for `AppLocalizations.of(context)` to resolve non-null in the widget tree — see Deviations).

**Task 2 — `create_setlist_screen.dart` + test:**
- Deleted its private `_maxSetlistTracks`; imports the shared constant via `show maxSetlistTracks`.
- Full localization: AppBar title, name/location/date field labels + name-required validator + date hint, add-tracks-optional header, no-tracks-in-band empty state, at-cap message (`l10n.setlistTracksLimit(l10n.trackCount(maxSetlistTracks))`), couldn't-load-tracks/retry, requires-connection tooltip/button-label, create button, success snackbar (`l10n.createSetlistSuccessSnackbar(name)`), and the generic failure error message.
- Test migrated to `tester.strings.*`; added `localizationsDelegates`/`supportedLocales`.

**Task 3 — `add_setlist_tracks_dialog.dart` + test:**
- Deleted its private `_maxSetlistTracks`; imports the shared constant via `show maxSetlistTracks`.
- Full localization: dialog title (reused `commonAddTracks`), search hint, max-reached message, no-match/none-available empty states, remaining-slots message (composes **both** `trackCount` and `slotCount` plurals via `l10n.addSetlistTracksRemainingMessage(l10n.trackCount(maxSetlistTracks), l10n.slotCount(remainingSlots))`), couldn't-load-tracks/retry, cancel button, requires-connection tooltip/button-label, add button, success snackbar, and the generic failure error message.
- Test migrated to `tester.strings.*`; added `localizationsDelegates`/`supportedLocales`.

## Must-Haves Verification

- `trackCount()` plural is used everywhere in the setlist domain per D-11: the 3 max-track-ceiling messages (detail-screen reorder guard, create-screen at-cap, add-tracks-dialog max-reached/remaining-slots) all route through `l10n.trackCount(maxSetlistTracks)`. The detail-screen's tracks-header stays a plain interpolated `l10n.setlistDetailTracksHeader(tracks.length)` (not a plural call) per D-12's confirmed reading — verified against the ARB entry, which is `"Tracks ({count})"` with an `int` placeholder, not an ICU `plural` block.
- `maxSetlistTracks` has exactly one declaration (`setlist_formatting.dart`), confirmed via `grep -c "const int maxSetlistTracks"` == 1 and `grep -c "_maxSetlistTracks"` == 0 across all 3 former consumers.
- No hardcoded English remains in any of the 4 screens — confirmed via targeted greps for every literal string cited in the plan across all 4 `lib/` files (all zero matches) plus `flutter analyze` reporting no unused-import warnings.
- All 4 test files assert against `tester.strings.*` instead of hardcoded English literals for app-copy; test fixture data (track/setlist/band names, server-returned error messages) intentionally stays hardcoded per the plan's explicit instruction.

## Verification

- `flutter test test/features/setlists/setlist_detail_screen_test.dart test/features/setlists/setlists_screen_test.dart test/features/setlists/create_setlist_screen_test.dart test/features/setlists/add_setlist_tracks_dialog_test.dart` — all 52 tests pass.
- `flutter analyze lib/features/setlists/` — no issues found (no new errors, no unused-import warnings).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Added `localizationsDelegates`/`supportedLocales` to all 4 tests' `MaterialApp` widgets**
- **Found during:** Task 1 (first `flutter test` run)
- **Issue:** The plan's action text didn't mention updating the test harness's `MaterialApp` construction. Running the migrated tests immediately threw `Null check operator used on a null value` at every `AppLocalizations.of(context)!` call site, because none of the 4 test files' `MaterialApp` widgets declared `localizationsDelegates`/`supportedLocales`, so `AppLocalizations.of(context)` always resolved to `null`.
- **Fix:** Added the standard 4-delegate list (`AppLocalizations.delegate` + the 3 `flutter_localizations` Global delegates) and `supportedLocales: const [Locale('en'), Locale('ru')]` to each test's `MaterialApp`/`UncontrolledProviderScope` wrapper, matching the pattern already established in `test/features/bands/band_detail_screen_test.dart` (from an earlier phase-13 plan).
- **Files modified:** `test/features/setlists/setlist_detail_screen_test.dart` (2 `MaterialApp` instances), `test/features/setlists/setlists_screen_test.dart`, `test/features/setlists/create_setlist_screen_test.dart`, `test/features/setlists/add_setlist_tracks_dialog_test.dart`.
- **Commits:** ad9fd14, 895edba, 01e4b73.

**2. [Rule 1 - Bug] Removed the now-unused `track_formatting.dart` import from `setlist_formatting.dart`**
- **Found during:** Task 1 (`flutter analyze`)
- **Issue:** After deleting `pluralizeTracks`/`tracksAndDuration` (the only 2 functions in the file that used the `DurationFormatting` extension), `flutter analyze` flagged the file's `import 'package:cadence/features/tracks/track_formatting.dart';` as an unused-import warning.
- **Fix:** Removed the import. `setlists_screen.dart` (the only file that lost access to `asMinutesSeconds` via this now-deleted re-export path) already imports `track_formatting.dart` directly for the extension.
- **Files modified:** `lib/features/setlists/setlist_formatting.dart`.
- **Commit:** ad9fd14.

## Known Stubs

None — no stub patterns introduced.

## Self-Check: PASSED

- FOUND: lib/features/setlists/setlist_formatting.dart
- FOUND: lib/features/setlists/setlist_detail_screen.dart
- FOUND: lib/features/setlists/setlists_screen.dart
- FOUND: lib/features/setlists/create_setlist_screen.dart
- FOUND: lib/features/setlists/add_setlist_tracks_dialog.dart
- FOUND: test/features/setlists/setlist_detail_screen_test.dart
- FOUND: test/features/setlists/setlists_screen_test.dart
- FOUND: test/features/setlists/create_setlist_screen_test.dart
- FOUND: test/features/setlists/add_setlist_tracks_dialog_test.dart
- FOUND commit: ad9fd14
- FOUND commit: 895edba
- FOUND commit: 01e4b73
