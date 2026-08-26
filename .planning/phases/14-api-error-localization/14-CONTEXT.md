# Phase 14: API Error Localization - Context

**Gathered:** 2026-08-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Every `on ApiException catch (e)` site across the app (~20, in screens and dialogs) shows a localized message for the 5 codes the API defines (`invalid_input`, `not_found`, `permission_denied`, `operation_rejected`, `already_exists` — all only present on 400 responses per `BadRequestResponseBody`/`ErrorCode` in `publicapi.yml`); any `ApiException` without a recognized `code` (null code, or a future code not in the enum) still shows `e.message` (raw server text) exactly as it does today. This phase does NOT touch the two existing `catch (_)` non-ApiException fallback branches (already localized in Phase 13, e.g. `createSetlistFailedError`), does NOT touch the 401-based `loginInvalidCredentialsError` special case (statusCode-driven, not code-driven — already localized, out of this phase's "error code" scope), and does NOT change server-side error responses.

</domain>

<decisions>
## Implementation Decisions

### Mapping strategy
- **D-01:** One shared generic localized ARB message per one of the 5 `ErrorCode` values, wired as the default at all ~20 `on ApiException catch (e)` sites. The 2 existing screen-specific overrides (login's `already_exists` → "This username is already taken", change-password's `invalid_input` → "Current password is incorrect") stay on top of the generic default — they're more precise for their specific context than a generic "Invalid input" would be.
- **D-02:** Generic message tone is plain/literal, matching the app's existing terse error copy style (`commonConnectionError`, `commonSomethingWentWrong`) — not softened/apologetic phrasing.

### Lookup shape
- **D-03:** Implemented as an extension on `ApiException` (e.g. `e.localizedMessage(l10n)`), taking `AppLocalizations` as a parameter — mirrors the existing `AppLocalizations.of(context)!` access pattern already used at every catch site, minimal diff per call site, no service locator (respects the project's DI-only architectural constraint).
- **D-04:** The 2 existing screen-specific overrides (login, change-password) get refactored to route through this same extension via an optional override mechanism (e.g. a per-code override param/map), rather than staying as separate untouched if/else blocks. One consistent call shape across all ~20 sites — no orphaned duplicate error-handling logic.

### Fallback (confirms REQUIREMENTS.md I18N-05, not re-decided)
- **D-05:** `ApiException` with `code == null` (network/parse failures, non-400 statuses without a body) or a `code` value outside the 5-value enum (future API drift) falls back to raw `e.message` exactly as every catch site does today — no blank state, no generic failure message substituted for it.

### Claude's Discretion
- Exact ARB key names for the 5 generic messages — follow the existing flat-namespace scoped-prefix convention (`commonX` for cross-screen shared strings, per Phase 13's D-01/D-02).
- Exact override-mechanism shape on the extension (named optional param vs `Map<String, String Function()>` vs similar) — implementation detail, no product-visible impact as long as the 2 existing overrides keep their current wording.
- Whether/how the new generic error keys get added to `test/test_strings.dart`'s `tester.strings` extension (Phase 13 pattern) — follow existing convention if tests need to assert on the new copy.
- Exact English/Russian wording for each of the 5 generic messages, within the plain/literal tone locked by D-02.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — I18N-05 (source requirement for this phase)
- `.planning/ROADMAP.md` §"Phase 14: API Error Localization" — goal, 3 success criteria, dependency on Phase 12 only

### API contract
- `lib/api/publicapi.yml` lines 655-682 — `BadRequestResponseBody`/`ErrorCode` schema: the 5 known codes, all scoped to 400 responses only

### Prior phase context
- `.planning/phases/12-locale-i18n-infrastructure/12-CONTEXT.md` — `LocaleController`, ARB/gen-l10n pipeline, live-switch mechanism this phase's messages must respect (success criterion 3: switching language changes error-message language)
- `.planning/phases/13-string-extraction-screen-localization/13-CONTEXT.md` — D-01/D-02 shared-key `commonX` naming convention, D-05/D-06 test-strings utility shape (`tester.strings.X`) to extend if needed
- `.planning/PROJECT.md` §Key Decisions — Riverpod/`@riverpod` codegen pattern; DI-only, no service locators; "behavioral changes must land as their own reviewed diff" (Phase 13 review learning — this phase IS a behavioral change, not a pure string swap, so treat it as such, not bundle with unrelated cleanup)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/api/api_exception.dart` — `ApiException` class (`statusCode`, `code`, `message`) is the extension target for D-03
- `lib/l10n/app_en.arb` / `app_ru.arb` — existing flat ARB files with `commonX` shared-key precedent (`commonRetry`, `commonConnectionError`, `commonSomethingWentWrong`) to extend with the 5 new generic error keys

### Established Patterns
- Every catch site follows `} on ApiException catch (e) { setState(() => _errorMessage = e.message); }` (or with a `catch (_)` fallback after it for non-ApiException failures) — `AppLocalizations.of(context)!` is already in scope at every one of these sites via existing `l10n` locals
- Only `lib/features/auth/login_screen.dart` (400/`already_exists`, and separately 401 statusCode) and `lib/features/profile/change_password_screen.dart` (400/`invalid_input`) currently branch on `e.code`/`e.statusCode` — every other ~18 site (`create_band_screen.dart`, `edit_band_screen.dart`, `confirm_leave_band_dialog.dart`, `confirm_delete_band_dialog.dart`, `confirm_remove_member_dialog.dart`, `confirm_rotate_invite_code_dialog.dart`, `confirm_transfer_ownership_dialog.dart`, `join_band_dialog.dart`, `create_track_screen.dart`, `edit_track_screen.dart`, `confirm_delete_track_dialog.dart`, `create_setlist_screen.dart`, `edit_setlist_screen.dart`, `setlist_detail_screen.dart`, `confirm_delete_setlist_dialog.dart`, `add_setlist_tracks_dialog.dart`) just shows `e.message` raw

### Integration Points
- `lib/api/api_client.dart:56-58` — 403 responses trigger `onUnauthorized()` (auto sign-out) before throwing; the thrown `ApiException` rarely reaches a user-visible catch site since `AuthGate` swaps to `LoginScreen` first — not a target for this phase's mapping
- `lib/generated/app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_ru.dart` — regenerate via `flutter gen-l10n` after ARB additions, same pipeline proven in Phases 12-13

</code_context>

<specifics>
## Specific Ideas

No UI mockups requested. Discussion focused entirely on mapping strategy (generic-with-overrides vs full-generic), lookup shape (extension vs free function), message tone, and whether to refactor the 2 pre-existing screen-specific overrides into the new mechanism.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. All 4 discussed areas were implementation-decision clarifications (HOW to map known codes), not new capabilities.

</deferred>

---

*Phase: 14-API Error Localization*
*Context gathered: 2026-08-26*
