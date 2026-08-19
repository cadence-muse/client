---
gsd_state_version: 1.0
milestone: v1.0
status: Awaiting next milestone
stopped_at: Completed quick task 260819-v0u (add /api/logout call on sign-out)
last_updated: "2026-08-19T19:30:27.004Z"
last_activity: 2026-08-17
last_activity_desc: Phase 05 complete; corrected stale Phase 2 state (all 6 plans incl. gap-closure were already done)
state_head: 6a55de34f7a1c41460f7a2a08b43950352707c7a
milestone_name: milestone
current_phase: 5
current_phase_name: Offline Trust & Connectivity UX
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-16)

**Core value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.
**Current focus:** Phase 05 — offline-trust-connectivity-ux

## Current Position

Phase: Milestone v1.0 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-08-17 — Milestone v1.0 completed and archived

## Performance Metrics

**Velocity:**

- Total plans completed: 17
- Average duration: - min
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | - | - |
| 03 | 4 | - | - |
| 04 | 5 | - | - |
| 05 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 35min | 1 tasks | 23 files |
| Phase 01 P02 | 15min | 1 tasks | 2 files |
| Phase 01 P03 | 40min | 2 tasks | 8 files |
| Phase 02 P01 | 25min | 2 tasks | 11 files |
| Phase 02 P02 | 20min | 2 tasks | 9 files |
| Phase 02 P03 | 35min | 3 tasks | 8 files |
| Phase 02 P05 | 20min | 3 tasks | 6 files |
| Phase 02 P06 | 27min | 3 tasks | 15 files |
| Phase 03 P01 | 45min | 2 tasks | 16 files |
| Phase 03 P02 | 40min | 2 tasks | 9 files |
| Phase 03 P03 | 35min | 2 tasks | 12 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Riverpod migration (OFFL-06) and cache infrastructure (OFFL-01) both land in Phase 1, proven against profile/homepage before any other screen depends on them.
- Roadmap: OFFL-02/03/04/05 (offline viewing, mutation blocking, staleness indicator, offline banner) deferred as a group to Phase 5 — a dedicated cross-screen verification pass rather than per-phase partial implementation.
- Roadmap: Bands → Tracks → Setlists ordering follows the API's own resource nesting (bandId scopes tracks and setlists; setlist-track ops need tracks to exist first).
- [Phase ?]: 01-01: Resolved Riverpod/build_runner to 2.x line (flutter_riverpod 2.6.1, riverpod_generator 2.6.5) instead of plan's stated 3.x/4.x — flutter_test SDK's pinned meta/test_api versions conflict transitively with the 3.x/4.x lines in this environment
- [Phase ?]: 01-01: Added a CacheService _ProfileStore backing-store seam (Hive in prod, in-memory via CacheService.inMemory() in tests) — async dart:io file ops hang indefinitely inside the flutter_tester engine in this sandbox, so widget tests use the in-memory double instead of real Hive/temp-dir I/O
- [Phase ?]: 01-02: Implemented the OFFL-06 regression guard as a pure-Dart Directory.listSync() string search instead of shelling out to grep, for portability across test environments
- [Phase ?]: 01-03: Generalized CacheService's internal store abstraction (_ProfileStore -> _KeyValueStore) to back two independent Hive boxes (profileBox, homepageBox), proving D-02's per-endpoint-box pattern generalizes for Phase 2's bandsBox
- [Phase ?]: 02-01: band.dart's Band stub deleted with no typed replacement — screens use raw Map<String, dynamic> per Phase 1's D-03 no-typed-model pattern (BandListItem is id+name only)
- [Phase ?]: 02-01: BandAvatar kept as its own dedicated widget file (not inlined in ListTile.leading) per D-06, so a future milestone can swap in a real image avatar by editing only that file
- [Phase ?]: 02-02: BandDetailData is the project's first family Riverpod AsyncNotifier (build(String bandId)); per-band detail cached as band_<id>-keyed entries inside the existing bandsBox from 02-01, not a new Hive box
- [Phase ?]: 02-02: BandDetailScreen reads bandAsync.valueOrNull (not .value) for the AppBar title — AsyncValue.value rethrows on AsyncError, which crashed the widget on the error path before its own error UI could render
- [Phase ?]: 02-03: JoinBandDialog resolves the joined band's id client-side by diffing PublicApi.listBands() before/after the join (POST /api/band/join returns no response body per publicapi.yml) — documented API-contract gap, not a client bug; falls back to the refreshed Bands list on any ambiguous diff (0 or 2+ new ids)
- [Phase ?]: 02-03: Added BandsListData.setBands() public method instead of the plan's literal `notifier.state = AsyncData(...)` instruction — the latter fails flutter analyze (invalid_use_of_protected_member/visible_for_testing); establishes the pattern that AsyncNotifier state must only be set via a method the class itself defines
- [Phase ?]: 02-05: Tri-state (bool?) ownership gate (owner/resolved-non-owner/unresolved) computed inside profileDataProvider's .when(data:) branch — both Delete (owner-only) and Leave (non-owner-only) stay hidden while unresolved, avoiding the owner-gating TOCTOU race RESEARCH.md Pitfall 2 describes
- [Phase ?]: 02-05: Remove-member success invalidates bandDetailDataProvider(bandId) only (acting owner stays on detail screen); Leave/Delete success invalidates bandsListDataProvider and double-pops back to the list (D-15 vs. RESEARCH.md Pitfall 5)
- [Phase ?]: 02-06: _HiveStore.get() recursively deep-converts nested Map/List values (CR-01 fix) — a shallow top-level-only conversion left nested collections (e.g. members list) as Hive's untyped containers, throwing TypeError on a real disk read; only caught by tests that explicitly Hive.close()+reopen mid-test, since in-memory tests never exercise real deserialization
- [Phase ?]: 02-06: BandsListData/BandDetailData background _refresh()/_doRefresh() gained a _version counter guard (WR-02) — captured before the network await, checked before applying the result, so a slower in-flight refresh can't silently revert a local mutation (setBands/renameBand/updateName) that landed first
- [Phase ?]: 02-06: Guarded EditBandScreen's new bandsListDataProvider.notifier read with ref.exists() rather than the plan's literal unconditional-call instruction — reading .notifier on a never-watched provider instantiates it and fires an unplanned network fetch as a side effect; mirrors the existing bandDetailDataProvider guard in the same function
- [Phase ?]: 03-01: TrackListData/TrackDetailData keep the _version WR-02 guard field-for-field per bands_provider.dart, even though no local-mutation method exists yet to bump it in this plan (edit/delete land in Plans 02/03) — left non-final to match the mirrored shape those later plans will extend
- [Phase ?]: 03-02: Edit and Delete are built without any ownership gate — TRACK-04/TRACK-05 carry no owner qualifier and 03-RESEARCH.md's Access Control section confirms server-side band-membership-only enforcement, superseding 03-UI-SPEC.md's inapplicable owner-gated citation
- [Phase ?]: 03-03: Added SelectedBandIdFilter.setFilter(bandId) as a public method instead of direct notifier.state assignment — matches BandsListData.setBands() precedent from 02-03 to keep flutter analyze clean
- [Phase 3]: 03-04 (gap closure): `updateBandTrack` now always sends all 6 editable fields (title/artist required, non-nullable) instead of omitting nulls — server treats an omitted field as "keep" and an explicit `null` as "clear"; applies to any future PUT/PATCH with optional clearable fields (e.g. setlist mutations)
- [Phase 3]: 03-04: New `SelectedTabIndex` Riverpod notifier (`navigation_provider.dart`) lets a screen switch `RootScaffold`'s bottom-nav tab without a direct reference to its state — reusable pattern for any future cross-tab navigation
- [Phase 3]: Team confirmed backend strictly validates/enforces the musical key format — NF-01 (unrecognized key values) is unreachable in practice via UAT, no client-side workaround needed
- [Phase 5]: Quick 260819-v0u: AuthSession.signOut() calls PublicApi.logout() best-effort (fire before local clear, swallow all errors) with a _loggingOut reentrancy guard to prevent unbounded recursion when a 403 on the logout call itself triggers ApiClient.onUnauthorized -> signOut()

### Pending Todos

None yet.

### Blockers/Concerns

- API gap: `UserProfile.id` and `Band.ownerId` were added to `lib/api/publicapi.yml` this milestone but require backend implementation before BAND-08 (self-leave) and BAND-05/BAND-09 (owner-only UI gating) can be built as specified — see REQUIREMENTS.md "API Gaps". Client-side fallback (username-match / no proactive hiding) documented there if backend isn't ready when Phase 2 starts.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260819-v0u | add /api/logout call when user logs out on profile screen | 2026-08-19 | 6a55de3 | [260819-v0u-add-api-logout-call-when-user-logs-out-o](./quick/260819-v0u-add-api-logout-call-when-user-logs-out-o/) |

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-08-17:

| Category | Item | Status |
|----------|------|--------|
| verification_gap | Phase 02: 02-VERIFICATION.md | gaps_found (raw file, pre-02-06) — gap-closure plan 02-06 fixed all 4 flagged issues (CR-01/WR-01/WR-02/WR-03) same-day with passing regression tests; confirmed present and wired by v1.0-MILESTONE-AUDIT.md's independent integration check. File left as historical record, not re-stamped. |

## Session Continuity

Last session: 2026-08-19T19:30:19.354Z
Stopped at: Completed quick task 260819-v0u (add /api/logout call on sign-out)
Resume file: None

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
