# Phase 14: API Error Localization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-26
**Phase:** 14-API Error Localization
**Areas discussed:** Mapping strategy, Lookup shape, Message tone, Override refactor

---

## Mapping strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Generic + keep overrides | One shared localized message per code (5 generic ARB keys) wired at all ~20 sites as default; the 2 existing screen-specific overrides stay on top since they're more precise than generic text. | ✓ |
| Generic everywhere, drop overrides | Replace the 2 existing screen-specific messages with the generic per-code message too — simpler, single source of truth, but login/change-password lose their more helpful specific wording. | |
| Fully generic, no code distinction | One single localized "Something went wrong" style message for any ApiException with a known code, ignoring which of the 5 codes it is. | |

**User's choice:** Generic + keep overrides
**Notes:** Recommended option accepted without discussion.

---

## Lookup shape

| Option | Description | Selected |
|--------|-------------|----------|
| Extension on ApiException | e.g. `e.localizedMessage(l10n)` — takes AppLocalizations as a param, called at each catch site same as today's e.message, minimal diff per site. | ✓ |
| Top-level helper function | e.g. `apiErrorMessage(l10n, e)` — free function instead of extension method, same call-site shape otherwise. | |
| Claude's discretion | No strong preference — let the planner/researcher pick the idiomatic Dart shape. | |

**User's choice:** Extension on ApiException
**Notes:** Recommended option accepted without discussion.

---

## Message tone

| Option | Description | Selected |
|--------|-------------|----------|
| Plain/literal | Direct translation of the code's meaning — "You don't have permission to do this", "This action isn't allowed", "Not found". Matches existing terse style (commonConnectionError, commonSomethingWentWrong). | ✓ |
| Softer/apologetic | Friendlier phrasing — "Sorry, you can't do that right now", etc. More conversational than the app's current error copy. | |

**User's choice:** Plain/literal
**Notes:** Recommended option accepted without discussion.

---

## Override refactor

| Option | Description | Selected |
|--------|-------------|----------|
| Refactor into extension | Extension takes an optional override map/param so both sites call the same helper, e.g. `e.localizedMessage(l10n, overrides: {...})` — one consistent call shape everywhere, no orphaned duplicate logic. | ✓ |
| Leave as-is, untouched | The 2 existing if/else blocks stay exactly as they are today; only the ~18 raw-message sites get wired to the new extension. Less churn, but two different error-handling shapes coexist. | |

**User's choice:** Refactor into extension
**Notes:** Recommended option accepted without discussion.

---

## Claude's Discretion

- Exact ARB key names for the 5 generic messages (follow `commonX` convention)
- Exact override-mechanism shape on the extension (named param vs map)
- Whether the new generic error keys get added to `test/test_strings.dart`
- Exact EN/RU wording for each of the 5 generic messages, within the plain/literal tone

## Deferred Ideas

None — discussion stayed within phase scope.
