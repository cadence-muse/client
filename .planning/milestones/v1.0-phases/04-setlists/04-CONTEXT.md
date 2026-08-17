# Phase 4: Setlists - Context

**Gathered:** 2026-08-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Setlist CRUD within a band: list a band's setlists (with track count + total duration), create a setlist (name required; event location, event date, and initial tracks optional), view setlist detail (ordered tracks, server-computed running duration), edit setlist info, delete a setlist, add/remove tracks on a setlist, and reorder tracks via drag-and-drop. Builds on Phase 1-3's Riverpod + Hive cache-store foundation (cache-first loading, per-endpoint Hive boxes, codegen providers) — no new state-management or caching approach introduced here.

**Expanded during discussion:** mirroring Phase 3's Tracks tab precedent, a new global bottom-nav "Setlists" tab shows a flat, cross-band list of every setlist the user's bands contain, filterable to one band. This required two new API endpoints not previously in `publicapi.yml` — a bulk track-add endpoint and a cross-band setlist-list endpoint — added to the contract during this discussion. See `<decisions>` → API gaps section and REQUIREMENTS.md SETL-06/SETL-10.

No offline-staleness UI (Phase 5), no per-member roles, no lyrics/chords/audio storage.

</domain>

<decisions>
## Implementation Decisions

### API gaps: bulk track-add + global setlist list
- **D-01:** Add `POST /api/band/{bandId}/setlist/{setlistId}/tracks` to `publicapi.yml` as the contract to implement server-side — body `AddSetlistTracksRequestBody { trackIds: string[], maxItems: 100 }`, mirroring the existing bulk `trackIds` field on setlist creation and the reorder endpoint's shape. — **Reversibility:** costly — **Rationale:** the add-tracks picker (D-08 below) is built directly against this bulk endpoint; the existing single-track `POST .../track` only adds one at a time and would require N looped calls if this doesn't ship.
- **D-02:** Client is built directly against the bulk-add endpoint with **no fallback** — backend considered ready, same posture as Phase 2's D-01 for `ownerId`/`id` (not the "block until shipped" posture used for Phase 3's TRACK-06).
- **D-03:** Add `GET /api/setlist/list` to `publicapi.yml` as the contract to implement server-side — optional `bandId` query filter (reuses existing `BandIdFilter` parameter), response `ListUserSetlistsResponseBody { items: UserSetlistListItem[] }` where each item extends `SetlistListItem` with `bandId` + `bandName`. Mirrors Phase 3's `GET /api/track/list` (D-01 in `03-CONTEXT.md`) exactly. — **Reversibility:** costly — **Rationale:** the new global Setlists tab (D-13/D-14 below) and its provider/screen are built directly against this shape.
- Tracked in REQUIREMENTS.md "API Gaps" as blocking new requirements **SETL-06** (bulk add) and **SETL-10** (global tab). Traceability and ROADMAP Phase 4 success criteria updated accordingly.

### Navigation & list display (per-band)
- **D-04:** A band's setlist list lives as a **separate screen** reached from Band detail (tap a "Setlists" entry → `SetlistListScreen(bandId)`) — mirrors Tracks' entry point (Phase 3 D-02).
- **D-05:** Per-band setlist list rows show **name + track count + duration + event date** (when set) — richer than Tracks' list (Phase 3 D-05) because event date is meaningful gig context here.
- **D-06:** Per-band setlist list sort order is **insertion order as returned by the API** — no client-side sort, matches Track precedent (Phase 3 D-07).
- **D-07:** A setlist row with no `eventDate` shows an explicit **"No date set"** placeholder rather than omitting the date area silently.

### Create setlist + initial tracks
- **D-08:** Create setlist is a **full-screen form** (not a dialog) — matches Create Band (Phase 2 D-10) and Add Track (Phase 3 D-08) precedent.
- **D-09:** The create form includes an **inline multi-select checklist** of the band's existing tracks to pick initial tracks, submitted as `trackIds` on the `POST /api/band/{bandId}/setlist` call (the API already supports this on creation, independent of D-01's new bulk-add-after-creation endpoint).
- **D-10:** `name`, `eventLocation`, and `eventDate` are **all always-visible fields** on the create form — no collapsible/progressive-disclosure section, matches Add Track's flat field list (Phase 3 D-08).
- **D-11:** After successfully creating a setlist, the user is navigated straight into the **setlist detail screen** — matches Create/Join Band's precedent (Phase 2 D-12).

### Track management on setlist detail
- **D-12:** Adding tracks to an existing setlist uses a **multi-select picker** (band's tracks not already in the setlist) that submits via the new bulk-add endpoint (D-01) in one call.
- **D-13:** Removing a track uses an **explicit remove icon per row** — no swipe-to-dismiss (this codebase doesn't use swipe gestures elsewhere).
- **D-14:** Drag-and-drop reordering calls `PUT .../tracks/reorder` with the full new `trackIds` order **immediately on each drop** — not batched behind a separate "Save order" action.
- **D-15:** The ordered track list has a **toggleable "Edit" mode** — normal view is read-only (track info only); tapping "Edit" reveals drag handles + remove icons on every row until the user exits edit mode. Drag handles and remove icons are not both shown in the default view.

### Edit & delete setlist
- **D-16:** Edit setlist is a **separate full-screen form**, mirroring the create form's layout minus the track picker (`name`/`eventLocation`/`eventDate`) — matches Track's separate create/edit screens (Phase 3 D-09), not a shared toggle widget.
- **D-17:** Setlist update calls must **always send all editable fields** (`name` + `eventLocation`-or-`null` + `eventDate`-or-`null`), never conditionally omit — the same server partial-update semantics fix established in Phase 3 (03-04 CR-02: omitted = keep, explicit `null` = clear) applies here since `UpdateBandSetlistRequestBody` has the identical nullable-optional-field shape.
- **D-18:** Delete setlist confirmation is a **lightweight Cancel/Confirm dialog** — matches Delete Track (Phase 3 D-11) and Leave/Remove-member (Phase 2 D-14), not Delete Band's type-to-confirm (Phase 2 D-13 reserves that friction for the one action that destroys shared data for every member).
- **D-19:** After deleting a setlist, the user returns to the **band's setlist list** (`SetlistListScreen(bandId)`) — matches Track (Phase 3 D-13) and Band (Phase 2 D-15) precedent.

### Global Setlists tab
- **D-20:** The global Setlists tab uses the **same flat-list + band-name badge + band filter dropdown** pattern as the Tracks tab (Phase 3 D-04) — not grouped-by-band section headers.
- **D-21:** The bottom nav is **reordered to Home / Bands / Tracks / Setlists / Profile** (currently Home / Tracks / Bands / Profile) — a deliberate reordering beyond just appending the new tab, decided during this discussion.

### Claude's Discretion
- None recorded as explicit "you decide" outcomes — every question in this discussion reached a concrete choice.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API contract
- `lib/api/publicapi.yml` — source of truth for all request/response shapes. Relevant for this phase:
  - `GET /api/band/{bandId}/setlist/list` → `ListBandSetlistsResponseBody` (`items: SetlistListItem[]`, each `id`/`name`/`tracksCount`/`durationSeconds` required + optional `eventDate`)
  - `POST /api/band/{bandId}/setlist` → `CreateBandSetlistsRequestBody` (`name` required; `eventLocation`/`eventDate`/`trackIds` optional, `trackIds` max 100) / `CreateBandSetlistsResponseBody` (`id`)
  - `GET /api/band/{bandId}/setlist/{setlistId}` → `BandSetlist` (`id`/`name`/`durationSeconds`/`tracks` required; `eventLocation`/`eventDate` optional; `tracks: SetlistTrackItem[]` each with `trackId`/`position`/`title`/`artist` required + optional `durationSeconds`)
  - `PUT /api/band/{bandId}/setlist/{setlistId}` → `UpdateBandSetlistRequestBody` (`name` optional; `eventLocation`/`eventDate` optional + nullable — see D-17)
  - `DELETE /api/band/{bandId}/setlist/{setlistId}`
  - `POST /api/band/{bandId}/setlist/{setlistId}/track` → `AddSetlistTrackRequestBody` (`trackId`, single) — existing single-add endpoint, superseded for the add-tracks UI by D-01's bulk endpoint but still valid API surface
  - `DELETE /api/band/{bandId}/setlist/{setlistId}/track/{trackId}` → remove one track
  - `PUT /api/band/{bandId}/setlist/{setlistId}/tracks/reorder` → `ReorderSetlistTracksRequestBody` (`trackIds: string[]`, full replace, max 100)
  - **New this phase (D-01):** `POST /api/band/{bandId}/setlist/{setlistId}/tracks` (bulk add) → `AddSetlistTracksRequestBody` (`trackIds: string[]`, max 100)
  - **New this phase (D-03):** `GET /api/setlist/list` (optional `bandId` query filter via existing `BandIdFilter` parameter) → `ListUserSetlistsResponseBody` (`items: UserSetlistListItem[]`, each extending `SetlistListItem` with required `bandId`/`bandName`)

### Project-level constraints
- `.planning/PROJECT.md` — "Constraints" section: reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns; offline scope is read-only cache; Android/iOS only, web excluded. "Key Decisions" table now includes this phase's two new API gaps.
- `.planning/REQUIREMENTS.md` — "Setlists" section (SETL-01 through SETL-10); "API Gaps" section documents the two new endpoints (D-01/D-03) alongside Phase 2/3's prior gaps, including the "no fallback, backend considered ready" posture (D-02).
- `.planning/ROADMAP.md` — Phase 4 success criteria (now includes the global Setlists tab, criterion 6) and scope boundary (offline staleness UI is Phase 5).

### Prior phase context (established patterns to extend, not re-decide)
- `.planning/phases/03-tracks/03-CONTEXT.md` — D-01 through D-04 (global-tab API-gap pattern and flat-list/band-badge/filter layout, directly mirrored by D-01/D-03/D-20 here), D-08/D-09 (full-screen separate create/edit forms), D-11/D-12/D-13 (lightweight delete confirm, detail-only delete trigger, post-delete navigation).
- `.planning/phases/02-bands/02-CONTEXT.md` — D-10 (full-screen create pattern), D-12 (post-create navigation to detail), D-13/D-14 (type-to-confirm vs. lightweight confirm), D-15 (post-destructive-action navigation).
- `.planning/phases/01-foundation-profile-home/01-CONTEXT.md` — D-01/D-02/D-03 (Hive-per-endpoint cache pattern, raw JSON storage), D-04 (cache-first loading), D-10 (Riverpod codegen via `riverpod_generator`/`@riverpod`).
- PROJECT.md Key Decisions — "Track/setlist mutation endpoints must always send all editable fields on update" (Phase 3, 03-04 CR-02) directly governs D-17 above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/providers/tracks_provider.dart` (or equivalent from Phase 3) — the reference implementation for a per-band-keyed cache-first provider plus a global cross-band provider with a `SelectedBandIdFilter` notifier; the new `SetlistListData`/`SetlistDetailData` and global-setlist providers should mirror this shape (per-band box + a separate global-list cache entry).
- `lib/cache/cache_service.dart` (`CacheService`) — add a `setlistsBox` (per-band setlist lists + detail) and a keyed store or box for the new global-setlists endpoint result (D-03), following the same generalized `_KeyValueStore` abstraction Phase 1-3 already extended.
- `lib/api/public_api.dart` (`PublicApi`) — needs new methods for setlist list/create/get/update/delete, add-track (single + new bulk), remove-track, reorder, and the new global list endpoint.
- `lib/features/tracks/` screens (list, add/edit forms, detail) — direct structural reference for the analogous setlist screens; the global Tracks tab screen is the direct template for the new global Setlists tab screen.
- `lib/providers/navigation_provider.dart` (`SelectedTabIndex`, Phase 3 03-04) — reusable pattern for switching `RootScaffold`'s bottom-nav tab without a direct reference to its state; relevant if any setlist flow needs to redirect into the new tab.

### Established Patterns
- Cache-first loading (Phase 1 D-04): show cached data immediately, background-refresh silently, no error surfaced on background-refresh failure — applies to per-band setlist list/detail and the new global setlists list.
- One Hive box per endpoint (Phase 1 D-02), raw decoded JSON (Phase 1 D-03) — no typed models/TypeAdapters; setlists follow the same no-typed-model convention as bands/tracks.
- Riverpod codegen (`@riverpod` + `riverpod_generator` + `build_runner`) for all new providers (Phase 1 D-10).
- `ApiException` (statusCode/code/message) caught at the UI layer — same error contract extends to setlist mutation calls.
- Mutation endpoints with nullable-optional fields must always send all editable fields, never conditionally omit (Phase 3 03-04 CR-02) — applies to `UpdateBandSetlistRequestBody` (D-17).

### Integration Points
- `lib/navigation/root_scaffold.dart` — bottom-nav gains a 5th "Setlists" destination and the whole tab order changes to Home/Bands/Tracks/Setlists/Profile (D-21).
- `lib/features/bands/band_detail_screen.dart` — gains a "Setlists" entry point (D-04) navigating to the new `SetlistListScreen(bandId)`, alongside the existing "Tracks" entry from Phase 3.
- A new `lib/features/setlists/` directory (mirroring `lib/features/tracks/`) holds the per-band list/detail/create/edit screens plus the new global setlists tab screen.

</code_context>

<specifics>
## Specific Ideas

- The global Setlists tab and the two new API-gap endpoints should mirror Phase 3's Tracks-tab precedent as closely as possible — same picker/filter UX, same "backend considered ready" posture pattern (though Phase 4 explicitly chose "no fallback" (D-02) rather than Phase 3's "block until shipped" posture for TRACK-06).
- Bottom nav reordering (D-21) is a deliberate, explicit choice made during this discussion, not an incidental side effect of adding the Setlists tab — don't revert to simple append-at-end.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (the global Setlists tab was accepted as an expansion consistent with Phase 3's precedent, not deferred).

### Reviewed Todos (not folded)
None — no pending todos matched this phase (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 4-Setlists*
*Context gathered: 2026-08-16*
