# Phase 17: API Contract Sync - Context

**Gathered:** 2026-08-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Sync the client's search wiring and password validation to the backend's already-updated `publicapi.yml` contract:

1. `ListUserTracks`/`ListUserSetlists` flip from stale client-side `POST`+body to the schema's `GET`+`SearchQuery` query param (mirroring the `ListBandTracks` migration already done in Phase 10).
2. Real search UI ships on the global Tracks and Setlists tabs (currently absent — `searchQuery` exists in the provider signatures but is never called with a value).
3. The setlist track picker (`AddSetlistTracksDialog`) stops discarding its debounced network search response and actually renders it while online; the offline substring fallback stays for the no-network case.
4. Password minLength-8 client-side validation is corrected — it already exists on both Register and Change Password, but the Register/Login field is shared by both modes and currently blocks *login* too (bug fix, not new validation).

</domain>

<decisions>
## Implementation Decisions

### Search UI scope
- **D-01:** Add real search boxes to the global Tracks tab and Setlists tab (`track_list_screen.dart`, `setlist_list_screen.dart` or their screen wrappers), wired to the migrated GET+`searchQuery` endpoints — not a wire-only migration. — **Reversibility:** reversible — pure UI addition, no schema change.
- **D-02:** Reuse the existing debounce pattern from `AddSetlistTracksDialog._onSearchChanged` (immediate local `setState`, 300ms `Timer`-debounced network call, only fired while online) for the new tab search boxes, for consistency across the app's three search surfaces.

### Setlist track picker fix
- **D-03:** `AddSetlistTracksDialog` must stop discarding its debounced `listBandTracks(searchQuery: ...)` response (`.catchError((_) => <Map<String,dynamic>>[])` with the result unused, per the existing D-05 comment in `add_setlist_tracks_dialog.dart:66-83`) and instead render the server results while online. Offline stays on `trackMatchesSearchQuery` client-side substring filtering — this is a genuine no-network fallback, not a "backend doesn't support it yet" workaround, and is unaffected by this phase.

### Password validation
- **D-04:** Fix `LoginScreen`'s shared password field so the `length < 8` validator only applies in sign-up (`_AuthMode.signUp`) mode; login mode requires only non-empty. Prevents a pre-existing user with a shorter, previously-valid password from being locked out client-side before the request ever reaches the server. — **Reversibility:** reversible.
- **D-05:** `ChangePasswordScreen`'s existing `length < 8` validator on the new-password field is already correct as-is — no change needed there.

### Claude's Discretion
- Exact placement of the new search boxes on Tracks/Setlists tabs (e.g., `AppBar` search action vs. inline `TextField` above the list) — follow whatever layout convention is closest to `AddSetlistTracksDialog`'s existing search field for visual consistency.
- Empty-search-results copy/localization key naming — reuse or extend existing ARB patterns.
- Query-parameter encoding/casing details for the `POST`→`GET` migration on `listUserTracks`/`listUserSetlists` — mirror `listBandTracks`'s existing query-param handling exactly.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API contract
- `lib/api/publicapi.yml` — source of truth. `ListUserTracks` (line 396-414), `ListUserSetlists` (line 416-434), and `ListBandTracks` (line 295-313) all already use the shared `SearchQuery` component (`#/components/parameters/SearchQuery`, line 659-665, case-insensitive substring match, `in: query`, optional). `RegisterRequestBody.password` (line 696-707) and `ChangePasswordRequestBody`'s equivalent (line ~759) both already declare `minLength: 8`.

### Requirements
- `.planning/REQUIREMENTS.md` — API-01 (search migration), API-02 (password minLength) under "### API Contract Sync"
- `.planning/ROADMAP.md` §"Phase 17: API Contract Sync" — goal and 4 success criteria

### Prior phase precedent
- `.planning/phases/16-track-terminology-rename/16-CONTEXT.md` — confirms Phase 16 deliberately left `publicapi.yml`'s `Songs` tag untouched, deferred here; not relevant to search/password work but explains why the rename doesn't reappear in this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/api/public_api.dart:173-185` (`listBandTracks`) — the already-correct GET+query-param pattern to mirror for `listUserTracks`/`listUserSetlists` (currently at lines 281-292 and ~437-446, both still `POST` with `body: {'searchQuery': ?searchQuery}`).
- `lib/features/setlists/add_setlist_tracks_dialog.dart:18-23` (`trackMatchesSearchQuery`) — existing case-insensitive substring matcher, already used for the offline fallback; reusable if the new tab search boxes also want an offline substring fallback for parity with the picker.
- `lib/features/setlists/add_setlist_tracks_dialog.dart:55-84` — full debounce/online-gating pattern (`_searchController`, `_debounceTimer`, 300ms `Timer`, `isOnlineProvider` gate) to copy for the new tab search UIs.
- `lib/features/profile/change_password_screen.dart:111-116` and `lib/features/auth/login_screen.dart:136-138` — existing `commonAtLeast8Chars` l10n key and validator shape to reuse/fix.

### Established Patterns
- `lib/providers/tracks_provider.dart:311` / `lib/providers/setlists_provider.dart:432` — current call sites of `listUserTracks`/`listUserSetlists`; neither passes `searchQuery` today. Adding tab search UI means these call sites (or a new debounced sibling call, following the picker's "discard shared cache" pattern) need to change.
- Per Key Decisions in PROJECT.md: "behavioral changes (even small formatter fixes) must land as their own reviewed diff, not bundled into a string-extraction phase" — the login-validator bug fix (D-04) is a small, isolated, well-justified behavior change and fits cleanly within this phase's own scope (API-02), not a foreign bundle.

### Integration Points
- `ApiClient.send()` (shared HTTP layer) already supports `queryParameters` — no client infrastructure gap, just call-site changes in `public_api.dart`.

</code_context>

<specifics>
## Specific Ideas

No specific UI mockup or exact copy was requested — user confirmed both scope questions with the recommended (fuller) option and left execution details to Claude's discretion (see above).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. No scope-creep suggestions arose.

</deferred>

---

*Phase: 17-API Contract Sync*
*Context gathered: 2026-08-27*
