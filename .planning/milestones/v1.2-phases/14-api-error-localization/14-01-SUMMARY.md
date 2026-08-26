---
phase: 14-api-error-localization
plan: 01
subsystem: api
tags: [flutter, dart, i18n, arb, gen-l10n, error-handling]

# Dependency graph
requires:
  - phase: 12-locale-i18n-infrastructure
    provides: LocaleController, ARB/gen-l10n pipeline, live locale-switch mechanism
provides:
  - "ApiExceptionLocalization extension on ApiException (localizedMessage(l10n, {overrides}))"
  - "5 new commonErrorX ARB keys (EN+RU) mapped to the ErrorCode enum"
  - "CreateBandScreen wired to the shared extension as the first of ~20 catch sites"
affects: [14-02, 14-03, 14-04]

# Actuals (#2632)
actuals:
  tokens: 2186
  tasks: 1
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ApiException localization via a Dart extension (ApiExceptionLocalization), not a service locator or subclass"
    - "Extension's optional overrides map lets screen-specific error wording (login, change-password) route through the same call shape as the generic 20-site default"

key-files:
  created: []
  modified:
    - lib/api/api_exception.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - lib/features/bands/create_band_screen.dart
    - test/features/bands/create_band_screen_test.dart

key-decisions:
  - "Extension method signature is localizedMessage(AppLocalizations l10n, {Map<String, String>? overrides}) — a plain named-parameter map, not a Function-valued map, since D-04's override use case only needs static per-code strings"
  - "switch's default case returns raw message, matching D-05's explicit unmapped-code fallback; no case can silently fall through to a blank/generic substitute"

patterns-established:
  - "Pattern: on ApiException catch (e) { setState(() => _errorMessage = e.localizedMessage(l10n)); } replaces the old on ApiException catch (e) { setState(() => _errorMessage = e.message); } at every catch site — Wave 2 (14-02/14-03/14-04) applies this verbatim to the remaining ~19 sites"

requirements-completed: [I18N-05]

coverage:
  - id: D1
    description: "ApiExceptionLocalization.localizedMessage() extension maps the 5 known ErrorCode values to localized ARB messages, supports a per-code override map, and falls back to raw e.message for null/unmapped codes"
    requirement: I18N-05
    verification:
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#a createBand() failure with a known error code renders the localized generic message instead of the raw server text"
        status: pass
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#a createBand() failure renders an inline error and re-enables the Create button"
        status: pass
    human_judgment: false
  - id: D2
    description: "CreateBandScreen's ApiException catch site is wired to the shared extension as the tracer proof for the remaining ~19 sites"
    requirement: I18N-05
    verification:
      - kind: unit
        ref: "flutter test test/features/bands/create_band_screen_test.dart (9 tests, all passing)"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-26
status: complete
---

# Phase 14 Plan 01: ApiException Localization Extension + CreateBandScreen Tracer Summary

**Shared `ApiExceptionLocalization.localizedMessage()` extension mapping the 5-value `ErrorCode` enum to localized ARB messages, proven end-to-end on `CreateBandScreen` with a passing RED/GREEN widget test.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-26T18:01:00Z (approx.)
- **Completed:** 2026-08-26T18:08:46Z
- **Tasks:** 1
- **Files modified:** 8

## Accomplishments
- `ApiExceptionLocalization` extension on `ApiException` added in `lib/api/api_exception.dart`, exposing `String localizedMessage(AppLocalizations l10n, {Map<String, String>? overrides})` that maps `invalid_input`/`not_found`/`permission_denied`/`operation_rejected`/`already_exists` to 5 new ARB keys, checks an optional override map first, and falls back to raw `e.message` for `null` or unrecognized codes (D-01 through D-05)
- 5 new `commonErrorX` ARB keys added to both `app_en.arb` and `app_ru.arb` in plain/literal tone matching the existing `commonX` style; `flutter gen-l10n` regenerated `lib/generated/app_localizations*.dart` with the typed getters
- `CreateBandScreen`'s `on ApiException catch (e)` block now calls `e.localizedMessage(l10n)` instead of showing raw `e.message`
- New widget test proves a `not_found` error renders `commonErrorNotFound` (not raw server text); pre-existing `'code': 'bad_request'` test verified unchanged as the fallback-to-raw-text regression proof

## Task Commits

Each task was committed atomically following the TDD RED/GREEN cycle (task carried `tdd="true"`):

1. **Task 1 (RED): failing widget test** - `c2a7733` (test) — added the new "known error code" test; confirmed it fails to compile against the pre-extension codebase (`commonErrorNotFound` getter undefined)
2. **Task 1 (GREEN): extension + ARB keys + gen-l10n + CreateBandScreen wiring** - `cad4abe` (feat) — implementation makes the RED test (and the full 9-test suite) pass

_No REFACTOR commit needed — no post-GREEN cleanup required._

## Files Created/Modified
- `lib/api/api_exception.dart` - Adds `ApiExceptionLocalization` extension with `localizedMessage()`
- `lib/l10n/app_en.arb` / `lib/l10n/app_ru.arb` - 5 new `commonErrorX` keys (EN+RU)
- `lib/generated/app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_ru.dart` - Regenerated via `flutter gen-l10n`
- `lib/features/bands/create_band_screen.dart` - Catch site now calls `e.localizedMessage(l10n)`
- `test/features/bands/create_band_screen_test.dart` - New test for the known-error-code path

## Decisions Made
- Override mechanism implemented as `Map<String, String>? overrides` (static string values), not a function map — sufficient for the 2 known override use cases (login's `already_exists`, change-password's `invalid_input`) that Wave 2's 14-03 plan will wire up
- `switch`'s `default:` branch returns `message` directly, giving the D-05 fallback a single, auditable code path with no risk of an unhandled-case exception

## Deviations from Plan

None — plan executed exactly as written. The plan's `<action>` specified the extension signature, ARB key names/values, gen-l10n regeneration, the CreateBandScreen catch-site change, and the new test almost verbatim; all were implemented as described.

## Issues Encountered

None. `flutter gen-l10n` printed a harmless deprecation notice about the `synthetic-package` argument (ignored because `l10n.yaml` governs config) but completed successfully. `flutter analyze` reported no new issues after the change.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The `ApiExceptionLocalization` extension, its `overrides` parameter, and the 5 ARB keys are established and ready for the remaining ~19 catch sites (Wave 2: 14-02, 14-03, 14-04) to adopt verbatim
- 14-03 will refactor the 2 pre-existing screen-specific overrides (`login_screen.dart`, `change_password_screen.dart`) to route through `overrides` per D-04 — not touched in this plan
- No blockers identified

---
*Phase: 14-api-error-localization*
*Completed: 2026-08-26*

## Self-Check: PASSED

All 8 modified/created files confirmed present on disk; both commits (`c2a7733` test/RED, `cad4abe` feat/GREEN) confirmed present in git log.
