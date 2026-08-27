---
phase: 16-track-terminology-rename
reviewed: 2026-08-27T14:07:22Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/features/tracks/tracks_screen.dart
  - lib/navigation/root_scaffold.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - lib/features/home/home_screen.dart
  - lib/features/home/band_picker_sheet.dart
  - test/features/tracks/tracks_screen_test.dart
  - test/regression/offline_trust_regression_test.dart
  - test/features/home/home_screen_test.dart
  - test/providers/setlists_provider_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/tracks/track_list_screen_test.dart
  - test/features/tracks/confirm_delete_track_dialog_test.dart
  - test/features/tracks/create_track_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
  - test/cache/cache_service_test.dart
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 16: Code Review Report

**Reviewed:** 2026-08-27T14:07:22Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** clean

## Summary

Phase 16 is a strictly scoped rename: (1) moved `lib/features/songs/tracks_screen.dart` to `lib/features/tracks/tracks_screen.dart` and updated its sole import site in `root_scaffold.dart`, and (2) renamed the `homeAddSongButton` ARB key to `homeAddTrackButton` (English "Add Track", Russian "Добавить трек"), regenerated the three `lib/generated/app_localizations*.dart` files via `flutter gen-l10n`, and swept ~51 "Song"-named test fixture strings across 7 test files to their "Track" equivalents.

Adversarial checks performed against the specific failure modes named in the review brief, all negative:

- **Stray "song" reference left behind:** `grep -rliE song` across `lib/` and `test/` (`.dart`/`.arb`) returns exactly one hit — `lib/api/publicapi.yml`, whose `Songs` tag is explicitly out of scope for this phase (deferred to Phase 17 per the plan's D-04) and confirmed untouched by `git diff` against the pre-phase base commit (zero-line diff). No other file in `lib/` or `test/` contains the substring, case-insensitive.
- **Mismatched fixture string vs. its test assertion after a sed-based rename:** Manually traced every fixture `'title'`/`trackTitle` literal against its corresponding `find.text(...)`/`expect(...)` argument in all 7 renamed test files (`setlists_provider_test.dart`, `setlist_detail_screen_test.dart`, `track_list_screen_test.dart`, `confirm_delete_track_dialog_test.dart`, `create_track_screen_test.dart`, `track_detail_screen_test.dart`, `cache_service_test.dart`). Every pair is in sync; no orphaned "Song" string or half-renamed pair found.
- **Broken import/reference after the `lib/features/songs` → `lib/features/tracks` move:** `lib/features/songs/` no longer exists on disk; `root_scaffold.dart` imports the new path and still renders `TracksScreen()` third in the 5-tab `screens` list (Home/Bands/Tracks/Setlists/Profile, D-21 order preserved); both dependent test files (`tracks_screen_test.dart`, `offline_trust_regression_test.dart`) reference the new path.
- **ARB key rename not threaded through to generated files/call sites:** `homeAddTrackButton` getter is present and correctly declared/defined in all three generated files (`app_localizations.dart:807`, `app_localizations_en.dart:416`, `app_localizations_ru.dart:424`); no `homeAddSongButton` getter survives anywhere; `home_screen.dart`'s button label and `band_picker_sheet.dart`'s doc comment both reference the new getter/wording.
- **Accidental logic change:** Diffed each touched production file against the pre-phase base commit — `root_scaffold.dart` (1-line import change only), `home_screen.dart` (3 comment/label lines only, all string-literal), `band_picker_sheet.dart` (1 comment line only), the three generated l10n files and two ARB files (mechanical key-rename diffs only, 1-2 lines each). No conditional, provider-invalidation, navigation-index, or button-enablement logic was touched.

Independently re-ran the full verification surface rather than trusting the plan summaries' self-reported status: `flutter analyze` reports zero issues, and the full `flutter test` suite (461 tests) passes with zero failures.

All reviewed files meet quality standards. No issues found.
