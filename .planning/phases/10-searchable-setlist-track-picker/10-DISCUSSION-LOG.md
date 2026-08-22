# Phase 10: Searchable Setlist Track Picker - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-22
**Phase:** 10-Searchable Setlist Track Picker
**Areas discussed:** Picker layout, Search matching, searchQuery spec wiring, Empty-results state

---

## Picker layout

| Option | Description | Selected |
|--------|-------------|----------|
| Keep AlertDialog, add search field on top | Minimal change — TextField above the existing ListView.builder checklist, same dialog shell/actions. | ✓ |
| Full-screen picker page | Bigger rework: new screen instead of dialog, more room, but breaks from the existing dialog-based pattern used everywhere else in the app. | |

**User's choice:** Keep AlertDialog, add search field on top
**Notes:** None.

---

## Search matching

| Option | Description | Selected |
|--------|-------------|----------|
| Title + artist | Consistent with ListUserTracksRequestBody's documented searchQuery behavior — substring, case-insensitive match on either field. | ✓ |
| Title only | Simpler, but diverges from the search behavior already documented for the analogous ListUserTracks endpoint. | |

**User's choice:** Title + artist
**Notes:** None.

---

## searchQuery spec wiring

| Option | Description | Selected |
|--------|-------------|----------|
| Doc-only, client filters locally | publicapi.yml documents searchQuery for future backend use; listBandTracks() dart method unchanged, client filters the already-cached list locally as user types. | |
| Send it over the wire now | listBandTracks() appends ?searchQuery=... to the GET request today; server ignores it (harmless) but every keystroke would trigger a real network request. | ✓ (with follow-up) |

**User's choice:** "send it and implement debounce now - backend will catch up" (free-text)
**Notes:** Follow-up questions asked to pin down exact behavior:

- **Fallback filtering:** Asked whether the client should also filter the (unfiltered-by-backend) response locally as a fallback so search actually works today.
  | Option | Selected |
  |--------|----------|
  | Yes, keep client-side filter as fallback (always) | |
  | No, trust the wire request only | |

  User's actual answer (free-text): "do client-side filtering only if there's no network" — a third option not offered, refining to an online/offline split rather than always-on or never. Captured as D-05/D-06 in CONTEXT.md.

- **Debounce duration:**
  | Option | Selected |
  |--------|----------|
  | 300ms | ✓ |
  | 500ms | |

  User's choice: 300ms.

---

## Empty-results state

| Option | Description | Selected |
|--------|-------------|----------|
| Distinct "No tracks match" message | New message shown only when a search query is active and yields zero matches, kept separate from the existing "No more tracks available" message. | ✓ |
| Reuse existing "No more tracks available" message | Same message for both zero-matches-from-search and all-tracks-already-added cases. | |

**User's choice:** Distinct "No tracks match" message
**Notes:** None.

---

## Claude's Discretion

- Exact debounce implementation mechanism (`Timer`, `Debouncer` utility class, etc.)
- Whether the debounced request keys into a new/separate Riverpod provider family or bypasses the shared `trackListDataProvider(bandId)` cache for search calls
- Exact search-field styling/placement
- Whether the offline path also no-ops the debounce/network call, or lets it fire and fail silently

## Deferred Ideas

None — discussion stayed within phase scope. Full-screen picker layout was considered and explicitly rejected (not deferred).
