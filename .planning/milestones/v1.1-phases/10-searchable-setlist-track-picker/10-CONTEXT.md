# Phase 10: Searchable Setlist Track Picker - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can quickly find and add the right track to a setlist even when the band has many tracks. The existing all-tracks static-list dialog (`AddSetlistTracksDialog`) gains a search field that filters the visible track checklist. `publicapi.yml`'s `ListBandTracks` gains a documented `searchQuery` request field — client-side spec extension only; the backend does not implement server-side filtering this milestone (SETL-12). No new capabilities beyond search-filtering this one picker — not a redesign of the multi-select/add flow, not a change to track list/detail screens elsewhere in the app.

</domain>

<decisions>
## Implementation Decisions

### Picker layout

- **D-01:** Keep the existing `AlertDialog` shell in `add_setlist_tracks_dialog.dart` — add a search `TextField` above the existing `ListView.builder` checklist. No full-screen picker page; this is additive to the current dialog structure (same actions row, same `CheckboxListTile` list).

### Search matching

- **D-02:** Search matches on **title + artist** (substring, case-insensitive) — consistent with `ListUserTracksRequestBody`'s documented `searchQuery` behavior ("Search by artist or title match"). Not title-only.

### searchQuery spec wiring — **Reversibility: costly** — this sets the wire contract and provider shape; switching between "doc-only" and "sends over the wire" later means reworking the request method and provider keying, and once a debounced network path exists other code may come to depend on its request cadence.

- **D-03:** `publicapi.yml`'s `ListBandTracks` gains a `searchQuery` field, and the client **actually sends it** as a GET query parameter on `/api/band/{bandId}/track/list?searchQuery=...` — not doc-only. The backend currently ignores it and returns the full unfiltered list; this is accepted as forward-compatible wiring for when the backend implements filtering later.
- **D-04:** The request is **debounced 300ms** as the user types, to avoid firing a network request on every keystroke.
- **D-05:** **Online:** rely on the (currently unfiltered) server response as-is — no client-side re-filtering of the response while online, even though this means search doesn't visibly filter results yet this milestone until the backend catches up. **Offline:** the picker filters the cached track list **locally** (title+artist substring match per D-02) since there's no network round-trip to rely on — this is the only path where search visibbly works this milestone.
- **D-06:** This is a real, accepted product tradeoff for this milestone — flagged in `STATE.md`'s existing Blockers/Concerns note about `searchQuery` needing graceful degradation until backend support ships. Online search behavior (no visible filtering) should not be treated as a bug during verification.

### Empty-results state

- **D-07:** A distinct **"No tracks match"** message (or equivalent wording) shows when a search query is active and the (locally filtered, offline) list yields zero matches — kept separate from the existing "No more tracks available" message (which means every band track is already in the setlist, unrelated to search).

### Claude's Discretion

- Exact debounce implementation mechanism (`Timer`, `Debouncer` utility class, etc.) — no specific pattern mandated in the codebase yet for this.
- Whether the debounced request keys into a new/separate Riverpod provider family (e.g. `trackListDataProvider(bandId, searchQuery)`) or bypasses the family cache entirely for search calls — `trackListDataProvider(bandId)` is currently shared across `add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `track_list_screen.dart`, `create_track_screen.dart`, and edit/delete flows; the planner/researcher should design this to avoid polluting or invalidating the shared base list cache used by those other screens.
- Exact search-field styling/placement (e.g. `TextField` with search icon prefix, placeholder text) — standard Material search field styling, consistent with app's existing form-field conventions.
- Whether the offline client-side filter also silently no-ops the debounce/network call while offline (to avoid a wasted request attempt), or the debounce timer still fires and fails silently — mechanical connectivity-check detail, no product decision attached beyond D-05's offline-filters-locally requirement.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml` — `ListBandTracks` operation (~line 290) and `ListBandTracksResponseBody`/`TrackListItem` schemas (~line 870) are the current GET-only, no-query-param contract to extend with a `searchQuery` query parameter (D-03). Reference `ListUserTracksRequestBody` (~line 970, "Search by artist or title match") as the wording/behavior precedent for the new field's description.
- `lib/api/public_api.dart:169` — `listBandTracks(String bandId)` is the Dart method to extend with an optional `searchQuery` parameter, appended as a query string on the existing `GET /api/band/$bandId/track/list` call.

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — SETL-12 (full acceptance text: search field replaces static list dialog; filters as user types; `searchQuery` documented as client-side spec extension, backend implementation deferred)
- `.planning/ROADMAP.md` §"Phase 10: Searchable Setlist Track Picker" — 3 success criteria (search field replaces flat dialog; typing filters visible list; `ListBandTracks` spec documents `searchQuery`), independent phase, sequenced last per research
- `.planning/STATE.md` Blockers/Concerns — existing note flagging that the picker must degrade gracefully client-side until backend `searchQuery` support ships; this phase's D-05/D-06 are the concrete resolution of that concern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/setlists/add_setlist_tracks_dialog.dart` (full file) — the dialog being modified; existing `CheckboxListTile` checklist, `remainingSlots`/100-track-cap guard (WR-03 from a prior review), `_errorMessage`/`_isSubmitting` state pattern, and the `trackListDataProvider(widget.bandId)`-backed `AsyncValue.when()` loading/error/data branches all stay as-is — only the `data:` branch content changes to add the search field + filtered list.
- `lib/providers/tracks_provider.dart` (+ generated `tracks_provider.g.dart`) — `trackListDataProvider` family, currently keyed by `bandId` only and shared across 6+ call sites (`add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `track_list_screen.dart`, `create_track_screen.dart`, `confirm_delete_track_dialog.dart`, `edit_track_screen.dart`) — any provider-shape change for search must not disrupt these other consumers' existing cache/invalidate behavior.
- `lib/providers/connectivity_provider.dart` (`isOnlineProvider`) — already used in `add_setlist_tracks_dialog.dart` to gate the Add button; same provider is the natural signal for the online/offline branch in D-05.

### Established Patterns
- Online-first caching (Phase 7, OFFL-07/OFFL-08): online always re-fetches fresh; offline serves last-fetched cache. D-05's online/offline split for search follows this same established branch, just applied to search-request behavior specifically.
- `ApiException` catch + generic fallback message pattern (see `_submit()` in `add_setlist_tracks_dialog.dart`) — reused as-is if the search request path can fail.

### Integration Points
- `lib/features/setlists/add_setlist_tracks_dialog.dart` — primary (likely only) file changed for the UI/search-field wiring.
- `lib/api/public_api.dart` — `listBandTracks()` method signature changes to accept optional `searchQuery`.
- `lib/api/publicapi.yml` — spec extension for `ListBandTracks` (query parameter + description).
- `lib/providers/tracks_provider.dart` — provider family shape may need to change to key on `(bandId, searchQuery)` or otherwise isolate search-triggered fetches from the shared base list cache (see Claude's Discretion).

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants the debounced network request sent now, "backend will catch up" later — this is a deliberate bet on forward compatibility, not an oversight. Don't second-guess this as a "wasted request" during planning/execution — it's intentional per D-03/D-06.
- Client-side filtering as a fallback is scoped specifically to the **offline** case, not as a general safety net while online (D-05) — the user was explicit that online should trust the wire request only, and offline is where local filtering kicks in.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The full-screen picker layout alternative was considered and explicitly rejected in favor of keeping the existing dialog (D-01), not deferred to a future phase.

</deferred>

---

*Phase: 10-Searchable Setlist Track Picker*
*Context gathered: 2026-08-22*
