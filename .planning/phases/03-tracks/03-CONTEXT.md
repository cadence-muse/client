# Phase 3: Tracks - Context

**Gathered:** 2026-08-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Song catalog CRUD within a band: list a band's tracks, add a track (title/artist required; duration/tempo/key/notes optional), view track detail, edit track info, delete a track. Builds on Phase 1/2's Riverpod + Hive cache-store foundation (cache-first loading, per-endpoint Hive boxes, codegen providers) — no new state-management or caching approach introduced here.

**Expanded during discussion:** the previously-placeholder global "Songs" bottom-nav tab is repurposed into a "Tracks" tab showing a flat, cross-band list of every track the user's bands contain, filterable to one band. This required a new API endpoint (`GET /api/track/list`) not previously in `publicapi.yml` — added to the contract during this discussion, mirroring Phase 2's `Band.ownerId`/`UserProfile.id` API-gap precedent. See `<decisions>` → API gap section and REQUIREMENTS.md TRACK-06.

No Setlists screens (Phase 4), no offline-staleness UI (Phase 5), no per-member roles.

</domain>

<decisions>
## Implementation Decisions

### API gap: global tracks endpoint
- **D-01:** Add `GET /api/track/list` to `publicapi.yml` as the contract to implement server-side (backend considered not-yet-shipped, same pattern as Phase 2's `ownerId`/`id` gap) — optional `bandId` query filter, response `ListUserTracksResponseBody { items: UserTrackListItem[] }` where each item extends `TrackListItem` with `bandId` + `bandName`. — **Reversibility:** costly — **Rationale:** the global Tracks tab (D-05/D-06 below) and its provider/screen are built directly against this shape; if the backend hasn't shipped it when this phase is implemented, the whole global-tab feature blocks (no client-side workaround — merging N per-band calls defeats the point and can't cheaply reproduce server-side band filtering).
- Tracked in REQUIREMENTS.md "API Gaps" as blocking new requirement **TRACK-06**. Traceability and ROADMAP Phase 3 success criteria updated accordingly.

### Navigation entry point
- **D-02:** A band's track list lives as a **separate screen** reached from Band detail (tap a "Tracks" entry → `TrackListScreen(bandId)`) — mirrors the Edit Band pattern (Phase 2 D-10, full-screen navigation from detail) rather than an inline section appended to Band detail.
- **D-03:** The global bottom-nav "Songs" tab is **renamed to "Tracks"** and repurposed to show the cross-band list (via D-01's new endpoint) instead of staying an unused placeholder.
- **D-04:** The global Tracks tab shows a **flat list** with a **band-name badge per row**, plus a **filter dropdown** to narrow to one band (using the `bandId` query param) — not grouped-by-band section headers.

### Track list display (per-band and global)
- **D-05:** Per-band track list rows show **title + artist + duration only** — matches `TrackListItem`'s actual schema (no `tempo`/`key` on the list item, only on full `BandTrack`); tempo/key are detail-page-only info.
- **D-06:** Duration (`durationSeconds`) displays as **mm:ss** (e.g. `3:45`), computed client-side — everywhere it's shown (list rows, detail).
- **D-07:** Per-band track list sort order is **insertion order as returned by the API** — no client-side sort.

### Add/edit track form
- **D-08:** Add track and edit track are **full-screen forms**, not dialogs — 6 possible fields (2 required + 4 optional) don't fit Join Band's single-field dialog pattern (Phase 2 D-11); matches Create Band's full-screen precedent (Phase 2 D-10).
- **D-09:** Add track and edit track are **separate screens** (not one shared form widget toggling create/edit mode) — mirrors Create Band vs. Edit Band being distinct today.
- **D-10:** The `key` field is entered via a **dropdown of the 12 root notes × major/minor toggle** (24 combinations: C, Cm, C#, C#m, … B, Bm) — a client-only convention layered on top of the API's unconstrained `key: string` field (no server-side enum).

### Delete track
- **D-11:** Delete confirmation is a **lightweight Cancel/Confirm dialog** (matches Leave Band / Remove Member, Phase 2 D-14) — not type-to-confirm (Phase 2 D-13's heavier pattern is reserved for Delete Band, which destroys the band for everyone; a single track delete doesn't warrant that friction).
- **D-12:** Delete is triggered **only from the track detail screen** — no swipe-to-dismiss on list rows.
- **D-13:** After deleting a track, the user returns to the **band's track list screen** (`TrackListScreen(bandId)`) — mirrors Phase 2 D-15 (delete/leave band → back to Bands list).

### Claude's Discretion
- None recorded as explicit "you decide" outcomes — every question in this discussion reached a concrete choice.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API contract
- `lib/api/publicapi.yml` — source of truth for all request/response shapes. Relevant for this phase:
  - `GET /api/band/{bandId}/track/list` → `ListBandTracksResponseBody` (`items: TrackListItem[]`, each `id`/`title`/`artist` required + optional `durationSeconds`)
  - `POST /api/band/{bandId}/track` → `CreateBandTrackRequestBody` (title/artist required; durationSeconds/tempo/key/notes optional) / `CreateBandTrackResponseBody` (`id`)
  - `GET /api/band/{bandId}/track/{trackId}` → `BandTrack` (full detail incl. tempo/key/notes)
  - `PUT /api/band/{bandId}/track/{trackId}` → `UpdateBandTrackRequestBody`
  - `DELETE /api/band/{bandId}/track/{trackId}`
  - **New this phase (D-01):** `GET /api/track/list` (optional `bandId` query filter, via new `BandIdFilter` parameter) → `ListUserTracksResponseBody` (`items: UserTrackListItem[]`, each extending `TrackListItem` with required `bandId`/`bandName`)

### Project-level constraints
- `.planning/PROJECT.md` — "Constraints" section: reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns; offline scope is read-only cache; Android/iOS only, web excluded.
- `.planning/REQUIREMENTS.md` — "Tracks" section (TRACK-01 through TRACK-06); "API Gaps" section documents the new `GET /api/track/list` endpoint (D-01) alongside Phase 2's prior `ownerId`/`id` gaps, including the fallback note if backend isn't ready (drop the global tab, keep per-band tracks only).
- `.planning/ROADMAP.md` — Phase 3 success criteria (now includes the global Tracks tab, criterion 5) and scope boundary (Setlists is Phase 4, offline staleness UI is Phase 5).

### Prior phase context (established patterns to extend, not re-decide)
- `.planning/phases/02-bands/02-CONTEXT.md` — D-10 (full-screen create pattern), D-11 (dialog-for-single-field pattern), D-13/D-14 (type-to-confirm vs. lightweight confirm), D-15 (post-destructive-action navigation), D-07/D-08 (per-entity keyed cache + cache-first detail loading).
- `.planning/phases/01-foundation-profile-home/01-CONTEXT.md` — D-01/D-02/D-03 (Hive-per-endpoint cache pattern, raw JSON storage), D-04 (cache-first loading), D-10 (Riverpod codegen via `riverpod_generator`/`@riverpod`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/providers/bands_provider.dart` — the reference implementation for a per-band-keyed cache-first provider (`BandDetailData`, family `AsyncNotifier`); the new per-band `TrackListData` provider should mirror this shape, keyed by `bandId` inside a new `tracksBox`.
- `lib/cache/cache_service.dart` (`CacheService`, `_KeyValueStore`/`_HiveStore`/`_InMemoryStore`) — add a `tracksBox` (per-band track lists) and a separate keyed store or box for the new global-tracks endpoint result (D-01), following the same generalized abstraction Phase 1/2 already extended.
- `lib/api/public_api.dart` (`PublicApi`) — currently has register/login/band methods; track endpoints (list/create/get/update/delete per-band, plus the new global list) need new methods here or a parallel class.
- `lib/features/bands/band_avatar.dart`, `edit_band_screen.dart` — style/structure reference for the new `TrackAvatar`-equivalent (if any) and the full-screen add/edit track forms.

### Established Patterns
- Cache-first loading (Phase 1 D-04): show cached data immediately, background-refresh silently, no error surfaced on background-refresh failure — applies to both per-band track list/detail and the new global tracks list.
- One Hive box per endpoint (Phase 1 D-02), raw decoded JSON (Phase 1 D-03) — no typed models/TypeAdapters; tracks follow the same no-typed-model convention as bands (Phase 2 D-code_context note on `band.dart`).
- Riverpod codegen (`@riverpod` + `riverpod_generator` + `build_runner`) for all new providers (Phase 1 D-10).
- `ApiException` (statusCode/code/message) caught at the UI layer — same error contract extends to track mutation calls.

### Integration Points
- `lib/features/songs/songs_screen.dart` — currently a bare placeholder (`Center(child: Text('Songs'))`); becomes the global Tracks tab screen (D-03/D-04), reading from the new global-tracks provider.
- `lib/navigation/root_scaffold.dart` — bottom-nav destination label/icon changes from "Songs" to "Tracks" (D-03); import path for `SongsScreen` likely renames alongside it.
- `lib/features/bands/band_detail_screen.dart` — gains a "Tracks" entry point (D-02) navigating to the new `TrackListScreen(bandId)`; no other changes to band detail's existing member/ownership logic.

</code_context>

<specifics>
## Specific Ideas

- The `key` field dropdown (D-10) should present all 12 root notes with a major/minor toggle (24 total values) — matches how musicians actually describe a song's key, even though the API stores it as a free-text string.
- Global Tracks tab: flat list, band-name badge per row, filter dropdown — not a grouped/sectioned-by-band layout.

</specifics>

<deferred>
## Deferred Ideas

None beyond what's captured as TRACK-06 above (folded into this phase's scope, not deferred).

### Reviewed Todos (not folded)
None — no pending todos matched this phase (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 3-Tracks*
*Context gathered: 2026-08-16*
