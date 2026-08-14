# Requirements: Cadence

**Defined:** 2026-08-14
**Core Value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Users

- [ ] **USER-01**: User can view own profile info via `GET /api/me`
- [ ] **USER-02**: User can view homepage summary (username, bands count) on app home tab via `GET /api/homepage`

### Bands

- [ ] **BAND-01**: User can view list of bands they belong to
- [ ] **BAND-02**: User can create a new band
- [ ] **BAND-03**: User can view band detail (name, members, invite code)
- [ ] **BAND-04**: User can update a band's name
- [ ] **BAND-05**: Band owner can delete a band
- [ ] **BAND-06**: User can join a band via invite code
- [ ] **BAND-07**: User can view and copy the band's invite code to share with others
- [ ] **BAND-08**: User can leave a band (remove self from member list)
- [ ] **BAND-09**: Band owner can remove another member from the band

### Tracks

- [ ] **TRACK-01**: User can view list of tracks in a band
- [ ] **TRACK-02**: User can add a track to a band (title, artist required; duration, tempo, key, notes optional)
- [ ] **TRACK-03**: User can view track detail
- [ ] **TRACK-04**: User can edit a track's info
- [ ] **TRACK-05**: User can delete a track from a band

### Setlists

- [ ] **SETL-01**: User can view list of setlists in a band (with track count and total duration)
- [ ] **SETL-02**: User can create a setlist (name required; event location, event date, and initial tracks optional)
- [ ] **SETL-03**: User can view setlist detail (ordered tracks, running duration)
- [ ] **SETL-04**: User can edit setlist info (name, event location, event date)
- [ ] **SETL-05**: User can delete a setlist
- [ ] **SETL-06**: User can add a track to a setlist
- [ ] **SETL-07**: User can remove a track from a setlist
- [ ] **SETL-08**: User can reorder tracks within a setlist via drag-and-drop
- [ ] **SETL-09**: User sees a setlist's total running duration (server-computed, no client math)

### Offline & State

- [ ] **OFFL-01**: Profile, homepage, band, track, and setlist GET data is cached locally on Android/iOS
- [ ] **OFFL-02**: Cached data remains viewable when the device has no connectivity
- [ ] **OFFL-03**: Mutations (create/update/delete) require connectivity and are disabled/blocked when offline
- [ ] **OFFL-04**: Each cached screen shows a "last synced Xm ago" indicator, escalating to a warning style past ~30 minutes stale
- [ ] **OFFL-05**: App shows a global offline-mode banner when the device has no connectivity
- [ ] **OFFL-06**: App state management migrates from ChangeNotifier/constructor-injected DI to Provider or Riverpod for band/track/setlist state shared across tabs

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Repertoire Enhancements

- **REPX-01**: Track tempo/key surfaced inline in setlist view (not just track detail)
- **REPX-02**: Client-side search/filter over cached track/setlist lists
- **REPX-03**: Setlist duplication (compose existing GET+POST client-side)
- **REPX-04**: Setlist target-duration vs. actual-duration comparison

## API Gaps (Backend Work Required)

Fields the client needs but the current `publicapi.yml` didn't expose. Added directly to `lib/api/publicapi.yml` as the contract to implement server-side — client code will be built against these shapes.

| Field | Schema | Why Needed | Blocks |
|-------|--------|------------|--------|
| `id` (uuid) | `UserProfile` (`GET /api/me` response) | Client has no way to learn its own user ID otherwise. Needed to identify "you" in a band's member list and to call `DELETE /api/band/{bandId}/remove-member/{userId}` with your own ID for self-leave. | BAND-08 |
| `ownerId` (uuid) | `Band` (`GET /api/band/{bandId}` response) | `BandMember` has no role/owner flag. Client can't conditionally show "Delete band" or "Remove member" actions (owner-only per API description) without knowing who the owner is. | BAND-03, BAND-05, BAND-09 |

**Until backend ships these:** BAND-08 (self-leave) can be built by asking the user to identify themselves by username-match against the member list — fragile if usernames aren't unique — flag as a known limitation. BAND-05/BAND-09 owner-only UI gating can't be done client-side at all until `ownerId` exists; those actions will call the API and surface whatever `403 permission_denied` comes back instead of hiding the button proactively.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Offline mutation queue with sync-on-reconnect | No conflict resolution strategy exists yet; v1 is read-only cache, mutations require connectivity |
| Offline caching on web build | Web stays online-only this milestone; caching scoped to Android/iOS |
| Real-time collaboration (live cross-device updates) | API has no websocket/push mechanism; read-only cache with visible staleness is the v1 model |
| Per-member roles beyond owner/member | `BandMember` schema has no role field beyond implicit owner; not supported by current API |
| Lyrics/chords/tabs storage per track | No dedicated schema on `BandTrack`; only `notes` free-text field exists |
| Track audio file storage/playback | API has no such field; out of scope until API adds it |
| Push notifications | No push infrastructure in API/backend scope this milestone |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| USER-01 | Phase 1 | Pending |
| USER-02 | Phase 1 | Pending |
| OFFL-01 | Phase 1 | Pending |
| OFFL-06 | Phase 1 | Pending |
| BAND-01 | Phase 2 | Pending |
| BAND-02 | Phase 2 | Pending |
| BAND-03 | Phase 2 | Pending |
| BAND-04 | Phase 2 | Pending |
| BAND-05 | Phase 2 | Pending |
| BAND-06 | Phase 2 | Pending |
| BAND-07 | Phase 2 | Pending |
| BAND-08 | Phase 2 | Pending |
| BAND-09 | Phase 2 | Pending |
| TRACK-01 | Phase 3 | Pending |
| TRACK-02 | Phase 3 | Pending |
| TRACK-03 | Phase 3 | Pending |
| TRACK-04 | Phase 3 | Pending |
| TRACK-05 | Phase 3 | Pending |
| SETL-01 | Phase 4 | Pending |
| SETL-02 | Phase 4 | Pending |
| SETL-03 | Phase 4 | Pending |
| SETL-04 | Phase 4 | Pending |
| SETL-05 | Phase 4 | Pending |
| SETL-06 | Phase 4 | Pending |
| SETL-07 | Phase 4 | Pending |
| SETL-08 | Phase 4 | Pending |
| SETL-09 | Phase 4 | Pending |
| OFFL-02 | Phase 5 | Pending |
| OFFL-03 | Phase 5 | Pending |
| OFFL-04 | Phase 5 | Pending |
| OFFL-05 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-14*
*Last updated: 2026-08-14 after roadmap creation (5 phases, full coverage)*
