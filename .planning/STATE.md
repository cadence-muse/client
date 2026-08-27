---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Quality of Life
current_phase: 18
current_phase_name: Metronome Tool
status: planning
stopped_at: Phase 17 complete, ready to plan Phase 18
last_updated: "2026-08-27T18:49:47.233Z"
last_activity: 2026-08-27
last_activity_desc: Phase 17 complete, transitioned to Phase 18
state_head: 24ffbf8f70f5fd8fee8d66a91b87566c0fb0de9a
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 8
  completed_plans: 8
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-27)

**Core value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.
**Current focus:** Phase 18 — Metronome Tool

## Current Position

Phase: 18 — Metronome Tool
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-27 — Phase 17 complete, transitioned to Phase 18

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 58
- Average duration: - min
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | - | - |
| 03 | 4 | - | - |
| 04 | 5 | - | - |
| 05 | 5 | - | - |
| 06 | 4 | - | - |
| 06.1 | 1 | - | - |
| 08 | 1 | - | - |
| 09 | 1 | - | - |
| 10 | 1 | - | - |
| 07 | 5 | - | - |
| 11 | 2 | - | - |
| 12 | 1 | - | - |
| 13 | 13 | - | - |
| 14 | 4 | - | - |
| 15 | 3 | - | - |
| 16 | 2 | - | - |
| 17 | 3 | - | - |

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

- Roadmap: v1.3 phases continue numbering from v1.2's Phase 14, starting at Phase 15 (Phases 15-18). No phase-number reset requested.
- Roadmap: BAND-13 (invite-code copy offline fix), QA-01 (re-stamp stale verification gaps), and SETL-13 (native date picker) are all small, low-risk, and mutually independent — bundled into Phase 15 to avoid three separate thin single-requirement phases, and sequenced first since nothing else in the milestone depends on them.
- Roadmap: Phase 16 (song→track rename) sequenced before Phase 17 (API contract sync) — RENAME-01 and API-01 both touch the cross-band Tracks tab and setlist track picker; doing the mechanical rename first means the API-01 search-logic change lands once, in already-renamed files, instead of being touched again by the rename sweep.
- Roadmap: Phase 18 (metronome) sequenced last per explicit user preference — zero dependency on any other item in the milestone, and building it last lets Phases 15-17 stabilize first.
- Roadmap: v1.2 phases continue numbering from v1.1's Phase 10, starting at Phase 11 (Phases 11-14). No phase-number reset requested.
- Roadmap: User requested Duration mm:ss (originally proposed as Phase 12) be sequenced before the Locale/i18n phases — the two are independent (per research SUMMARY.md dependency graph), so the swap has no correctness cost. Final order: Phase 11 (Duration mm:ss Input + Display) → Phase 12 (Locale + i18n Infrastructure) → Phase 13 (String Extraction & Screen Localization) → Phase 14 (API Error Localization).
- Roadmap: Phase 11 (Duration mm:ss Input + Display) has no dependency on i18n infrastructure — ships first per explicit user preference.
- Roadmap: Phase 12 (Locale + i18n Infrastructure) — every other i18n phase depends on `LocaleController`, the ARB/gen-l10n pipeline, and the locale-propagation pattern it establishes; cheapest to build once, before the string-localization sweep (per research SUMMARY.md).
- Roadmap: Phase 13 (String Extraction & Screen Localization) is sequenced after Phase 12 so the "watch locale" propagation pattern and test-string centralization are already-proven, not invented mid-sweep across 20+ screens; I18N-06 (Russian plural forms) folded into this phase since it's part of the same string-localization surface.
- Roadmap: Phase 14 (API Error Localization) sequenced last — smallest, most isolated surface (`ApiException` catch blocks only), depends only on Phase 12's ARB pipeline.
- Roadmap: v1.1 phases continue numbering from v1.0's Phase 5, starting at Phase 6 (Phases 6-10).
- Roadmap: Phase 6 (low-risk info/settings polish) ships first to establish display patterns before the higher-risk Phase 7 cache-behavior flip.
- Roadmap: Phase 7 (cache-behavior flip, online-first) sequenced before Phase 8 (owner tools) so rotate-invite-code/transfer-ownership mutations are built against the finalized online-first invalidation model, not the retired cache-first one.
- Roadmap: The research-recommended "Permission Gating Refactor" phase was dropped — REQUIREMENTS.md confirms owner-only UI gates are already compliant with the new schema (out of scope, no code change needed), so v1.1 has no dedicated phase for it.
- Roadmap: Phases 9 (Homepage quick actions) and 10 (searchable track picker) are independent/low-touch and sequenced last, per research recommendation to ship them after foundational work stabilizes.
- Roadmap: Riverpod migration (OFFL-06) and cache infrastructure (OFFL-01) both landed in Phase 1, proven against profile/homepage before any other screen depended on them.
- Roadmap: Bands → Tracks → Setlists ordering in v1.0 followed the API's own resource nesting (bandId scopes tracks and setlists).
- [Phase 3]: `updateBandTrack` always sends all 6 editable fields instead of omitting nulls — server treats an omitted field as "keep" and an explicit `null` as "clear"; applies to any future PUT/PATCH with optional clearable fields (relevant to Phase 8's owner-mutation endpoints).
- [Phase 5]: Quick 260819-v0u: AuthSession.signOut() calls PublicApi.logout() best-effort with a `_loggingOut` reentrancy guard to prevent unbounded recursion on a 403 from the logout call itself.
- [Phase 13]: All 19 screens/9+ dialogs migrated to `AppLocalizations`; `test/test_strings.dart` centralizes test-string assertions (`tester.strings.keyName`) across 24 test files, replacing hardcoded English literals in `find.text(...)`.
- [Phase 13]: `memberCount`/`trackCount`/`slotCount` use full ICU plural forms (one/few/many/other) for correct Russian 1/2–4/5+ pluralization.
- [Phase 13 code review]: `DurationTextInputFormatter`'s in-phase algorithmic rewrite broke backspace-to-empty clearing (stuck at "0:00") — caught and fixed same-session (CR-01, commit 10a9544); flagged as scope creep bundled into a string-extraction phase (WR-02) — keep behavioral changes in their own reviewed diff going forward.
- [Phase 15]: `EditSetlistScreen`'s date-picker `initialDate` now clamps a persisted `eventDate` into `[firstDate, lastDate]` post-parse instead of trusting the parsed value directly — an out-of-range date previously threw `AssertionError` (Gap 1 / CR-01), fixed in gap-closure plan 15-03.
- [Phase 17]: `listUserTracks`/`listUserSetlists` migrated POST+body → GET+`SearchQuery` query params, mirroring `listBandTracks`; cross-band Tracks/Setlists tabs gained real debounced (300ms), online-gated server search with offline substring fallback unchanged.
- [Phase 17]: `AddSetlistTracksDialog`'s debounced online search response is now rendered (`_serverSearchResults` state), not discarded — same "capture into nullable state, consume in build()" pattern now used by all three debounced-search call sites.
- [Phase 17 code review, CR-01 fixed]: `LoginScreen`'s error handling branched on `statusCode == 401` for `/api/login`, but the contract only ever returns `400` — dead code, masked by a test mocking an impossible response. Fixed to key off the `400` response's `invalid_input` code via `localizedMessage`'s `overrides`, scoped separately from `register()`'s own `already_exists` override so a signup-time `invalid_input` isn't mislabeled "Invalid credentials".

### Pending Todos

None yet.

### Blockers/Concerns

- v1.1: backend implementation status of the `searchQuery` field on `ListBandTracks` is unconfirmed. API-01 (Phase 17) shipped the client-side portion — the setlist track picker now renders whatever the server returns instead of discarding it — but whether the server actually filters by `searchQuery` was not verified this phase.
- [Phase 15 review, non-blocking] `CreateSetlistScreen._showDatePickerDialog` always opens with `initialDate: now` instead of the currently-picked date (WR-01, create_setlist_screen.dart:95-104) — reopening the picker loses the prior selection. No test coverage.
- [Phase 15 review, non-blocking] Both setlist screens' `_showDatePickerDialog` call `setState()` after `await showDatePicker(...)` without a `mounted` check (WR-02) — could throw "setState() called after dispose()" if the widget is torn down mid-dialog (e.g. 403 auto-logout).
- [Phase 17 review, non-blocking] Debounced search in `tracks_screen.dart`/`setlists_screen.dart`/`add_setlist_tracks_dialog.dart` cancels the debounce timer but not the in-flight request — an out-of-order slow response can overwrite a fresher one (17-REVIEW.md WR-01).
- [Phase 17 review, non-blocking] Setlists tab search field reuses `addSetlistTracksSearchHint` ("Search by title or artist"), but setlists only have a `name` field to match against (17-REVIEW.md WR-02).
- [Phase 17 review, non-blocking] `LoginScreen._submit()` has no generic fallback for non-`ApiException` failures (raw network errors), unlike the sibling `add_setlist_tracks_dialog.dart` changed the same phase (17-REVIEW.md WR-03).

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|

### Roadmap Evolution

- Phase 06.1 inserted after Phase 6: API contract catch-up: RemoveSetlistTrack->RemoveSetlistTracks migration, ListUserTracks/ListUserSetlists GET->POST migration, per fe72e78 schema update missed by v1.1 roadmap (URGENT)
- v1.3 ROADMAP.md created 2026-08-27: Phases 15 (Carried-Over Fixes & Setlist Date Picker), 16 (Track Terminology Rename), 17 (API Contract Sync), 18 (Metronome Tool). 10/10 requirements mapped.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| verification_gaps | 02/02-VERIFICATION.md | gaps_found | 2026-08-26 | v1.2 |
| verification_gaps | 02/02-VERIFICATION.md | gaps_found | 2026-08-22 | v1.1 |

Items acknowledged and deferred at milestone close on 2026-08-17:

| Category | Item | Status |
|----------|------|--------|
| verification_gap | Phase 02: 02-VERIFICATION.md | gaps_found (raw file, pre-02-06) — gap-closure plan 02-06 fixed all 4 flagged issues (CR-01/WR-01/WR-02/WR-03) same-day with passing regression tests; confirmed present and wired by v1.0-MILESTONE-AUDIT.md's independent integration check. File left as historical record, not re-stamped. |

## Session Continuity

Last session: 2026-08-27T18:51:32.000Z
Stopped at: Phase 17 complete, ready to plan Phase 18
Resume file: None

## Operator Next Steps

- Plan Phase 18 with `/gsd-plan-phase 18`
