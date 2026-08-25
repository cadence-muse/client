---
phase: 12-locale-i18n-infrastructure
plan: 01
subsystem: i18n
tags: [flutter-gen-l10n, arb, riverpod, shared-preferences, localization]

# Dependency graph
requires: []
provides:
  - "ARB/gen-l10n localization pipeline (l10n.yaml, lib/l10n/app_en.arb, lib/l10n/app_ru.arb, generated lib/generated/app_localizations.dart)"
  - "LocaleController (@riverpod, SharedPreferences-backed) mirroring ThemeController's shape"
  - "MaterialApp.locale binding pattern in lib/app.dart (locale.when() data/loading/error)"
  - "Settings screen Language section (RadioGroup<Locale>) proving the live-switch mechanism end-to-end"
affects: [13-string-extraction-screen-localization, 14-api-error-localization]

# Actuals (#2632)
actuals:
  tokens: 9715
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: [flutter_localizations (SDK), "intl ^0.20.2", "shared_preferences ^2.2.0"]
  patterns:
    - "Async @riverpod AsyncNotifier<Locale> backed by SharedPreferences, mirroring ThemeController's sync ValueNotifier shape but adding build()/setLocale() async persistence"
    - "locale.when(data/loading/error) at the MaterialApp root, matching the existing themeMode watch pattern"
    - "Nested RadioGroup<Locale> inside an outer RadioGroup<ThemeMode> — Flutter 3.44's deprecated per-tile RadioListTile.groupValue/onChanged replaced by ambient RadioGroup ancestors"

key-files:
  created:
    - lib/providers/locale_provider.dart
    - lib/providers/locale_provider.g.dart
    - l10n.yaml
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - test/providers/locale_provider_test.dart
    - test/features/settings/settings_screen_test.dart
    - test/locale_live_switch_test.dart
  modified:
    - pubspec.yaml
    - lib/app.dart
    - lib/features/settings/settings_screen.dart
    - lib/providers/auth_provider.dart
    - test/providers/auth_provider_test.dart
    - test/widget_test.dart
    - test/offline_cross_tab_test.dart

key-decisions:
  - "intl pinned to ^0.20.2 (not ^0.19.0 per RESEARCH.md/UI-SPEC.md) — the installed flutter_localizations SDK package pins intl 0.20.2 exactly; ^0.19.0's caret constraint would conflict"
  - "AppBar title localized via appBarSettingsTitle in this phase (per D-07/Pattern 3), not deferred to Phase 13 as UI-SPEC.md's prose inconsistently suggested"
  - "Language RadioListTile<Locale> pair wrapped in its own nested RadioGroup<Locale> instead of per-tile groupValue/onChanged, since both are @Deprecated in the installed Flutter SDK (3.44.9)"
  - "E3/E4 (background-tab propagation, restart/logout persistence) elevated from UI-SPEC's 'backstop/manual' framing to automated tests in test/locale_live_switch_test.dart, matching ROADMAP Phase 12 success criterion 5"

patterns-established:
  - "SharedPreferences-backed async Riverpod controller: build() reads + defensively falls back to a safe default for unsupported/missing values; setLocale()-style setters write state optimistically before persisting"
  - "Any future test that pumps CadenceApp must call SharedPreferences.setMockInitialValues({}) first, since CadenceApp now watches localeControllerProvider on startup"

requirements-completed: [I18N-01, I18N-02, I18N-03]

coverage:
  - id: D1
    description: "Profile -> Settings shows a Language section (RadioGroup<Locale>, English/Русский options) matching the existing Theme section pattern"
    requirement: I18N-01
    verification:
      - kind: unit
        ref: "test/features/settings/settings_screen_test.dart#renders Theme and Language sections in English by default"
        status: pass
    human_judgment: false
  - id: D2
    description: "Selecting a language updates all visible Settings-screen text immediately (AppBar, section headers) with no restart"
    requirement: I18N-02
    verification:
      - kind: integration
        ref: "test/features/settings/settings_screen_test.dart#tapping Русский updates AppBar title and section headers live, within the same pumped tree (no restart)"
        status: pass
      - kind: integration
        ref: "test/locale_live_switch_test.dart#I18N-01/02: fresh install defaults to English; switching to Russian in Settings applies live"
        status: pass
    human_judgment: false
  - id: D3
    description: "A fresh install (no persisted app_locale) defaults to English; LocaleController falls back to English for any unsupported persisted code"
    requirement: I18N-01
    verification:
      - kind: unit
        ref: "test/providers/locale_provider_test.dart#build() defaults to Locale(en) on a fresh install (no app_locale key)"
        status: pass
      - kind: unit
        ref: "test/providers/locale_provider_test.dart#build() falls back to Locale(en) when SharedPreferences 'app_locale' holds an unsupported code (e.g. 'fr')"
        status: pass
    human_judgment: false
  - id: D4
    description: "A background IndexedStack tab (mounted but inactive when the language changed) reports the new locale via Localizations.localeOf once navigated to"
    requirement: I18N-02
    verification:
      - kind: integration
        ref: "test/locale_live_switch_test.dart#I18N-02 success criterion 5: an IndexedStack tab kept alive in the background reports the new locale once navigated to"
        status: pass
    human_judgment: false
  - id: D5
    description: "Selecting Russian and simulating a full app restart reopens in Russian, with the language surviving logout (D-04)"
    requirement: I18N-03
    verification:
      - kind: integration
        ref: "test/locale_live_switch_test.dart#I18N-03: selecting Russian persists across a simulated app restart"
        status: pass
      - kind: unit
        ref: "test/providers/auth_provider_test.dart#AuthSession signOut() does not clear the app_locale SharedPreferences key (D-04)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-08-25
status: complete
---

# Phase 12 Plan 01: Locale + i18n Infrastructure Summary

**ARB/gen-l10n pipeline with a SharedPreferences-backed LocaleController (mirroring ThemeController) wired end-to-end on the Settings screen — live language switch, English default, background-tab propagation, and restart/logout persistence, all proven by automated unit/widget/integration tests.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 2 (Task 1 tracer, Task 2 auto)
- **Files modified:** 18 (11 created, 7 modified)

## Accomplishments

- Full ARB/gen-l10n pipeline (`l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_ru.arb`, generated `lib/generated/app_localizations.dart`) seeded with D-07's 8-string Settings-screen table
- `LocaleController` (`lib/providers/locale_provider.dart`) — async `@riverpod` class backed by `SharedPreferences`, mirroring `ThemeController`'s shape; defaults to English, falls back to English for unsupported persisted codes, and stays consistent under rapid back-to-back `setLocale()` calls
- `lib/app.dart`'s `MaterialApp` bound to `localeControllerProvider` via `locale.when(data/loading/error)`, with `localizationsDelegates`/`supportedLocales` registered
- Settings screen Language section: a nested `RadioGroup<Locale>` (not the deprecated per-tile `groupValue`/`onChanged`) with static native-name labels ("English"/"Русский", D-06) that never change with locale
- `AuthSession.signOut()` documented (D-04, no behavior change) and regression-tested to never clear `'app_locale'`
- Full automated test coverage: unit tests for `LocaleController`, a widget test proving the live switch within the Settings screen alone, and a full-app integration test proving English default, live switch, background `IndexedStack` tab propagation (ROADMAP Phase 12 success criterion 5), and restart persistence

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer — ARB/gen-l10n pipeline + LocaleController + live Settings-screen language switch** - `65a7b49` (feat)
2. **Task 2: Widget/integration coverage — live switch, background-tab propagation, restart persistence, fresh-install default, D-04 logout survival** - `fc09b44` (test)

## Files Created/Modified

- `pubspec.yaml` - added `flutter_localizations` (SDK), `intl ^0.20.2`, `shared_preferences ^2.2.0`; `generate: true`
- `l10n.yaml` - gen-l10n config (`arb-dir: lib/l10n`, `output-dir: lib/generated`, `synthetic-package: false`)
- `lib/l10n/app_en.arb` / `lib/l10n/app_ru.arb` - D-07's 8-string ARB seed (Settings screen)
- `lib/generated/app_localizations.dart` (+ `_en`/`_ru` locale files) - generated by `flutter gen-l10n`
- `lib/providers/locale_provider.dart` (+ `.g.dart`) - `LocaleController`, SharedPreferences-backed
- `lib/app.dart` - `MaterialApp` bound to `localeControllerProvider`, localization delegates registered
- `lib/features/settings/settings_screen.dart` - Language section (nested `RadioGroup<Locale>`), Theme section strings moved to ARB
- `lib/providers/auth_provider.dart` - D-04 doc comment on `signOut()`, no behavior change
- `test/providers/locale_provider_test.dart` - unit tests for `LocaleController` default/persist/fallback/concurrency
- `test/features/settings/settings_screen_test.dart` - widget tests for the live switch within Settings alone
- `test/locale_live_switch_test.dart` - full-app integration tests (English default, live switch, background-tab propagation, restart persistence)
- `test/providers/auth_provider_test.dart` - D-04 regression test (`signOut()` doesn't clear `'app_locale'`)
- `test/widget_test.dart`, `test/offline_cross_tab_test.dart` - Rule 1 fix: mock `SharedPreferences` before pumping `CadenceApp`

## Decisions Made

- `intl: ^0.20.2` instead of RESEARCH.md/UI-SPEC.md's suggested `^0.19.0` — the installed `flutter_localizations` SDK package pins `intl` to exactly `0.20.2`; the caret constraint on `^0.19.0` would have conflicted with that pin and failed `flutter pub get` (documented in 12-01-PLAN.md's "Resolved Conflicts" #1)
- AppBar title localized via `appBarSettingsTitle` in this phase per D-07 and Pattern 3, resolving an inconsistency where UI-SPEC.md's prose sections suggested deferring it to Phase 13 while its own ARB table and D-07 already included it
- Nested `RadioGroup<Locale>` for the Language tiles instead of per-tile `groupValue`/`onChanged`, since both are `@Deprecated` in the installed Flutter SDK (3.44.9) in favor of ambient `RadioGroup` ancestors
- Background-tab propagation (ROADMAP Phase 12 success criterion 5) and restart/logout persistence elevated from UI-SPEC.md's "backstop/manual" framing to automated tests in `test/locale_live_switch_test.dart`, since the underlying mechanism was testable today without waiting on Phase 13's string sweep

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `CadenceApp`-pumping tests hung on the real SharedPreferences platform channel**

- **Found during:** Task 2 full-suite verification (`flutter test`)
- **Issue:** `test/widget_test.dart` and `test/offline_cross_tab_test.dart` pump `CadenceApp` directly without mocking `SharedPreferences`. Once Task 1 wired `localeControllerProvider` (SharedPreferences-backed) into `CadenceApp`, both pre-existing tests hit `pumpAndSettle timed out` — `SharedPreferences.getInstance()` never resolves against an unmocked platform channel in the test harness.
- **Fix:** Added `SharedPreferences.setMockInitialValues({})` before each `CadenceApp` pump in both files (in `widget_test.dart`'s `setUp()`, inline in `offline_cross_tab_test.dart`'s single `testWidgets`).
- **Files modified:** `test/widget_test.dart`, `test/offline_cross_tab_test.dart`
- **Verification:** Full suite (`flutter test`) green — 436/436 passing, no timeouts.
- **Committed in:** `fc09b44` (Task 2 commit)

**2. [Rule 3 - Blocking] `settings_screen_test.dart`'s first draft didn't bind `MaterialApp.locale` to the provider**

- **Found during:** Task 2, writing `test/features/settings/settings_screen_test.dart`
- **Issue:** The first draft pumped a plain `MaterialApp` (no `locale:` param) wrapping `SettingsScreen`. Tapping "Русский" updated `localeControllerProvider`'s state correctly, but `AppLocalizations.of(context)` still resolved to English — `MaterialApp.locale` was never bound to the provider, so the widget under test had no way to receive the new locale (unlike `CadenceApp`, which does this binding internally).
- **Fix:** Added a small `_TestApp` `ConsumerWidget` in the test file that watches `localeControllerProvider` and binds it to `MaterialApp.locale` via the same `locale.when(...)` pattern as `lib/app.dart`, matching what the real app does.
- **Files modified:** `test/features/settings/settings_screen_test.dart`
- **Verification:** All 3 tests in the file pass.
- **Committed in:** `fc09b44` (Task 2 commit)

**3. [Rule 1 - Bug] `tester.pageBack()` failed platform-back-button-type detection**

- **Found during:** Task 2, writing the background-tab-propagation test in `test/locale_live_switch_test.dart`
- **Issue:** `tester.pageBack()` looks for a platform-specific back button widget type (Material vs. Cupertino) based on the ambient theme/platform; in this test harness it failed to find either, throwing "one back button expected on screen."
- **Fix:** Replaced with a direct `Navigator.of(tester.element(find.byType(SettingsScreen))).pop()`, which pops the pushed route without depending on back-button-widget-type detection.
- **Files modified:** `test/locale_live_switch_test.dart`
- **Verification:** Test passes.
- **Committed in:** `fc09b44` (Task 2 commit)

**4. [Rule 1 - Bug] Second `pumpWidget(buildApp())` didn't simulate a real app restart**

- **Found during:** Task 2, writing the restart-persistence test in `test/locale_live_switch_test.dart`
- **Issue:** Calling `tester.pumpWidget(buildApp())` a second time with the same widget-tree shape reuses the existing `Element`/`State` tree (same `ProviderContainer`, same `Navigator` route stack) instead of tearing it down — so the test was still on the pushed `SettingsScreen` route from before, not back at a fresh `Home` tab, and `find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile'))` found nothing (no `NavigationBar` on a pushed detail route).
- **Fix:** Pump an unrelated throwaway widget (`SizedBox.shrink()`) between the two `CadenceApp` pumps to force full teardown of the old tree before pumping the "restarted" app, so the new pump gets a genuinely fresh `ProviderContainer` and `Navigator` (reading the same underlying `SharedPreferences`/`TokenStorage` mock stores, which are static and outlive the element tree).
- **Files modified:** `test/locale_live_switch_test.dart`
- **Verification:** Test passes; confirmed the new tree starts fresh at the Home tab and correctly shows "Настройки" without any radio tap.
- **Committed in:** `fc09b44` (Task 2 commit)

**5. [Rule 2 - Missing Critical] Per-locale generated files not in the plan's file list**

- **Found during:** Task 1, after `build_runner`/`flutter pub get` ran gen-l10n
- **Issue:** `flutter gen-l10n` generates `lib/generated/app_localizations_en.dart` and `lib/generated/app_localizations_ru.dart` alongside `app_localizations.dart`; the plan's `files_modified` list only named the latter, but the per-locale files are required imports of the main generated file and must be committed to match the tracked `.g.dart`/generated-file convention already established in this codebase.
- **Fix:** Committed all three generated files together.
- **Files modified:** `lib/generated/app_localizations_en.dart`, `lib/generated/app_localizations_ru.dart`
- **Verification:** `flutter analyze` clean; app builds and imports resolve.
- **Committed in:** `65a7b49` (Task 1 commit)

---

**Total deviations:** 5 auto-fixed (3 Rule 1 bug fixes, 1 Rule 3 blocking fix, 1 Rule 2 missing-critical addition)
**Impact on plan:** All fixes were necessary to make the plan's own test requirements pass and to keep the pre-existing 401+ test suite green after introducing a SharedPreferences dependency into the app root. No scope creep — no functionality was added beyond what the plan specified.

## Issues Encountered

None beyond the auto-fixed deviations above — all resolved within the standard deviation-rule process.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The ARB/gen-l10n pipeline, `LocaleController`, and the `locale.when()`/`RadioGroup<Locale>` propagation pattern are all proven end-to-end and ready for Phase 13's full app-wide string-extraction sweep.
- `flutter analyze && flutter test` is green project-wide (436 tests passing, 0 analyze issues).
- No blockers for Phase 13 (String Extraction & Screen Localization) or Phase 14 (API Error Localization) — both depend only on this phase's infrastructure, which is fully wired.

## Self-Check: PASSED

All 15 files created/modified this plan verified present on disk; both task commits (`65a7b49`, `fc09b44`) verified present in git history.

---
*Phase: 12-locale-i18n-infrastructure*
*Completed: 2026-08-25*
