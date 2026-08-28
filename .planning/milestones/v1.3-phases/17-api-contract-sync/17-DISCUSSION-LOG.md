# Phase 17: API Contract Sync - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-27
**Phase:** 17-API Contract Sync
**Areas discussed:** Search UI scope, Login validator bug

---

## Search UI scope

Discovered via codebase scout: `publicapi.yml` already has `ListUserTracks`/`ListUserSetlists` on `GET`+shared `SearchQuery` param, but `public_api.dart` still calls them as `POST`+body, and no provider caller ever passes a `searchQuery` value — the global Tracks/Setlists tabs have no search UI at all, despite the roadmap's Phase 17 success criteria implying search already exists there.

| Option | Description | Selected |
|--------|-------------|----------|
| Add search boxes | Migrate POST→GET AND add a search TextField to the global Tracks/Setlists tabs, wired to the new GET+searchQuery param | ✓ |
| Wire-only migration | Only flip the two endpoints from POST+body to GET+query param; searchQuery stays unused until a future phase adds UI | |

**User's choice:** Add search boxes (recommended option)
**Notes:** None — user accepted the recommendation as presented.

---

## Login validator bug

Discovered via codebase scout: `LoginScreen`'s password `TextFormField` is shared between login and sign-up mode (`_AuthMode`), and its `length < 8` validator runs unconditionally — so a pre-existing user with a shorter password (valid before this rule existed) would be blocked from even attempting login, client-side, before any request reaches the server.

| Option | Description | Selected |
|--------|-------------|----------|
| Fix it now | Make the length-8 validator apply only in sign-up mode; login mode requires only non-empty | ✓ |
| Leave as-is | Out of scope for this phase; note as a carried-over bug for later | |

**User's choice:** Fix it now (recommended option)
**Notes:** Directly tied to API-02 (password minLength requirement), so fixing it here rather than deferring keeps the behavior change in the same reviewed diff as the rule it's paired with.

---

## Claude's Discretion

- Exact placement/layout of the new Tracks/Setlists tab search boxes (AppBar action vs. inline TextField)
- Empty-search-results copy/localization key naming
- Query-parameter encoding details for the POST→GET migration (mirror `listBandTracks`'s existing handling)

## Deferred Ideas

None — discussion stayed within phase scope.
