---
phase: 13-string-extraction-screen-localization
plan: 08
subsystem: ui
tags: [flutter, l10n, gen-l10n, riverpod]

# Dependency graph
requires:
  - phase: 13-01
    provides: offlineNoCacheTitle/offlineNoCacheDescription and all loginXxx ARB keys in app_en.arb/app_ru.arb, plus the generated AppLocalizations class
provides:
  - lib/widgets/offline_no_cache_view.dart fully localized (D-14 shared empty state, consumed by ~6 list screens)
  - lib/features/auth/login_screen.dart fully localized, including thrown-exception messages surfaced via _errorMessage (D-16 auth-boundary coverage)
affects: [13-string-extraction-screen-localization, any later phase touching offline empty states or the login/signup screen]

actuals:
  tokens: 1791
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Capture `final l10n = AppLocalizations.of(context)!;` inside a State method (not just build()) when a thrown-exception message needs localized text outside the widget tree callback — login_screen.dart's _submit() captures l10n before the async gap, using the State's own `context` getter."

key-files:
  created: []
  modified:
    - lib/widgets/offline_no_cache_view.dart
    - lib/features/auth/login_screen.dart

key-decisions:
  - "login_screen.dart's password validator reuses commonAtLeast8Chars (exact-match text with change_password_screen.dart's validator, per D-01) rather than introducing a dedicated loginPasswordValidator key."

patterns-established: []

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "offline_no_cache_view.dart renders both title and description strings via AppLocalizations instead of hardcoded English"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/bands/bands_screen_test.dart#offline with no cache shows OfflineNoCacheView, with no Retry button (D-06)"
        status: pass
      - kind: other
        ref: "flutter analyze lib/widgets/offline_no_cache_view.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "login_screen.dart renders every string via AppLocalizations, including the two thrown-exception messages surfaced through _errorMessage"
    requirement: I18N-04
    verification:
      - kind: other
        ref: "flutter analyze lib/features/auth/login_screen.dart"
        status: pass
      - kind: other
        ref: "grep -c 'l10n\\.' lib/features/auth/login_screen.dart == 11 (>= 8 required)"
        status: pass
    human_judgment: true
    rationale: "login_screen.dart has no dedicated widget test in this codebase (per plan's <objective> note); manual pump under Locale('ru') is the only way to confirm no English string remains, so this is not automatable at authoring time."

duration: 12min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 08: Offline Empty State + Login Screen Localization Summary

**Localized the shared offline-empty-state widget (consumed by ~6 list screens) and the login/signup screen, including its two thrown-exception error messages, using ARB keys landed by 13-01.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-26
- **Completed:** 2026-08-26
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `OfflineNoCacheView` (D-14) now renders `offlineNoCacheTitle`/`offlineNoCacheDescription` via `AppLocalizations.of(context)!` instead of hardcoded English — this single shared widget covers every consuming list screen at once.
- `LoginScreen` (D-16) fully localized: app title, username/password labels and validators, sign-up/log-in button text, mode-toggle text, and both thrown `ApiException` messages (`loginUsernameTakenError`, `loginInvalidCredentialsError`) surfaced through `_errorMessage`.
- Confirmed via existing test suite (`bands_screen_test.dart`, 22/22 passing) that `OfflineNoCacheView`'s localized strings render identically to the prior hardcoded English text under the default test locale — no regression in consuming screens' own test coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: offline_no_cache_view.dart** - `d7ea47f` (feat)
2. **Task 2: login_screen.dart** - `ad1efe7` (feat)

**Plan metadata:** (this commit, docs)

## Files Created/Modified
- `lib/widgets/offline_no_cache_view.dart` - Added `AppLocalizations` import; replaced two hardcoded strings with `l10n.offlineNoCacheTitle`/`l10n.offlineNoCacheDescription`.
- `lib/features/auth/login_screen.dart` - Added `AppLocalizations` import; captured `l10n` in both `build()` and `_submit()`; replaced app title, field labels/validators, button text, toggle text, and both thrown-exception messages with `l10n.*` lookups; reused `commonAtLeast8Chars` for the password validator per D-01.

## Decisions Made
- Password validator in `login_screen.dart` reuses `commonAtLeast8Chars` (shared with `change_password_screen.dart`) rather than a dedicated `loginPasswordValidator` key, per the plan's explicit instruction and D-01's exact-match-text precedent.
- `l10n` is captured as a local in `_submit()` (an async `State` method, not `build()`) using the `State` object's own `context` getter — necessary because the thrown `ApiException` messages must be localized before/during the async request, not just at render time.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Both remaining always-visible/widely-consumed shared surfaces called out by CONTEXT.md's discretion section (D-14's `OfflineNoCacheView` and D-16's `LoginScreen`) are now fully localized. No hardcoded English string literal remains in either file. No ARB changes were needed — this plan only consumed keys already landed by 13-01. No blockers for subsequent plans in Phase 13.

## Self-Check: PASSED

- FOUND: lib/widgets/offline_no_cache_view.dart
- FOUND: lib/features/auth/login_screen.dart
- FOUND: d7ea47f
- FOUND: ad1efe7

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*
