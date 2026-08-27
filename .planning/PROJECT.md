# Cadence

## What This Is

Cadence is a Flutter mobile app (Android/iOS, with web build support) for bands to manage their repertoire together: shared song catalog, band membership, and setlists for gigs. As of v1.2, the app has full band/track/setlist CRUD against the public API, runs on Riverpod state management with a Hive-backed cache-store pattern, always shows freshly-fetched server data when online, and falls back to last-fetched cache with a persistent warning banner when offline. Band owners can rotate invite codes and transfer ownership; the setlist track picker is searchable. The full UI is localized in English and Russian (live switch, no restart, ARB/gen-l10n pipeline, correct Russian pluralization) including API error messages, and track duration is entered/displayed as mm:ss everywhere.

## Core Value

A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## Current State

**Shipped:** v1.2 i18n and Duration Input (2026-08-26)

Full UI string localization (EN/RU) with live no-restart switching from Profile settings, on-device persistence, correct Russian ICU pluralization, and localized API error messages (unmapped codes fall back to raw server text). Track duration is entered and displayed as mm:ss everywhere, with typing auto-format and invalid-input rejection — `durationSeconds` API field unchanged.

## Current Milestone: v1.3 Quality of Life

**Goal:** Close carried-over debt, sync the client to backend API changes, finish the song→track rename, and ship two standalone quality-of-life features (calendar date picker, metronome tool).

**Target features:**
- Fix WR-01 (invite-code copy gated behind `isOnline`) and re-stamp the stale `02-VERIFICATION.md` gaps that are already resolved in code
- Adopt backend's server-side search: `ListUserTracks`/`ListUserSetlists` flip POST→GET with `SearchQuery`, band-track search moves to shared `$ref`; adopt `minLength: 8` password validation
- Rename remaining "song" references to "track" throughout the codebase (tab label, `lib/features/songs/` → `tracks`, `SongsScreen` class, ARB keys) — full rename, not just user-facing strings
- Setlist date input uses native `showDatePicker` instead of the current raw input
- New metronome tool: audio tick + visual pulse, big round tempo selector (default 120, ±5/±1 quick actions), 4/4 only with accented beat 1, reachable from Homepage "Tools" section and from a track screen (prefilled with that track's tempo); built last in the milestone

<details>
<summary>Previous milestone context (v1.2 and earlier)</summary>

**v1.2 i18n and Duration Input (shipped 2026-08-26):** full EN/RU localization with live switching, localized API errors, mm:ss duration input/display.

**v1.1 UI Improvements (shipped 2026-08-22):** password change from Profile, richer band/track/setlist info (member count/role, key metadata icons), online-first cache behavior flip (fresh data when online, last-fetched cache + warning banner when offline), band owner invite-code rotation and ownership transfer, homepage quick actions, searchable setlist track picker.

**v1.0 MVP (shipped 2026-08-17):** initial band/track/setlist CRUD, Riverpod migration off ChangeNotifier/prop-drilling, offline read cache with staleness indicators.

</details>

## Requirements

### Validated

- ✓ User can register with username/password — existing
- ✓ User can log in and session token persists across app restarts (secure storage) — existing
- ✓ 403 responses trigger automatic logout — existing
- ✓ App shell exists: bottom nav (Home/Songs/Bands/Profile), light/dark theme — existing
- ✓ User can view their profile (`GET /api/me`) and homepage summary (`GET /api/homepage`) — Phase 1
- ✓ App migrates off constructor-injected ChangeNotifier/prop-drilling to Riverpod, with a working local cache layer (proven end-to-end on profile/homepage) — Phase 1
- ✓ User can list, create, view, update, and delete tracks within a band, plus view them cross-band via a global filterable Tracks tab — Phase 3
- ✓ User can list, create, view, update, and delete setlists within a band — Phase 4
- ✓ User can add/remove tracks on a setlist and reorder them — Phase 4
- ✓ User can view all setlists across every band they belong to via a global filterable Setlists tab — Phase 4
- ✓ All GET-able band/track/setlist/profile data is cached locally on Android/iOS and remains viewable when offline; staleness indicators and connectivity-gated mutations are consistent across every screen — Phase 5
- ✓ User can list, create, view, update, and delete bands they belong to — Phase 2
- ✓ User can join a band via invite code — Phase 2
- ✓ User (owner) can remove a band member; any member can remove themselves — Phase 2
- ✓ User can change their account password from the Profile screen (USER-03) — v1.1 Phase 6
- ✓ User sees each band's member count and their own role (owner/member) in the Bands list and band detail screen (BAND-10) — v1.1 Phase 6
- ✓ Track list/detail screens show icons for musical key, duration, and notes (TRACK-07) — v1.1 Phase 6
- ✓ Setlist list/detail screens show icons for location and duration (SETL-11) — v1.1 Phase 6
- ✓ When online, every cached screen always fetches fresh data from the server; when offline, screens serve last-fetched cache with a persistent warning banner and the old staleness-tier badge system is removed entirely (OFFL-07, OFFL-08) — v1.1 Phase 7
- ✓ Band owner can rotate the band's invite code (BAND-11) — v1.1 Phase 8
- ✓ Band owner can transfer ownership to another band member (BAND-12) — v1.1 Phase 8
- ✓ User can start "Add band"/"Add song"/"Add setlist" from Homepage quick actions, with a band-picker dialog for song/setlist (HOME-01, HOME-02) — v1.1 Phase 9
- ✓ Setlist track picker replaces the flat all-tracks dialog with a searchable list; `publicapi.yml`'s `ListBandTracks` gains a client-side `searchQuery` field (backend implementation deferred) (SETL-12) — v1.1 Phase 10
- ✓ User enters and views track duration as mm:ss instead of raw seconds; `durationSeconds` API field unchanged (DUR-01, DUR-02, DUR-03, DUR-04) — v1.2 Phase 11
- ✓ User can switch app language between English and Russian from Profile settings; change applies live, no restart; ARB/gen-l10n pipeline and `LocaleController` established as the pattern every later i18n phase builds on (I18N-01, I18N-02, I18N-03) — v1.2 Phase 12
- ✓ All UI strings across every screen/dialog are localized EN/RU, with grammatically correct Russian plural forms (1/2–4/5+) for count-bearing strings (I18N-04, I18N-06) — v1.2 Phase 13
- ✓ Known API error codes are mapped to localized messages in the user's selected language; unmapped codes fall back to raw server text (I18N-05) — v1.2 Phase 14
- ✓ Invite-code copy button works offline (offline-gating regression fixed) (BAND-13) — v1.3 Phase 15
- ✓ `02-VERIFICATION.md`'s 4 carried-over gaps re-verified against current code and re-stamped (QA-01) — v1.3 Phase 15
- ✓ Setlist date input via native `showDatePicker`, with existing-date pre-population and out-of-range clamping into `[firstDate, lastDate]` (SETL-13) — v1.3 Phase 15

### Active

- [ ] Adopt server-side search: `ListUserTracks`/`ListUserSetlists` GET+`SearchQuery`, band-track search via shared `$ref`
- [ ] Adopt `minLength: 8` password validation (register + change-password)
- [ ] Full song→track rename (UI strings, `lib/features/songs/` dir, `SongsScreen` class, ARB keys)
- [ ] Metronome tool (audio + visual, homepage Tools section + track-prefilled entry, 4/4 only)

### Out of Scope

- Offline writes / mutation queue with sync-on-reconnect — deferred; v1 is read-only cache, no conflict resolution needed yet
- Offline caching on web build — web stays online-only this milestone
- Real-time collaboration (live updates when another member edits) — not requested
- Track audio file storage/playback — API has no such field; out of scope until API adds it
- Removing owner-only UI gates on band/track/setlist edit/delete — verified against code and the v1.1 schema update; already compliant (Delete-band stays owner-gated, Track/Setlist edit/delete and Band rename already have zero owner gate) — v1.1
- Invite-code shareable deep link — manual copy-to-clipboard is sufficient — v1.1
- Fuzzy/soundex search matching on the setlist track picker — client sends plain `searchQuery` text; matching strategy is a backend concern — v1.1

## Context

**Shipped state (v1.2, 2026-08-26):** ~29,800 LOC Dart across `lib/` + `test/`, 453 tests passing, `dart analyze` clean, zero TODO/stub/placeholder markers in production code. State flows through Riverpod (codegen'd AsyncNotifiers/family providers) end-to-end. `lib/cache/cache_service.dart`'s Hive-backed `_HiveStore` (with recursive `_deepConvert` for nested collections) backs 5 boxes (profile, homepage, bands, tracks, setlists). Every cached screen fetches fresh on open when online and falls back to last-fetched cache with a persistent offline warning banner when offline (`OfflineNoCacheException`/`OfflineNoCacheView`), with connectivity-gated mutations unchanged (`isOnlineProvider`, `connectivity_plus`).

**Localization (v1.2):** ARB/gen-l10n pipeline generates `AppLocalizations`; `LocaleController` (async `@riverpod` `AsyncNotifier<Locale>`, `SharedPreferences`-backed) drives a live, no-restart EN/RU switch from Profile settings, defaulting to English and persisting on-device. ~130 ARB keys cover every screen/dialog with correct Russian ICU plural forms (one/few/many/other) for count-bearing strings. `ApiExceptionLocalization.localizedMessage()` maps known `ErrorCode` values to localized messages across all 16 `on ApiException catch` sites app-wide; unmapped codes fall back to raw server text. Track duration is entered/displayed as mm:ss everywhere via `DurationTextInputFormatter` (auto-format, capped 99:59) and `track_formatting.dart`'s `asMinutesSeconds` extension — `durationSeconds` API field unchanged.

**API surface:** Full scope defined in `lib/api/publicapi.yml` (OpenAPI 3.0) — Users (register/login/me/homepage/password-change), Bands (CRUD, join, remove-member, rotate-invite-code, transfer-ownership), Band Tracks (CRUD), Band Setlists (CRUD, add/remove/reorder track, bulk-add), plus cross-band `POST /api/track/list` and `POST /api/setlist/list` (both `searchQuery`-bearing) for the global filterable tabs. All endpoints except register/login require `sessionAuth`.

**Platform note:** Repo builds for Android, iOS, and web. Offline caching targets Android/iOS only — web stays online-only.

**v1.1 schema catch-up (fe72e78, 2026-08-20):** client caught up to a server-side schema update — `POST /api/me/password`, `Band.membersCount`, member `id`/`role` (owner/member enum), `POST /api/band/{bandId}/rotate-invite-code`, `POST /api/band/{bandId}/transfer-ownership`; band/track/setlist mutation permissions loosened from owner-only to any-member (except delete-band, still owner-gated); `/api/track/list` and `/api/setlist/list` converted from GET to POST with a `searchQuery` request body; single-track setlist add/remove consolidated into the bulk `tracks` endpoints (`AddSetlistTracks`/`RemoveSetlistTracks`). App is unreleased, so no backward-compat shims were needed.

**API gap this milestone:** `publicapi.yml`'s `ListBandTracks` request gained a client-defined `searchQuery` field (SETL-12) — the client sends it, but the backend does not yet implement server-side filtering; the picker degrades to offline substring filtering until backend support ships.

**Known non-blocking items carried into next milestone:** one manual accessibility check outstanding (offline-banner text under ≥200% font scaling, from v1.0 Phase 5); Nyquist `/gsd-validate-phase` never run this or the prior milestone (coverage TODO, not a compliance failure).

## Constraints

- **Tech stack**: Flutter/Dart, must reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns rather than replacing them — minimize churn on already-working auth
- **Offline scope**: Read-only cache (last-fetched data viewable offline); no offline mutation queue, no conflict resolution — keeps v1 scope bounded
- **Platform scope**: Local caching required on Android/iOS; web excluded this milestone
- **API contract**: `lib/api/publicapi.yml` is the source of truth for all request/response shapes — no inventing fields or endpoints not defined there

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Read-only offline cache, not offline writes+sync | Keeps v1 scope bounded — no conflict resolution or retry-queue complexity needed | ✓ Good — held through Phase 5 |
| Offline caching mobile-only (Android/iOS), web excluded | Web already requires network for the pipeline/hosting model; avoids browser storage quirks this milestone | ✓ Good |
| Persist login token across restarts | Already implemented via flutter_secure_storage; confirmed as desired behavior going forward | ✓ Good |
| Introduce Provider or Riverpod for state management | Band/track/setlist screens need shared state across tabs; current ChangeNotifier+DI prop-drilling was already flagged as an anti-pattern in the codebase map | ✓ Good — Phase 1 |
| Extend `publicapi.yml` with `UserProfile.id` and `Band.ownerId` rather than fake it client-side | Client genuinely cannot self-identify or gate owner-only UI without these; username-matching or hiding-nothing were the only workarounds and both are fragile/wrong | ✓ Good — backend shipped it, Phase 2 uses it directly |
| Extend `publicapi.yml` with `GET /api/track/list` (cross-band, `bandId`-filterable) for TRACK-06 | No existing endpoint returns tracks across all of a user's bands; per-band-only would require N calls and defeats the global tab's purpose | ✓ Good — Phase 3 |
| Track/setlist mutation endpoints must always send all editable fields on update (not just changed ones) | Server's partial-update semantics treat an omitted field as "keep" and an explicit `null` as "clear" — conditional-send silently failed to clear optional fields (03-04 CR-02 gap) | ✓ Good — Phase 3, applies to any future PUT/PATCH with optional clearable fields |
| Extend `publicapi.yml` with `POST .../setlist/{setlistId}/tracks` (bulk add) and `GET /api/setlist/list` (cross-band, `bandId`-filterable) for SETL-06/SETL-10 | No bulk-add endpoint existed (only single-track add); no endpoint returned setlists across all of a user's bands, mirroring Phase 3's TRACK-06 gap | ✓ Good — Phase 4 |
| Recursive `_deepConvert()` at the Hive store boundary rather than per-call-site casting | Phase 2's initial verification (02-VERIFICATION.md) found Hive returns untyped `Map<dynamic,dynamic>`/`List<dynamic>` for nested collections; a shallow top-level conversion missed it, only catchable by a real Hive close+reopen test (in-memory test double hid it entirely) | ✓ Good — Phase 2 gap-closure (02-06); pattern reused for free by every later Hive-backed box |
| Monotonic `_version` counter guard on AsyncNotifier background refreshes | Unawaited background `_refresh()` on cache-hit could silently overwrite a local mutation (rename, setBands) that landed first, with no ordering guarantee | ✓ Good — Phase 2 gap-closure (02-06); reused as-is for Tracks/Setlists providers |
| `ref.exists()` guard before reading a sibling provider's `.notifier` from an unrelated screen | Reading `.notifier` on a never-watched provider instantiates it and fires an unplanned network call as a side effect — broke 3 pre-existing tests when first hit in Phase 2 | ✓ Good — established as the standing pattern for any cross-provider notifier read |
| Owner-gated mutations use a local-patch pattern: optimistic patch for responses with a usable body (rotate), invalidate+refetch plus a separate list-patch for responses without one (transfer) | Rotate's response returns the new code directly; transfer's 200-with-no-body can't be trusted as a source of truth, so the detail screen refetches while the bands-list badge is patched from the known target userId | ✓ Good — Phase 8; established alongside `updateName()`/`renameBand()` for future owner-gated mutations |
| Cache behavior flip built as a single reusable template (`_fetchAndCache`/online-first `build()`/tab-switch-refetch/`OfflineNoCacheException`) proven on Bands first, then mirrored verbatim across Home/Profile/Tracks/Setlists | One tracer plan (07-01) established the pattern and caught its edge cases once, instead of each of the 4 remaining plans re-deriving it independently | ✓ Good — Phase 7; zero pattern drift across the 5 plans |
| `LocaleController` built as an async `@riverpod` `AsyncNotifier<Locale>` backed by `SharedPreferences`, mirroring `ThemeController`'s shape but adding async persistence | Locale, unlike theme, needs a disk round-trip on both read and write; the async-notifier shape keeps the existing sync `ThemeController` pattern recognizable while accommodating that | ✓ Good — Phase 12; pattern for Phase 13/14 to reuse |
| Persisted-cache writes must check the same `_version` guard as in-memory state commits, not just the state assignment | Code review (CR-01) found a stale in-flight background refresh could pass the state-level version check's absence and still silently overwrite the on-disk cache with reverted data — the original guard only protected `state`, not the paired `CacheService` write | ✓ Good — Phase 7 gap-closure; both writes now gated by one check |
| Dropdown filter values must be clamped against their live source list before rendering, not just when set | A selected band-filter id surviving in a persisted provider after its band is deleted/left crashes Flutter's `DropdownButton` assertion (CR-02) — the fix clamps the rendered value without touching the persisted filter, so it "sticks" if the band reappears | ✓ Good — Phase 7 gap-closure; applies to any future filterable dropdown backed by a mutable list |
| `syncedAt` bump only fires after a confirmed cache write, not unconditionally alongside it | `CacheService.writeX` swallowed exceptions internally, so a failed persisted write could still report a fresh sync time (WR-02); `writeX` now returns `Future<bool>` and every call site gates the bump on `true` | ✓ Good — Phase 7 gap-closure |
| Removed the entire `XSyncedAt` provider family (10 classes) rather than building a "last synced" UI to consume them | Code review (WR-03) found the providers were maintained on every fetch/mutation but had zero screen consumers — dead infrastructure; no product ask existed for a last-synced indicator, so deletion was the lower-risk choice over building unrequested UI | ✓ Good — Phase 7 gap-closure |
| Behavioral changes (even small formatter fixes) must land as their own reviewed diff, not bundled into a string-extraction phase | Code review (CR-01) caught `DurationTextInputFormatter`'s in-phase algorithmic rewrite silently breaking backspace-to-empty clearing — untested because the phase's own test suite assumed pure string extraction; fixed same-session, but the bundling itself was flagged as scope creep (WR-02) | ✓ Fixed — Phase 13 code review; apply going forward: keep localization-only diffs isolated from behavior changes |
| `ApiExceptionLocalization.localizedMessage()` as a shared extension over `ApiException`, with an `overrides` parameter for screen-specific error-code handling | 16 catch sites across Bands/Tracks/Setlists/Login needed the same known-code-to-localized-message mapping; the `overrides` mechanism let login's `already_exists` and change-password's `invalid_input` retire their bespoke handling onto the same path instead of staying special-cased (D-04) | ✓ Good — Phase 14; established pattern for any future ApiException catch site |
| Clamp a persisted `eventDate` into the date picker's `[firstDate, lastDate]` window post-parse, rather than trusting the parsed value directly | `EditSetlistScreen`'s initial `showDatePicker` call asserts `initialDate` is in range and threw `AssertionError` for any setlist dated >5y past or >2y future (15-VERIFICATION.md Gap 1 / CR-01) | ✓ Good — Phase 15 gap-closure (15-03); same duplicated boundary math flagged again in 15-REVIEW.md (IN-01) as a future extraction candidate |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-27 after Phase 15*
