# Roadmap: Cadence

## Overview

Cadence goes from a Flutter default-template shell with working auth to a full band-repertoire app: profile/home, then bands, tracks, and setlists built as vertical CRUD slices, each landing on a Riverpod + local-cache foundation established up front so no phase has to retrofit state management or offline support into already-built screens. The milestone closes with a dedicated pass that makes staleness and connectivity trustworthy and consistent across every screen — the actual point of the app's core value (usable with no signal, at a gig).

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation, Profile & Home** - Riverpod migration and cache-store infrastructure, proven end-to-end on the profile and homepage screens (completed 2026-08-15)
- [ ] **Phase 2: Bands** - Full band management — create, view, edit, delete, join via invite code, and membership
- [x] **Phase 3: Tracks** - Song catalog CRUD within a band (completed 2026-08-16)
- [ ] **Phase 4: Setlists** - Setlist CRUD, track add/remove/reorder, and running duration
- [ ] **Phase 5: Offline Trust & Connectivity UX** - Staleness indicators, offline banner, and mutation blocking verified consistently across every screen

## Phase Details

### Phase 1: Foundation, Profile & Home

**Goal**: Users can view their profile and homepage summary, on an app now running on Riverpod state management with a working local cache layer that every later phase builds on directly (not retrofits later).
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: USER-01, USER-02, OFFL-01, OFFL-06
**Success Criteria** (what must be TRUE):

  1. User can view their own profile info via a profile screen backed by `GET /api/me`.
  2. User can view a homepage summary (username, band count) on the home tab via `GET /api/homepage`.
  3. Profile and homepage screens still show the last-fetched data when the device has no connectivity, proving the cache-store pattern end-to-end for the first two screens.
  4. Auth, profile, and homepage state flows through Riverpod providers instead of constructor-injected `ChangeNotifier` — no dual source of truth for auth state during or after the migration.

**Plans**: 1/3 plans executed
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Riverpod + Hive walking skeleton: Profile end-to-end (auth/theme migration, ApiClient decoupling, cache-store pattern)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Auth/theme provider test coverage (OFFL-06 regression guard, cache-clear-on-signOut mitigation)
- [x] 01-03-PLAN.md — Home screen: cache-first GET /api/homepage + full test coverage

**UI hint**: yes

### Phase 2: Bands

**Goal**: Band members can manage their bands end-to-end, using the Riverpod + cache-store pattern from Phase 1.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: BAND-01, BAND-02, BAND-03, BAND-04, BAND-05, BAND-06, BAND-07, BAND-08, BAND-09
**Success Criteria** (what must be TRUE):

  1. User can view the list of bands they belong to.
  2. User can create a new band and see it appear in their band list.
  3. User can view a band's detail page (name, members, invite code) and copy the invite code to share.
  4. User can update a band's name, and — if they're the owner — delete the band.
  5. User can join another band via invite code, leave a band they're in, and — if owner — remove another member.

**Plans**: 5/5 plans executed

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Bands list end-to-end (tracer): API + cache + provider + BandsScreen (BAND-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Band detail view + invite code copy (BAND-03, BAND-07)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-PLAN.md — Create band + join via invite code, single FAB entry point (BAND-02, BAND-06)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-04-PLAN.md — Edit band name (BAND-04)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 02-05-PLAN.md — Delete band, leave band, remove member (owner-gated destructive actions) (BAND-05, BAND-08, BAND-09)

**UI hint**: yes

### Phase 3: Tracks

**Goal**: Band members can maintain their band's song catalog.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: TRACK-01, TRACK-02, TRACK-03, TRACK-04, TRACK-05, TRACK-06
**Success Criteria** (what must be TRUE):

  1. User can view the list of tracks in a band.
  2. User can add a new track to a band (title and artist required; duration, tempo, key, notes optional).
  3. User can view a track's detail page.
  4. User can edit a track's info and delete a track from the band.
  5. User can view all tracks across every band they belong to on a global Tracks tab, optionally filtered to one band.

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 03-01-PLAN.md — Per-band track list + add + detail (tracer): API + cache + provider + screens (TRACK-01, TRACK-02, TRACK-03)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-PLAN.md — Edit track + delete track, ungated on ownership (TRACK-04, TRACK-05)

**Wave 3** *(blocked on Wave 2 completion — shares public_api.dart/cache_service.dart/tracks_provider.dart)*

- [x] 03-03-PLAN.md — Global cross-band Tracks tab, filterable by band (TRACK-06)

**UI hint**: yes

### Phase 4: Setlists

**Goal**: Band members can build and manage setlists for gigs, including track ordering and running duration.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: SETL-01, SETL-02, SETL-03, SETL-04, SETL-05, SETL-06, SETL-07, SETL-08, SETL-09, SETL-10
**Success Criteria** (what must be TRUE):

  1. User can view the list of setlists in a band, each showing track count and total duration.
  2. User can create a setlist (name required; event location, event date, and initial tracks optional).
  3. User can view setlist detail (ordered tracks, running duration) and edit the setlist's info.
  4. User can add tracks to a setlist, remove them, and reorder them via drag-and-drop.
  5. User can delete a setlist, and the displayed running duration is always server-computed (no client-side math).
  6. User can view all setlists across every band they belong to on a global Setlists tab, optionally filtered to one band.

**Plans**: 4/5 plans executed

Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Per-band setlist list + create + detail (tracer): API + cache + provider + screens (SETL-01, SETL-02, SETL-03, SETL-09)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Edit setlist info + delete setlist (SETL-04, SETL-05)

**Wave 3** *(blocked on Wave 2 completion — shares public_api.dart/setlists_provider.dart/setlist_detail_screen.dart)*

- [x] 04-03-PLAN.md — Add tracks (bulk picker) + remove track + Edit-mode toggle (SETL-06, SETL-07)

**Wave 4** *(blocked on Wave 3 completion — shares setlist_detail_screen.dart)*

- [x] 04-04-PLAN.md — Drag-and-drop track reordering, built-in ReorderableListView (SETL-08)

**Wave 5** *(blocked on Wave 4 completion — shares public_api.dart/setlists_provider.dart)*

- [ ] 04-05-PLAN.md — Global cross-band Setlists tab + bottom-nav reorder (SETL-10)

**UI hint**: yes

### Phase 5: Offline Trust & Connectivity UX

**Goal**: Band members can trust what they see offline — clear staleness and connectivity signals, and mutations safely blocked without connectivity — verified consistently across profile, bands, tracks, and setlists.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: OFFL-02, OFFL-03, OFFL-04, OFFL-05
**Success Criteria** (what must be TRUE):

  1. User can view previously-loaded profile, band, track, and setlist data with the device in airplane mode, across every screen.
  2. Each cached screen shows a "last synced Xm ago" indicator that escalates to a warning style past ~30 minutes stale.
  3. A global offline-mode banner appears whenever the device has no connectivity, regardless of which screen the user is on.
  4. Create/update/delete actions are visibly disabled or blocked while offline instead of silently failing.

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation, Profile & Home | 3/3 | Complete    | 2026-08-15 |
| 2. Bands | 5/5 | In Progress|  |
| 3. Tracks | 4/4 | Complete    | 2026-08-16 |
| 4. Setlists | 4/5 | In Progress|  |
| 5. Offline Trust & Connectivity UX | 0/TBD | Not started | - |
