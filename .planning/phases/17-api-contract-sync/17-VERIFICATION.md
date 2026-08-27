---
phase: 17-api-contract-sync
verified: 2026-08-27T00:00:00Z
status: passed
score: 12/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 17: API Contract Sync Verification Report

**Phase Goal:** The client's search behavior and password rules match the backend's updated `publicapi.yml` contract.

**Verified:** 2026-08-27
**Status:** PASSED
**Re-verification:** Initial verification

## Goal Achievement Summary

Phase 17 achieves its goal through three coordinated plans:

1. **API-01 (Plan 01 & 02):** Migrated `listUserTracks`/`listUserSetlists` from POST+body to GET+query parameters, wired real debounced, online-gated search on the global Tracks and Setlists tabs, and fixed the setlist track picker to render (not discard) online search results.

2. **API-02 (Plan 03):** Gated the LoginScreen password length validator to signup mode only, allowing login attempts with legacy short passwords to reach the server instead of being blocked client-side.

3. **CR-01 (Post-Review Fix):** Fixed `login_screen.dart` error handling to branch on the actual `400 invalid_input` error code the backend returns, not the impossible `401` status code the spec never produces for `/api/login`.

All must-haves verified, all success criteria achieved, all tests passing (477 total), no regressions.

---

## Observable Truths Verification

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `listUserTracks` and `listUserSetlists` send `GET` (not `POST`), matching the publicapi.yml `ListUserTracks`/`ListUserSetlists` `get:` operations | ✓ VERIFIED | `lib/api/public_api.dart` lines 280–297 and 443–460 both use `'GET'` with `queryParameters`, mirroring `listBandTracks` exactly; both methods' doc comments reference the `get:` operations in publicapi.yml |
| 2 | An empty or omitted search query sends no `searchQuery` query parameter at all | ✓ VERIFIED | `public_api.dart` lines 284–289 and 447–452 build `queryParameters` maps that omit `searchQuery` when null or empty (`final effectiveSearchQuery = (searchQuery != null && searchQuery.isNotEmpty) ? searchQuery : null`) |
| 3 | Typing in the Tracks tab's search TextField, while online, sends a debounced (300ms) GET request to `/api/track/list` with `searchQuery` as a query parameter | ✓ VERIFIED | `TracksScreen._onSearchChanged` (lines 55–75): arms a `Timer(const Duration(milliseconds: 300), ...)` that calls `ref.read(publicApiProvider).listUserTracks(bandIdFilter: ..., searchQuery: _searchQuery)` directly via publicApiProvider, bypassing cached providers; `test/features/tracks/tracks_screen_test.dart` widget tests confirm request.url carries `searchQuery` query parameter |
| 4 | Typing in the Setlists tab's search TextField, while online, sends a debounced (300ms) GET request to `/api/setlist/list` with `searchQuery` as a query parameter | ✓ VERIFIED | `SetlistsScreen._onSearchChanged` (lines 62–81) mirrors `TracksScreen` exactly: `Timer(300ms)` → `listUserSetlists(bandIdFilter: ..., searchQuery: _searchQuery)` via publicApiProvider; tests confirm behavior |
| 5 | Typing in either tab's search field while offline immediately narrows the currently-cached list via case-insensitive substring matching, with zero network calls attempted | ✓ VERIFIED | `TracksScreen._buildTracksBody` (lines 178–184): `if (!isOnline && _searchQuery.isNotEmpty)` filters `tracks` through `trackMatchesSearchQuery`, no publicApiProvider call; `SetlistsScreen` mirrors with `_setlistMatchesSearchQuery`; offline tests in both test files confirm zero additional network calls |
| 6 | An online search that returns zero results shows `commonNoSearchResults` (Tracks tab) / `commonNoSetlistSearchResults` (Setlists tab), distinct from the tab's true empty-band-state copy | ✓ VERIFIED | `TracksScreen._buildContent` (lines 209–211): `if (tracks.isEmpty && _searchQuery.isNotEmpty)` renders `l10n.commonNoSearchResults`; `SetlistsScreen._buildContent` similarly renders `l10n.commonNoSetlistSearchResults`; ARB keys added at `lib/l10n/app_en.arb` lines 78–79 and corresponding Russian translations; widget tests confirm both strings render when server returns `{'items': []}` |
| 7 | The full list stays visible during the 300ms debounce window (no loading spinner overlay), and a failed debounced search request leaves the previously-displayed results unchanged with no new error UI | ✓ VERIFIED | Debounced search sends directly via publicApiProvider with no UI state changes (no loading spinner) during debounce; failed requests have empty `.catchError((_) {})` handler (no error UI introduced); tests confirm `_serverSearchResults` is only updated on success |
| 8 | Offline substring matching uses Dart's built-in `String.toLowerCase().contains()` over UTF-16 code units, not grapheme clusters | ✓ VERIFIED | `trackMatchesSearchQuery` (lines 18–23 in `add_setlist_tracks_dialog.dart`): `(track['title'] as String).toLowerCase().contains(lowerQuery)`, using Dart's standard String methods (UTF-16 code units); identical pattern in `_setlistMatchesSearchQuery` (lines 23–27 in `setlists_screen.dart`) |
| 9 | `AddSetlistTracksDialog`'s debounced online search response is captured and rendered instead of being discarded | ✓ VERIFIED | `add_setlist_tracks_dialog.dart` lines 80–90: removed the old `.catchError((_) => <Map<String, dynamic>>[])` discard pattern; now stores result in `_serverSearchResults` via `.then((results) { setState(() => _serverSearchResults = results); })`; lines 166–171 show `_serverSearchResults` is used to populate `availableTracks` when online |
| 10 | Tracks already in `currentTrackIds` stay excluded from the checklist when the displayed source is the online server search response | ✓ VERIFIED | `add_setlist_tracks_dialog.dart` lines 166–171: even when `_serverSearchResults != null`, the list is filtered through `if (!widget.currentTrackIds.contains(track['id'] as String)) track`; test at lines 83–109 in test file confirms this exclusion applies to server results |
| 11 | In signup mode, a 7-character password is rejected and an 8-character password passes validation, matching publicapi.yml's `RegisterRequestBody.password minLength: 8` | ✓ VERIFIED | `LoginScreen` validator (lines 142–150): `if (isSignUp && (value == null || value.length < 8))` returns `l10n.commonAtLeast8Chars`; test case 3 in `login_screen_test.dart` confirms 7-char signup password shows error; test case 8+ char signup password passes validation |
| 12 | In login mode, a non-empty password under 8 characters is NOT blocked client-side — the login request reaches the server (proven by mocked 400 response surfacing `loginInvalidCredentialsError`, not `commonAtLeast8Chars`) | ✓ VERIFIED | `LoginScreen` validator: length check is gated on `isSignUp`, so login mode skips it; test case 1 in `login_screen_test.dart` confirms 7-char login password reaches server (mocked 400 response) and shows server error, not validator error |

---

## Requirements Coverage

| Requirement | Plan | Scope | Status | Evidence |
|-------------|------|-------|--------|----------|
| **API-01** | 01, 02 | `ListUserTracks`/`ListUserSetlists` migrate from POST+body to GET+SearchQuery; setlist track picker adopts shared SearchQuery contract and renders real server-side search | ✓ SATISFIED | All three GET methods use `queryParameters`; picker renders `_serverSearchResults`; all offline fallbacks intact |
| **API-02** | 03 | Registration and password-change forms enforce 8-char minimum client-side in signup/change modes only | ✓ SATISFIED | Login mode has no length gate; signup mode enforces 8-char minimum; ChangePasswordScreen untouched (already correct) |

**Traceability:** Both requirements from REQUIREMENTS.md Section "API Contract Sync" are mapped and satisfied. Note: REQUIREMENTS.md shows API-01 status as "Pending" but implementation is complete — this is likely a stale entry that needs updating (not part of this phase's verification scope, but flagged for awareness).

---

## Artifacts Verification

### Required Files (All Present & Substantive)

| Artifact | Purpose | Status | Details |
|----------|---------|--------|---------|
| `lib/api/public_api.dart` | HTTP API layer | ✓ VERIFIED | `listUserTracks`/`listUserSetlists` methods fully implemented with GET + queryParameters |
| `lib/features/tracks/tracks_screen.dart` | Global Tracks tab with search | ✓ VERIFIED | `ConsumerStatefulWidget` with `_searchController`, `_debounceTimer`, `_serverSearchResults` state; search TextField wired; debounce logic intact; offline fallback via `trackMatchesSearchQuery` |
| `lib/features/setlists/setlists_screen.dart` | Global Setlists tab with search | ✓ VERIFIED | Mirrors TracksScreen exactly; `_setlistMatchesSearchQuery` helper defined (lines 23–27); offline fallback on setlist name matching |
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | Setlist track picker with online search | ✓ VERIFIED | `_serverSearchResults` state added; online response rendered; offline fallback via `trackMatchesSearchQuery` preserved; currentTrackIds exclusion applied to both paths |
| `lib/features/auth/login_screen.dart` | Auth screen with password validation | ✓ VERIFIED | Password validator gates 8-char check on `isSignUp`; error handling branches on `code == 'invalid_input'` (CR-01 fix); register and login flows both use `publicApiProvider` |
| `lib/l10n/app_en.arb` / `app_ru.arb` | Localization strings | ✓ VERIFIED | `commonNoSearchResults`/`commonNoSetlistSearchResults` keys added at lines 78–79 with EN/RU translations |
| `lib/generated/app_localizations*.dart` | Generated localization bindings | ✓ VERIFIED | Regenerated via `flutter gen-l10n`; carries getter methods for new keys |

### Test Files (All Updated & Passing)

| Test File | Coverage | Status | Details |
|-----------|----------|--------|---------|
| `test/api/public_api_test.dart` | `listUserTracks`/`listUserSetlists` contract | ✓ VERIFIED | Updated to assert GET method + query-parameter contract (not POST body); groups mirror `listBandTracks` shape; all 16 tests pass |
| `test/features/tracks/tracks_screen_test.dart` | Tracks tab search | ✓ VERIFIED | 5 new widget tests: debounced GET, empty-results string, offline filtering, no extra network calls; all pass |
| `test/features/setlists/setlists_screen_test.dart` | Setlists tab search | ✓ VERIFIED | 5 widget tests mirroring Tracks tests (debounce, empty results by name, offline filtering); all pass |
| `test/features/setlists/add_setlist_tracks_dialog_test.dart` | Setlist picker online search fix | ✓ VERIFIED | 3 new tests: server results render (D-03), currentTrackIds exclusion on server results, online zero-results copy; all pass |
| `test/features/auth/login_screen_test.dart` | Password validation + error handling | ✓ VERIFIED | 4 new tests: login with short password reaches server (400 invalid_input), login with empty password shows `commonFieldRequired`, signup with short password shows `commonAtLeast8Chars`, signup with empty password shows `commonAtLeast8Chars` (not `commonFieldRequired`, proving check order); all 7 tests pass |
| `test/providers/tracks_provider_test.dart` | Provider integration | ✓ VERIFIED | Updated `listUserTracks` assertions from `everyElement('POST')` to `everyElement('GET')` to reflect GET migration |
| `test/providers/setlists_provider_test.dart` | Provider integration | ✓ VERIFIED | Updated `listUserSetlists` assertions from `everyElement('POST')` to `everyElement('GET')` |

---

## Key Links Verification

All critical wiring confirmed:

| From | To | Via | Status | Test Evidence |
|------|-----|-----|--------|--|
| `TracksScreen._onSearchChanged` | `listUserTracks(bandIdFilter:, searchQuery:)` | Direct `publicApiProvider` call, no cache layer | ✓ WIRED | `tracks_screen_test.dart` debounce test asserts request.url carries `searchQuery` parameter |
| `SetlistsScreen._onSearchChanged` | `listUserSetlists(bandIdFilter:, searchQuery:)` | Direct `publicApiProvider` call | ✓ WIRED | `setlists_screen_test.dart` debounce test confirms same pattern |
| `AddSetlistTracksDialog._onSearchChanged` | `listBandTracks(searchQuery:)` | Direct `publicApiProvider` call | ✓ WIRED | `add_setlist_tracks_dialog_test.dart` test confirms response renders (not discarded) |
| `LoginScreen._submit()` | Error handling on `ApiException` | Code branches on `code == 'invalid_input'` | ✓ WIRED | `login_screen_test.dart` test mocks 400 response with `invalid_input` code, confirms error message displays |

---

## Data-Flow Verification (Level 4)

Search results flow from server to UI:

| Feature | Request | Response Parsing | Rendered | Status |
|---------|---------|------------------|----------|--------|
| Tracks tab online search | GET `/api/track/list?searchQuery=...` | `response['items']` cast to `List<Map<String,dynamic>>` | Assigned to `_serverSearchResults`, used in `_buildContent` | ✓ FLOWING |
| Setlists tab online search | GET `/api/setlist/list?searchQuery=...` | Same parsing | Assigned to `_serverSearchResults`, used in `_buildContent` | ✓ FLOWING |
| Setlist picker online search | GET `/api/band/{bandId}/track/list?searchQuery=...` | Same parsing | Assigned to `_serverSearchResults`, rendered as `availableTracks` | ✓ FLOWING |

Offline searches use cached data (already-fetched lists) with no data source; no new data sourcing introduced.

---

## Anti-Patterns Check

**Scanning modified files for debt markers and stubs:**

- ✓ No `TBD`, `FIXME`, or `XXX` markers in phase-modified files
- ✓ No placeholder/stub implementations (all methods fully wired)
- ✓ No dead code branches introduced
- ✓ No hardcoded empty data (initial state fields properly initialized as `null` for "no search yet")

**Quality Issues Found (from code review, not blockers):**

| Issue | File | Severity | Impact | Status |
|-------|------|----------|--------|--------|
| WR-01: Debounced search race condition (out-of-order responses) | `tracks_screen.dart`, `setlists_screen.dart`, `add_setlist_tracks_dialog.dart` | WARNING | Slower earlier response can overwrite faster later response | Not fixed (advisory, not a blocker for API contract sync goal) |
| WR-02: Setlists search hint text mismatch ("Search by title or artist" but only searches name) | `setlists_screen.dart` line 124 | WARNING | UX clarity issue (hint doesn't match behavior) | Not fixed (advisory, scope creep) |
| WR-03: LoginScreen lacks generic `catch(_)` fallback like sibling `add_setlist_tracks_dialog.dart` | `login_screen.dart` | WARNING | Network errors don't show user message | Not fixed (scope deferred) |
| CR-01: 401 branch dead code → invalid_input code handling | `login_screen.dart` line 68–76 | CRITICAL → FIXED | Client branching on non-existent status | ✓ FIXED in commit 24ffbf8 |

The phase addresses CR-01 directly; WR-01/WR-02/WR-03 are documented quality improvements deferred to future work (not part of API-contract-sync goal).

---

## Test Results

**Full Suite:** 477 tests passed, zero failures, zero regressions

**Phase-Specific:**
- `flutter test test/api/public_api_test.dart` — 16 tests passed
- `flutter test test/features/tracks/tracks_screen_test.dart test/features/setlists/setlists_screen_test.dart` — 26 tests passed
- `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart` — new tests all pass
- `flutter test test/features/auth/login_screen_test.dart` — 7 tests passed
- `flutter analyze` — No issues (0 errors, 0 warnings)

**Behavioral Proof:**
- Online search: Real GET requests with `searchQuery` parameter captured in test mocks and confirmed in request assertions
- Offline search: Same list pre and post-keystroke, zero additional network calls recorded
- Empty results: Correct copy rendered (`commonNoSearchResults`, `commonNoSetlistSearchResults`, `addSetlistTracksNoMatch`)
- Password validation: Signup blocks < 8 chars; login allows any non-empty value; error codes map to correct messages

---

## Success Criteria Achievement

| Success Criterion | Status | Evidence |
|-------------------|--------|----------|
| User's cross-band Tracks and Setlists tab searches are served by real server-side filtering (GET + SearchQuery) instead of the client's offline substring filter | ✓ ACHIEVED | Both tabs have online GET calls to `/api/track/list` and `/api/setlist/list` with `searchQuery` parameter; offline fallback via substring filtering preserved as documented |
| The setlist track picker's search field sends the same shared SearchQuery contract as the two list endpoints | ✓ ACHIEVED | `AddSetlistTracksDialog` calls `listBandTracks(searchQuery:)`, which sends GET with same `SearchQuery` parameter contract as `ListUserTracks`/`ListUserSetlists` |
| User attempting to register or change their password with a password under 8 characters sees a client-side validation error before any request is sent | ✓ ACHIEVED | `LoginScreen` signup mode blocks < 8 chars with `commonAtLeast8Chars` error; `ChangePasswordScreen` already enforces this (unchanged, confirmed present) |
| All existing search/list tests are updated and passing against the new GET-based mocks, with zero regressions | ✓ ACHIEVED | 477 total tests pass; provider tests updated to assert GET (not POST); new tests added for search behavior; full suite clean |

---

## Commits in This Phase

| Commit | Message | Files | Status |
|--------|---------|-------|--------|
| 81847d9 | feat(17-01): migrate listUserTracks/listUserSetlists to GET, add Tracks tab search | 13 files | ✓ Verified |
| a4a3a8b | feat(17-01): add Setlists tab search, mirroring Tracks tab pattern | 3 files | ✓ Verified |
| c1f2c26 | feat(17-02): render server search results instead of discarding them (D-03) | 2 files | ✓ Verified |
| f58da92 | test(17-02): edge-case coverage for server search results | 1 file | ✓ Verified |
| b7ac5a0 | fix(17-03): gate LoginScreen password length validator to signup mode | 2 files | ✓ Verified |
| 24ffbf8 | fix(17): scope login error handling to the real 400 invalid_input contract (CR-01) | 2 files | ✓ Verified |

---

## Risk Assessment

### Mitigated Risks
- **T-17-01 (SQL Injection):** Backend owns query validation; client sends plain text, URI encoding is automatic
- **T-17-02 (Timing leak):** Inherent to search feature, no client mitigation required
- **T-17-03 (Untrusted response rendering):** Response shape already rendered elsewhere; no new trust boundary
- **T-17-04 (Signup length gate relaxation):** Mitigation provided by dedicated regression test (test case 3) proving signup still enforces 8-char
- **T-17-05 (Login permissiveness):** Intentional fix; server remains sole authority on credential correctness

### Unmitigated Warnings (Deferred)
- **WR-01:** Out-of-order debounced response race — advisory, not a blocker
- **WR-02:** Setlists search hint/behavior mismatch — UX clarity, scope deferred
- **WR-03:** LoginScreen missing generic error fallback — quality improvement, scope deferred

---

## Conclusion

**Phase Goal:** ✓ ACHIEVED

The client's search behavior and password rules now match the backend's updated `publicapi.yml` contract:

1. ✓ Search operations use GET + SearchQuery query parameters (API-01)
2. ✓ Password validation correctly gated to signup mode (API-02)
3. ✓ Login error handling branches on correct error code (CR-01 fix)
4. ✓ All tests passing (477), zero regressions
5. ✓ No blockers; advisories documented for future improvement

**Status:** PASSED

---

_Verified: 2026-08-27_
_Verifier: Claude (gsd-verifier)_
_Verification depth: Goal-backward from phase objective, all must-haves confirmed against codebase implementation_
