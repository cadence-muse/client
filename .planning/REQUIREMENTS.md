# Requirements: Cadence

**Defined:** 2026-08-20
**Core Value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## v1 Requirements

Requirements for the v1.1 UI Improvements milestone. Each maps to a roadmap phase.

### Users

- [x] **USER-03**: User can change their account password from the Profile screen

### Bands

- [x] **BAND-10**: User sees each band's member count and their own role (owner/member) in the Bands list and band detail screen
- [ ] **BAND-11**: Band owner can rotate the band's invite code
- [ ] **BAND-12**: Band owner can transfer ownership to another band member

### Home

- [ ] **HOME-01**: User can start "Add band" from a Homepage quick action, opening the band-creation screen directly
- [ ] **HOME-02**: User can start "Add song" or "Add setlist" from Homepage quick actions, picking a band via a picker dialog before opening the respective per-band create screen

### Offline Cache

- [ ] **OFFL-07**: When online, every cached screen always fetches fresh data from the server (no cache-first serve)
- [ ] **OFFL-08**: When offline, screens serve last-fetched cache data with a persistent warning banner; existing `SyncStatusBadge`/staleness-tier system (10min/30min) is removed entirely

### Tracks

- [x] **TRACK-07**: Track list/detail screens show icons for musical key, duration, and notes

### Setlists

- [x] **SETL-11**: Setlist list/detail screens show icons for location and duration
- [ ] **SETL-12**: Setlist track picker replaces the current all-tracks dialog with a searchable list; `publicapi.yml`'s `ListBandTracks` gains a `searchQuery` request field (client extends the spec now, backend implements separately)

## v2 Requirements

None yet.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Removing owner-only UI gates on band/track/setlist edit/delete | Verified against code and the new schema — Delete-band correctly stays owner-gated (unchanged), Track/Setlist edit/delete and Band rename already have zero owner gate. No code change needed; nothing to track. |
| Offline mutation queue / sync-on-reconnect | Deferred since v1.0 — v1.1 keeps read-only cache, no conflict resolution |
| Invite-code shareable deep link | Requires URL scheme registration; manual copy-to-clipboard is sufficient for v1.1 |
| Fuzzy/soundex search matching | Client sends plain `searchQuery` text; matching strategy is a backend concern |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| USER-03 | Phase 6 | Complete |
| BAND-10 | Phase 6 | Complete |
| TRACK-07 | Phase 6 | Complete |
| SETL-11 | Phase 6 | Complete |
| OFFL-07 | Phase 7 | Pending |
| OFFL-08 | Phase 7 | Pending |
| BAND-11 | Phase 8 | Pending |
| BAND-12 | Phase 8 | Pending |
| HOME-01 | Phase 9 | Pending |
| HOME-02 | Phase 9 | Pending |
| SETL-12 | Phase 10 | Pending |

**Coverage:**

- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-20*
*Last updated: 2026-08-20 after v1.1 roadmap creation (Phases 6-10)*
