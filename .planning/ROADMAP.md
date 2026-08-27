# Roadmap: Cadence

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-08-17)
- ✅ **v1.1 UI Improvements** — Phases 6-10 (shipped 2026-08-22)
- ✅ **v1.2 i18n and Duration Input** — Phases 11-14 (shipped 2026-08-26)
- 🚧 **v1.3 Quality of Life** — Phases 15-18 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-08-17</summary>

- [x] Phase 1: Foundation, Profile & Home (3/3 plans) — completed 2026-08-15
- [x] Phase 2: Bands (6/6 plans) — completed 2026-08-15
- [x] Phase 3: Tracks (4/4 plans) — completed 2026-08-16
- [x] Phase 4: Setlists (5/5 plans) — completed 2026-08-17
- [x] Phase 5: Offline Trust & Connectivity UX (5/5 plans) — completed 2026-08-17

Full detail: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v1.1 UI Improvements (Phases 6-10) — SHIPPED 2026-08-22</summary>

- [x] Phase 6: Foundation Info & Settings Polish (4/4 plans) — completed 2026-08-21
- [x] Phase 06.1: API contract catch-up (1/1 plans) — completed 2026-08-21
- [x] Phase 7: Cache Behavior Flip — Online-First (5/5 plans) — completed 2026-08-22
- [x] Phase 8: Band Owner Tools (1/1 plans) — completed 2026-08-21
- [x] Phase 9: Homepage Quick Actions (1/1 plans) — completed 2026-08-22
- [x] Phase 10: Searchable Setlist Track Picker (1/1 plans) — completed 2026-08-22

Full detail: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>✅ v1.2 i18n and Duration Input (Phases 11-14) — SHIPPED 2026-08-26</summary>

- [x] Phase 11: Duration mm:ss Input + Display (2/2 plans) — completed 2026-08-25
- [x] Phase 12: Locale + i18n Infrastructure (1/1 plans) — completed 2026-08-25
- [x] Phase 13: String Extraction & Screen Localization (13/13 plans) — completed 2026-08-26
- [x] Phase 14: API Error Localization (4/4 plans) — completed 2026-08-26

Full detail: `.planning/milestones/v1.2-ROADMAP.md`

</details>

### 🚧 v1.3 Quality of Life (In Progress)

**Milestone Goal:** Close carried-over debt, sync the client to backend API changes, finish the song→track rename, and ship two standalone quality-of-life features (calendar date picker, metronome tool).

- [x] **Phase 15: Carried-Over Fixes & Setlist Date Picker** - Invite-code copy works offline, stale verification gaps re-stamped, setlist dates use native picker (completed 2026-08-27)
- [x] **Phase 16: Track Terminology Rename** - Full song→track rename across UI strings, directory, class, and ARB keys (completed 2026-08-27)
- [ ] **Phase 17: API Contract Sync** - Server-side search (GET+SearchQuery) replaces client filtering; 8-char minimum password validation
- [ ] **Phase 18: Metronome Tool** - Audio+visual metronome reachable from Homepage Tools and a track's detail screen

## Phase Details

### Phase 15: Carried-Over Fixes & Setlist Date Picker

**Goal**: Users get the invite-code copy button working offline, previously-flagged verification gaps confirmed still resolved in code, and setlist dates entered via the platform's native date picker.
**Depends on**: Nothing (continues from Phase 14)
**Requirements**: BAND-13, QA-01, SETL-13
**Success Criteria** (what must be TRUE):

  1. User can tap "copy invite code" on the band detail screen while offline and the code copies to the clipboard successfully (button no longer gated behind `isOnline`)
  2. `02-VERIFICATION.md`'s four previously-flagged gaps (Hive deep-convert, mutation error handling, band-rename list propagation, background-refresh version guard) are re-checked against current code and re-stamped resolved with evidence
  3. User creating or editing a setlist taps the date field and gets the platform's native `showDatePicker` instead of typing a raw date string

**Plans:** 3/3 plans complete

- [x] 15-01-PLAN.md — Setlist date field uses native showDatePicker instead of raw text entry (SETL-13)
- [x] 15-02-PLAN.md — Invite-code copy works offline (BAND-13) + 02-VERIFICATION.md gaps re-verified and re-stamped resolved (QA-01)
- [x] 15-03-PLAN.md — Gap closure: clamp EditSetlistScreen's initialDate into [firstDate, lastDate] to fix AssertionError crash on out-of-range persisted eventDate (SETL-13)

**UI hint**: yes

### Phase 16: Track Terminology Rename

**Goal**: The app's remaining "song" terminology is fully renamed to "track", eliminating a legacy naming split that predates the v1.0 track feature.
**Depends on**: Phase 15
**Requirements**: RENAME-01
**Success Criteria** (what must be TRUE):

  1. Bottom-nav tab and every screen/dialog reads "Track(s)" not "Song(s)" in both English and Russian
  2. No file under `lib/` lives in a `songs/` directory or contains a `Song`-prefixed class name (e.g. `SongsScreen`) — fully renamed to `tracks`/`TracksScreen` equivalents
  3. No ARB key or translation string contains "song" in English or Russian
  4. Full test suite passes with zero references to old song-named identifiers, and no stale generated (`.g.dart`) artifacts remain from the old names

**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 16-01-PLAN.md — Merge lib/features/songs/ into lib/features/tracks/ (D-01/D-06); rename homeAddSongButton ARB key to homeAddTrackButton and sweep "Add Song" comments (D-02/D-03/D-06)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 16-02-PLAN.md — Rename "Song"-named test fixture data to "Track" equivalents across 7 test files (D-05); phase-wide closing audit for zero "song" references

**UI hint**: yes

### Phase 17: API Contract Sync

**Goal**: The client's search behavior and password rules match the backend's updated `publicapi.yml` contract.
**Depends on**: Phase 16 (rename lands first so the search-migration logic change is written once, in already-renamed files, instead of being touched again by the rename sweep)
**Requirements**: API-01, API-02
**Success Criteria** (what must be TRUE):

  1. User's cross-band Tracks and Setlists tab searches are served by real server-side filtering (GET + `SearchQuery`) instead of the client's offline substring filter
  2. The setlist track picker's search field sends the same shared `SearchQuery` contract as the two list endpoints
  3. User attempting to register or change their password with a password under 8 characters sees a client-side validation error before any request is sent
  4. All existing search/list tests are updated and passing against the new GET-based mocks, with zero regressions

**Plans:** 3/3 plans executed

- [x] 17-01-PLAN.md — GET migration for listUserTracks/listUserSetlists + debounced search UI on the global Tracks tab (TracksScreen) and Setlists tab (SetlistsScreen) (API-01)
- [x] 17-02-PLAN.md — Setlist track picker renders debounced server search results instead of discarding them (API-01)
- [x] 17-03-PLAN.md — LoginScreen password validator gates the 8-char minimum to signup mode only, unblocking login for pre-existing short passwords (API-02)

**UI hint**: yes

### Phase 18: Metronome Tool

**Goal**: Users have a metronome tool for practicing, reachable from the Homepage and from any track's detail screen.
**Depends on**: Nothing new — zero technical dependency on Phases 15-17; sequenced last per explicit user preference so other fixes stabilize first
**Requirements**: METR-01, METR-02, METR-03, METR-04
**Success Criteria** (what must be TRUE):

  1. User can open a metronome from a new "Tools" section on the Homepage, defaulting to 120 BPM
  2. User can open the metronome from a track's detail screen and see it prefilled with that track's tempo
  3. When playing, user hears an audio tick synced to a visual pulse in 4/4 time, with the first beat of each bar audibly and visually accented
  4. User can adjust tempo via a large round tempo selector, plus ±1 and ±5 quick-adjust buttons

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 15 → 16 → 17 → 18

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|-----------------|--------|-----------|
| 1. Foundation, Profile & Home | v1.0 | 3/3 | Complete | 2026-08-15 |
| 2. Bands | v1.0 | 6/6 | Complete | 2026-08-15 |
| 3. Tracks | v1.0 | 4/4 | Complete | 2026-08-16 |
| 4. Setlists | v1.0 | 5/5 | Complete | 2026-08-17 |
| 5. Offline Trust & Connectivity UX | v1.0 | 5/5 | Complete | 2026-08-17 |
| 6. Foundation Info & Settings Polish | v1.1 | 4/4 | Complete | 2026-08-21 |
| 06.1. API contract catch-up | v1.1 | 1/1 | Complete | 2026-08-21 |
| 7. Cache Behavior Flip — Online-First | v1.1 | 5/5 | Complete | 2026-08-22 |
| 8. Band Owner Tools | v1.1 | 1/1 | Complete | 2026-08-21 |
| 9. Homepage Quick Actions | v1.1 | 1/1 | Complete | 2026-08-22 |
| 10. Searchable Setlist Track Picker | v1.1 | 1/1 | Complete | 2026-08-22 |
| 11. Duration mm:ss Input + Display | v1.2 | 2/2 | Complete | 2026-08-25 |
| 12. Locale + i18n Infrastructure | v1.2 | 1/1 | Complete | 2026-08-25 |
| 13. String Extraction & Screen Localization | v1.2 | 13/13 | Complete | 2026-08-26 |
| 14. API Error Localization | v1.2 | 4/4 | Complete | 2026-08-26 |
| 15. Carried-Over Fixes & Setlist Date Picker | v1.3 | 3/3 | Complete    | 2026-08-27 |
| 16. Track Terminology Rename | v1.3 | 2/2 | Complete    | 2026-08-27 |
| 17. API Contract Sync | v1.3 | 3/3 | In Progress|  |
| 18. Metronome Tool | v1.3 | 0/TBD | Not started | - |
