# Roadmap: Cadence

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-08-17)
- 🚧 **v1.1 UI Improvements** — Phases 6-10 (in progress)

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

### 🚧 v1.1 UI Improvements (In Progress)

**Milestone Goal:** Catch the app up to the fe72e78 schema update, flip offline cache to online-first, polish info-display UI, and add search to the setlist song picker.

- [x] **Phase 6: Foundation Info & Settings Polish** - Password change, band member count/role display, and metadata icons on Track/Setlist screens (completed 2026-08-21)
- [ ] **Phase 7: Cache Behavior Flip — Online-First** - Online always fetches fresh; offline serves cache with a persistent warning banner; staleness-tier badge system removed
- [ ] **Phase 8: Band Owner Tools** - Owner can rotate the invite code and transfer band ownership
- [ ] **Phase 9: Homepage Quick Actions** - Add band/song/setlist shortcuts from the Homepage, with a band-picker dialog for song/setlist
- [ ] **Phase 10: Searchable Setlist Track Picker** - Setlist track picker replaces the flat dialog with a searchable list; `ListBandTracks` spec gains a `searchQuery` field

## Phase Details

### Phase 1: Foundation, Profile & Home

**Goal**: Users can view their profile and homepage summary, on an app now running on Riverpod state management with a working local cache layer.
**Plans**: 3 plans (complete)

### Phase 2: Bands

**Goal**: Users can create, view, edit, delete, and join bands, with membership management.
**Plans**: 6 plans (complete)

### Phase 3: Tracks

**Goal**: Users can manage a band's song catalog with full CRUD, plus a cross-band filterable view.
**Plans**: 4 plans (complete)

### Phase 4: Setlists

**Goal**: Users can manage setlists per band — CRUD, track add/remove/reorder, and a cross-band filterable view.
**Plans**: 5 plans (complete)

### Phase 5: Offline Trust & Connectivity UX

**Goal**: Every cached screen shows consistent staleness/connectivity signals with mutations gated while offline.
**Plans**: 5 plans (complete)

Full detail for Phases 1-5: `.planning/milestones/v1.0-ROADMAP.md`

---

### Phase 6: Foundation Info & Settings Polish

**Goal**: Users can change their account password and see richer, at-a-glance info (member count/role, key metadata icons) on Bands/Track/Setlist screens — low-risk display work that establishes patterns before the riskier cache-behavior flip.
**Depends on**: Nothing (first phase of v1.1; builds on v1.0's Profile/Bands/Tracks/Setlists screens)
**Requirements**: USER-03, BAND-10, TRACK-07, SETL-11
**Success Criteria** (what must be TRUE):

  1. User can navigate to the Profile screen, enter their current password and a new password, and successfully change their password with clear success feedback.
  2. A user who enters an incorrect current password sees a clear error message and the change is rejected.
  3. On the Bands list and a band's detail screen, the user sees each band's member count and their own role (Owner/Member) displayed.
  4. On track list/detail screens, icons represent musical key, duration, and notes at a glance.
  5. On setlist list/detail screens, icons represent location and duration at a glance.

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 06-01-PLAN.md — Password change end-to-end (USER-03) + remaining spec field extensions

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 06-02-PLAN.md — Band member count & role display (BAND-10)
- [x] 06-03-PLAN.md — Track metadata icons: key/duration/notes (TRACK-07)
- [x] 06-04-PLAN.md — Setlist metadata icons: location/duration (SETL-11)

**UI hint**: yes

### Phase 06.1: API contract catch-up: migrate RemoveSetlistTrack to RemoveSetlistTracks batch endpoint and ListUserTracks/ListUserSetlists from GET to POST with searchQuery body, per fe72e78 schema update (INSERTED)

**Goal:** `public_api.dart`'s `removeSetlistTrack`, `listUserTracks`, and `listUserSetlists` methods match the current `publicapi.yml` wire contract (post `fe72e78`), so setlist track removal and the cross-band track/setlist lists succeed against the live API instead of failing on stale GET/DELETE-path assumptions.
**Requirements**: None — inserted urgent catch-up phase, no `REQUIREMENTS.md` IDs apply (see STATE.md's "Roadmap Evolution" entry).
**Depends on:** Phase 6
**Plans:** 1/1 plans executed

Plans:

- [x] 06.1-01-PLAN.md — Migrate removeSetlistTrack (batch endpoint), listUserTracks and listUserSetlists (GET→POST) to match the fe72e78 schema update

### Phase 7: Cache Behavior Flip — Online-First

**Goal**: Users always see the freshest server data when online, and get an honest, simple signal when viewing cached data offline — replacing the staleness-tier badge system entirely.
**Depends on**: Phase 6 (low-risk patterns established before this higher-risk, all-screens change)
**Requirements**: OFFL-07, OFFL-08
**Success Criteria** (what must be TRUE):

  1. When online, every previously-cached screen (Home, Bands, Tracks, Setlists, Profile) always shows freshly-fetched server data on open, rather than serving the old cache first.
  2. When offline, every one of those screens still shows the last-fetched cache data instead of a blank or error state.
  3. When offline, a persistent warning banner is visible on every cached screen indicating the shown data may be out of date.
  4. The old per-item staleness badge (10min/30min "synced X ago" tiers) no longer appears anywhere in the app.

**Plans**: TBD
**UI hint**: yes

### Phase 8: Band Owner Tools

**Goal**: A band owner can manage the band's invite code and hand off ownership to another member.
**Depends on**: Phase 7 (owner-mutation flows integrate with the finalized online-first cache/invalidation model rather than the retired cache-first one)
**Requirements**: BAND-11, BAND-12
**Success Criteria** (what must be TRUE):

  1. Band owner can rotate the band's invite code from the band detail screen, and the new code is shown and copyable immediately.
  2. After rotating the invite code, the previous invite code no longer works for joining the band.
  3. Band owner can transfer ownership to another member via a confirmation flow, after which the new owner sees owner-only controls and the previous owner sees only member controls.
  4. Non-owner members never see the rotate-invite-code or transfer-ownership controls.

**Plans**: TBD
**UI hint**: yes

### Phase 9: Homepage Quick Actions

**Goal**: Users can jump straight from the Homepage into creating a band, song, or setlist without extra navigation.
**Depends on**: Phase 6 (reuses existing Bands list data for the band-picker dialog); independent of Phases 7-8
**Requirements**: HOME-01, HOME-02
**Success Criteria** (what must be TRUE):

  1. User can tap "Add band" on the Homepage and land directly on the band-creation screen.
  2. User can tap "Add song" on the Homepage, is shown a picker dialog listing their bands, and lands on the chosen band's create-track screen after picking one.
  3. User can tap "Add setlist" on the Homepage, is shown a picker dialog listing their bands, and lands on the chosen band's create-setlist screen after picking one.

**Plans**: TBD
**UI hint**: yes

### Phase 10: Searchable Setlist Track Picker

**Goal**: Users can quickly find and add the right track to a setlist even when the band has many tracks.
**Depends on**: Nothing new — independent; sequenced last per research (ships after foundational work stabilizes)
**Requirements**: SETL-12
**Success Criteria** (what must be TRUE):

  1. Opening the "add tracks to setlist" picker shows a search field instead of the old flat static-list dialog.
  2. Typing in the search field filters the visible track list to matches as the user types.
  3. `lib/api/publicapi.yml`'s `ListBandTracks` request includes a documented `searchQuery` field (client-side spec extension; backend implementation follows in a later milestone).
  4. Selecting one or more filtered tracks and confirming adds exactly those tracks to the setlist, same as the previous dialog's add behavior.

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8 → 9 → 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|-----------------|--------|-----------|
| 1. Foundation, Profile & Home | v1.0 | 3/3 | Complete | 2026-08-15 |
| 2. Bands | v1.0 | 6/6 | Complete | 2026-08-15 |
| 3. Tracks | v1.0 | 4/4 | Complete | 2026-08-16 |
| 4. Setlists | v1.0 | 5/5 | Complete | 2026-08-17 |
| 5. Offline Trust & Connectivity UX | v1.0 | 5/5 | Complete | 2026-08-17 |
| 6. Foundation Info & Settings Polish | v1.1 | 4/4 | Complete    | 2026-08-21 |
| 7. Cache Behavior Flip — Online-First | v1.1 | 0/TBD | Not started | - |
| 8. Band Owner Tools | v1.1 | 0/TBD | Not started | - |
| 9. Homepage Quick Actions | v1.1 | 0/TBD | Not started | - |
| 10. Searchable Setlist Track Picker | v1.1 | 0/TBD | Not started | - |
