# Feature Research

**Domain:** Band repertoire / setlist management app (mobile, Flutter)
**Researched:** 2026-08-14
**Confidence:** MEDIUM

## Feature Landscape

Note: this milestone's buildable surface is fixed by `lib/api/publicapi.yml` (source of truth). Findings below are filtered through that constraint — features the API doesn't support (e.g. real-time sync, per-member roles beyond owner/member, lyrics/chords storage) are flagged as out-of-scope/anti-features even where competitor apps offer them, per PROJECT.md's "no inventing fields or endpoints" constraint.

### Table Stakes (Users Expect These)

Features users assume exist in any band/setlist tool. Missing these = product feels incomplete. All are directly supported by the current API.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Band list + create/rename/delete | Baseline "workspace" concept — every competitor (Band Mule, BandHelper, Setlistly) organizes around a band/group entity | LOW | `GET/POST /api/band`, `PUT/DELETE /api/band/{id}` already fully specified |
| Join band via invite code | Standard join mechanic across all researched competitors — no per-member approval step, instant access on valid code | LOW | `POST /api/band/join`; API returns only success/400, no pending-approval state — matches the "instant join" pattern found industry-wide |
| View invite code / share it | Owner needs to distribute the code somehow; without visible/copyable code, the join flow is a dead end | LOW | `inviteCode` field is on `Band` detail response — just needs a "copy" affordance in band detail screen |
| Member list on band detail | Users expect to see who's in the band before/after inviting | LOW | `members: BandMember[]` on `GET /api/band/{id}` |
| Remove member (self-leave + owner-remove-any) | Every competitor supports leaving a band and owner-initiated removal; without it, users get stuck in bands forever | LOW | `DELETE /api/band/{bandId}/remove-member/{userId}` — single endpoint covers both cases (self or owner) |
| Track catalog CRUD (title, artist, duration) | The core "repertoire" concept — a band's shared song list is the anchor entity all setlists build from | LOW-MEDIUM | Full CRUD on `/api/band/{bandId}/track` already in API; `tempo`, `key`, `notes` are optional richer fields worth surfacing in track detail/edit forms |
| Setlist CRUD (name, event date/location) | Setlists are the "output" artifact bands actually use at a gig — table stakes for any setlist tool | LOW-MEDIUM | `/api/band/{bandId}/setlist` CRUD; `eventDate`/`eventLocation` optional but should be exposed since gig context is why bands use these apps |
| Add/remove tracks on a setlist | A setlist with no ability to curate which songs are in it isn't a setlist | LOW | `POST/DELETE .../setlist/{id}/track[/{trackId}]` |
| Reorder setlist tracks (drag-and-drop) | Universal pattern across every setlist app researched (Setlist Helper, Set List Maker, All Set) — bands sequence songs by energy/pacing for a show | MEDIUM | `PUT .../tracks/reorder` takes full ordered `trackIds` array; Flutter side needs `ReorderableListView` + optimistic reorder-then-confirm |
| Setlist running duration | Every competitor surfaces total set time so bands know if they're over/under their slot | LOW | `durationSeconds` already computed server-side on `SetlistListItem`/`BandSetlist` — just display it, no client math needed |
| Offline read access to last-synced data | This milestone's explicit core value ("open the app without signal ... still see tracks/setlist") | HIGH | Requires local DB (see STACK/ARCHITECTURE research) + repository read-through pattern for all list/detail GETs |
| Empty states (no bands / no tracks / no setlists) | New users always hit these first — a blank screen with no CTA is a broken first impression | LOW | Needs "Create your first band" / "Join a band" / "Add a track" prompts |
| Basic form validation on create/edit | `title`/`artist`/`name` are required fields per schema; server returns `400 invalid_input` — client should pre-validate to avoid round-trips | LOW | Mirror required fields per schema (e.g. `CreateBandTrackRequestBody` requires `title`+`artist`) |

### Differentiators (Competitive Advantage)

Not required for a baseline setlist tool, but where Cadence can stand out given its stated core value (offline-first, at-the-venue reliability) — all still within current API scope.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Explicit "last synced" + staleness indicator | Most competitor apps assume connectivity (cloud-only); Cadence's core value is explicit offline reliability, so making staleness *visible and trustworthy* (not just silently cached) is the differentiator, not the caching itself | LOW-MEDIUM | Per-screen "Updated Xm ago" label; escalate to amber/warning styling past ~30min per standard offline-UX tiering (see PITFALLS/ARCHITECTURE) |
| Persistent offline-mode banner | Reassures a band member at a venue with no signal that they're seeing real (if old) data, not a broken app | LOW | Single global banner tied to `connectivity_plus` status, not per-screen — avoid banner spam |
| Setlist duration vs. slot warning | Bands frequently get a fixed set time from a venue; surfacing "42:10 total" next to a target isn't in the API but is pure client-side UX value on top of the already-provided `durationSeconds` | LOW | No API changes needed — purely a client affordance (e.g. user-entered target duration stored locally, not synced) |
| Quick-add track to setlist from track catalog | Reduces friction versus navigating setlist -> add -> search-by-name flows seen in some competitors | LOW | Straightforward list-with-checkbox UX using existing `AddSetlistTrackRequestBody`/`trackId` |
| Track metadata surfaced in setlist view (tempo/key) | Musicians actively want tempo/key visible while building a set (energy pacing, key transitions) — data already exists on `BandTrack` but competitor apps often bury it | LOW | `tempo`/`key`/`notes` exist on track schema; worth denormalizing into setlist track display, not just track detail |

### Anti-Features (Commonly Requested, Often Problematic — For This Milestone)

Features competitor apps have, or users might ask for, that should be explicitly deferred given API/scope constraints in PROJECT.md.

| Feature | Why Requested | Why Problematic (this milestone) | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time collaborative editing (live setlist updates across devices) | Competitors (Band Mule, Band Central) advertise "instant, real-time available" shared collections | Explicitly out of scope per PROJECT.md; API has no websocket/push mechanism, and read-only cache + manual refresh is the agreed v1 model | Pull-to-refresh + explicit "last synced" timestamp; revisit with a sync/push mechanism in a later milestone |
| Offline mutation queue (create/edit tracks/setlists while offline, sync later) | Natural "why can't I just edit offline too?" ask once offline viewing exists | Explicitly deferred in PROJECT.md — no conflict resolution strategy exists yet; building it now risks silent data loss on conflicting edits | Disable/gray out mutation actions when offline; show "connect to make changes" messaging |
| Per-member roles beyond owner/member (e.g. "editor", "viewer-only") | Larger bands sometimes want tiered permissions | `BandMember` schema has no role field beyond implicit owner (band creator); inventing a role system isn't supported by the API | Keep owner/member binary as-is; flag for backend team if richer roles are wanted in a future API version |
| Lyrics/chords/tabs storage per track | Multiple competitors (Band Setlist Manager) store per-instrument lyrics/chords/tab sheets | `notes` is the only free-text field on `BandTrack` — no dedicated lyrics/chords schema, and adding one isn't sanctioned this milestone | Use the existing `notes` field for freeform performance notes; don't build a rich lyrics/chord editor against an unsupported shape |
| Audio file attachment/playback per track | Musicians often want reference audio attached to a song | PROJECT.md explicitly calls this out: "Track audio file storage/playback — API has no such field; out of scope until API adds it" | None this milestone — do not build local-only audio attachments either, since it creates an inconsistent, non-synced feature |
| Setlist templates / duplicate-setlist | Bands often reuse a similar set across gigs | Not in API (no "duplicate" endpoint) — would require client-side compose of `GET` + `POST` with copied `trackIds`, which is buildable but adds scope not requested in Active requirements | Could be added trivially later as a pure client-side composition of existing CRUD calls if requested — flag as a cheap v1.x candidate, not v1 |
| Full-text search across tracks/setlists | Bigger catalogs benefit from search | No search endpoint in API; band track/setlist lists are unpaginated flat lists (`items: []` with no pagination params), so any "search" this milestone would be client-side filtering only | Simple client-side substring filter over the already-fetched (and offline-cached) track/setlist list — cheap, no API dependency, safe differentiator to consider in v1.x |
| Push notifications ("new setlist added", "you were removed from a band") | Common engagement feature in collaborative apps | No push infrastructure in API/backend scope this milestone; adding it is a backend+client project of its own | None this milestone |

## Feature Dependencies

```
Band CRUD (list/create/view/edit/delete)
    └──requires──> Auth session (existing)

Join band via invite code
    └──requires──> Band CRUD (need a Band detail view to land on after joining)

Remove member (self/owner)
    └──requires──> Band detail view (member list must be visible first)

Track catalog CRUD
    └──requires──> Band detail view (tracks are scoped to a band; user needs band context first)

Setlist CRUD
    └──requires──> Band detail view (setlists are scoped to a band)

Add/remove track on setlist
    └──requires──> Track catalog CRUD (need tracks to exist before adding to a setlist)
    └──requires──> Setlist CRUD (need a setlist to add tracks to)

Reorder setlist tracks
    └──requires──> Add/remove track on setlist (need >=2 tracks on a setlist to make reordering meaningful)

Offline read cache (all GETs)
    └──requires──> Local DB layer (Drift/sqlite) — cross-cutting, should land early since every list/detail screen depends on it
    └──enhances──> Band/Track/Setlist CRUD (read paths only; writes still require connectivity per Out of Scope)

Last-synced / staleness indicator
    └──requires──> Offline read cache (need a persisted fetch timestamp to display)

Offline-mode banner
    └──requires──> connectivity detection (new dependency: connectivity_plus or equivalent)

State management migration (Provider/Riverpod)
    └──enhances──> all of the above (shared band/track/setlist state across tabs is much harder with current ChangeNotifier+DI prop-drilling pattern)
```

### Dependency Notes

- **Everything band/track/setlist requires Band detail view first:** tracks and setlists are always scoped under a `bandId` in the API path — there's no cross-band track/setlist listing. The roadmap should land "band CRUD + band detail" before track/setlist screens are buildable at all.
- **Reorder depends on add/remove, which depends on both track catalog and setlist existing:** this is a natural three-phase-minimum dependency chain (bands → tracks → setlists-with-tracks) even before offline caching enters the picture.
- **Offline read cache is cross-cutting, not a single feature:** it touches every GET-backed screen (profile, homepage, band list/detail, track list/detail, setlist list/detail). It's more efficient to introduce the local-DB + repository pattern once, early, and have each subsequent CRUD phase write through it — rather than bolting caching onto each screen type separately later.
- **Last-synced/staleness indicator enhances but doesn't gate the cache:** the cache can ship functionally without the indicator, but PROJECT.md's core value statement implies users need to *trust* what they're seeing offline — so the indicator should not be deferred far behind the cache itself.
- **State management migration enhances everything, doesn't strictly block it:** PROJECT.md flags this as a required decision this milestone ("App migrates off constructor-injected ChangeNotifier/prop-drilling") because band/track/setlist state needs to be shared across Home/Songs/Bands tabs — doing this early avoids rework once multiple screens depend on the same band-scoped data.

## MVP Definition

### Launch With (v1 — this milestone's Active requirements)

Minimum viable scope per PROJECT.md Active requirements — everything here is already committed, not speculative:

- [ ] Profile + homepage summary (`GET /api/me`, `GET /api/homepage`)
- [ ] Band list/create/view/update/delete
- [ ] Join band via invite code
- [ ] Remove band member (self-leave + owner-remove)
- [ ] Track catalog CRUD within a band
- [ ] Setlist CRUD within a band
- [ ] Add/remove/reorder tracks on a setlist
- [ ] Offline read cache for all GET-able data (Android/iOS)
- [ ] State management migration to Provider or Riverpod

### Add After Validation (v1.x)

Cheap, API-supported extensions that weren't asked for but fell out of this research — worth flagging to the user, not silently building:

- [ ] Client-side search/filter over cached track/setlist lists — trigger: catalog grows past ~20-30 tracks and manual scanning becomes annoying
- [ ] Setlist duplication (compose existing GET+POST client-side) — trigger: users report re-creating similar setlists repeatedly
- [ ] Setlist target-duration vs. actual-duration comparison — trigger: users ask "will this set fit our slot"

### Future Consideration (v2+)

Deferred per PROJECT.md's explicit Out of Scope, or requiring backend/API changes not sanctioned this milestone:

- [ ] Offline mutation queue with sync-on-reconnect and conflict resolution — defer until read-only cache is proven and a conflict strategy is chosen deliberately
- [ ] Real-time collaboration (live cross-device updates) — defer until a push/websocket mechanism exists in the API
- [ ] Track audio attachment/playback — defer until API adds a field for it
- [ ] Richer band member roles — defer until API adds a role concept beyond owner/member
- [ ] Lyrics/chords/tabs per track — defer until API adds a dedicated schema (don't overload `notes`)
- [ ] Push notifications — defer, requires backend infrastructure work

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Band CRUD + detail view | HIGH | LOW | P1 |
| Join via invite code | HIGH | LOW | P1 |
| Remove member (self/owner) | MEDIUM | LOW | P1 |
| Track catalog CRUD | HIGH | LOW-MEDIUM | P1 |
| Setlist CRUD | HIGH | LOW-MEDIUM | P1 |
| Add/remove setlist track | HIGH | LOW | P1 |
| Reorder setlist tracks | HIGH | MEDIUM | P1 |
| Offline read cache (all screens) | HIGH | HIGH | P1 |
| State management migration | MEDIUM (invisible to users, blocks maintainability) | MEDIUM | P1 |
| Last-synced / staleness indicator | HIGH (trust signal for core value) | LOW-MEDIUM | P1 |
| Offline-mode banner | MEDIUM | LOW | P2 |
| Setlist duration display | MEDIUM | LOW | P2 (nearly free — server computes it) |
| Track tempo/key surfaced in setlist view | LOW-MEDIUM | LOW | P2 |
| Client-side search/filter | LOW at current scale | LOW | P3 |
| Setlist duplication | LOW-MEDIUM | LOW | P3 |

**Priority key:**
- P1: Must have for launch (matches PROJECT.md Active requirements)
- P2: Should have, add when possible (cheap wins on top of P1 API responses)
- P3: Nice to have, future consideration (not requested, flag before building)

## Competitor Feature Analysis

| Feature | Band Mule / Band Central (cloud-first) | Setlist Helper / Set List Maker (setlist-focused) | Cadence's Approach |
|---------|--------------|--------------|--------------|
| Band joining | Invite link, no approval, instant workspace access | N/A (mostly single-user or looser sharing) | Invite code (`POST /api/band/join`), matches instant-join norm |
| Setlist reordering | Basic list ordering | Drag-and-drop with live running duration | Drag-and-drop via `ReorderableListView` + `PUT .../tracks/reorder`, duration already server-computed |
| Real-time sync | Real-time cross-device (websocket-backed) | Mostly single-device/local | Explicitly NOT this milestone — read-only cache with visible staleness instead |
| Offline support | Largely assumes connectivity (cloud-first tools) | Mixed — some are local-first (Set List Maker) | This is Cadence's differentiator: explicit offline read cache + trust-building staleness UI, positioned against connectivity-dependent competitors |
| Lyrics/chords | Setlist Helper/Band Setlist Manager: per-instrument tracks | Yes | Not supported by API this milestone — `notes` field only |
| Roles/permissions | Owner + members, sometimes finer-grained | N/A | Owner (implicit) + member, matches `BandMember` schema exactly |

## Sources

- [Band setlist manager review](https://medium.com/@e-kratz/review-band-setlist-manager-f525dd04fc90) — MEDIUM confidence
- [Setlistly](https://setlistly.com/setlist-app) — MEDIUM confidence
- [SetBook](https://www.set-book.com/) — MEDIUM confidence
- [Setlist Helper](https://www.setlisthelper.com/) — MEDIUM confidence
- [Band Mule](https://www.bandmule.com/) — MEDIUM confidence
- [Band Central](https://www.bandcentral.com/join-the-band/vPblA5cBPaehT116_j12) — MEDIUM confidence
- [BandHelper](https://www.bandhelper.com/) — MEDIUM confidence
- [Set List Maker (Arlo Leach)](https://www.arlomedia.com/apps/setlistmaker_original/) — MEDIUM confidence
- [Drag & Drop UX Design Best Practices — Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-drag-and-drop) — MEDIUM confidence
- [Drag-and-Drop UX Guidelines — Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/drag-and-drop-ux/) — MEDIUM confidence
- [All Set: The Setlist App](https://apps.apple.com/py/app/all-set-the-setlist-app/id1453232689) — MEDIUM confidence
- [Offline-first mobile app background sync — AppMaster](https://appmaster.io/blog/offline-first-background-sync-conflict-retries-ux) — MEDIUM confidence
- [Offline Mode in Mobile Apps — Tekrevol](https://www.tekrevol.com/blogs/offline-first-app-development-guide/) — MEDIUM confidence
- [Build an offline-first app — Android Developers](https://developer.android.com/topic/architecture/data-layer/offline-first) — MEDIUM confidence
- `lib/api/publicapi.yml` — ground truth for buildable API surface (HIGH confidence, curated/local source)
- `.planning/PROJECT.md` — ground truth for milestone scope/constraints (HIGH confidence, curated/local source)

---
*Feature research for: band repertoire/setlist management (Flutter mobile app)*
*Researched: 2026-08-14*
