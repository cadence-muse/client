# Phase 4: Setlists - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-16
**Phase:** 4-Setlists
**Areas discussed:** Navigation & list display, Create setlist + initial tracks, Add/remove/reorder tracks on detail, Edit & delete setlist, Global Setlists tab (added mid-discussion)

---

## Navigation & list display

| Option | Description | Selected |
|--------|-------------|----------|
| Separate screen | Tap a "Setlists" entry on Band detail → SetlistListScreen(bandId), mirrors Tracks (Phase 3 D-02) | ✓ |
| Inline section | Setlists shown as a section directly on Band detail | |

**User's choice:** Separate screen

| Option | Description | Selected |
|--------|-------------|----------|
| Name + count + duration | Minimal, matches SETL-01 literal wording | |
| Name + count + duration + date | Adds event date when set | ✓ |

**User's choice:** Name + count + duration + date

| Option | Description | Selected |
|--------|-------------|----------|
| Insertion order | As returned by API, matches Track precedent (Phase 3 D-07) | ✓ |
| By event date, soonest first | Client-side sort, dateless last | |

**User's choice:** Insertion order

| Option | Description | Selected |
|--------|-------------|----------|
| Omit it | No date-related text when eventDate absent | |
| "No date set" placeholder | Explicit placeholder text | ✓ |

**User's choice:** "No date set" placeholder

---

## Create setlist + initial tracks

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen form | Matches Create Band/Add Track precedent | ✓ |
| Dialog | Lighter-weight | |

**User's choice:** Full-screen form

| Option | Description | Selected |
|--------|-------------|----------|
| Skip on create, add after | Tracks added afterward from detail screen | |
| Inline multi-select checklist | Checklist of band's tracks, submitted as trackIds on creation | ✓ |

**User's choice:** Inline multi-select checklist

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible | Name, eventLocation, eventDate all shown from the start | ✓ |
| Collapsible "add details" | Only Name shown by default | |

**User's choice:** Always visible

| Option | Description | Selected |
|--------|-------------|----------|
| Setlist detail screen | Navigates straight into new setlist's detail, matches Band precedent (Phase 2 D-12) | ✓ |
| Back to setlist list | Returns to list | |

**User's choice:** Setlist detail screen

---

## Add/remove/reorder tracks on detail

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-select picker, looped calls | One POST per selected track | |
| Single-select, add one at a time | Picker stays open, one at a time | |
| (User-proposed) Multi-select picker + new bulk-add API endpoint | User requested adding a missing bulk-add endpoint to the OpenAPI schema instead of looping single calls | ✓ |

**User's choice:** Multi-select picker; identified API gap — new bulk-add endpoint added to `publicapi.yml`.
**Notes:** Followed up with two clarifying questions:
1. Endpoint shape confirmation — proposed `POST /api/band/{bandId}/setlist/{setlistId}/tracks` with `{ trackIds: string[] }` (max 100), mirroring the existing bulk `trackIds` field on setlist creation and the reorder endpoint. User confirmed: "Yes, that shape."
2. Fallback posture if backend isn't ready — user chose "consider it already supported on backend, no fallbacks. whole app is a work in progress" — i.e. build directly against the new endpoint, no client-side fallback loop (mirrors Phase 2 D-01's posture, not Phase 3 TRACK-06's "block until shipped" posture).

Endpoint and `AddSetlistTracksRequestBody` schema added directly to `lib/api/publicapi.yml`.

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe-to-dismiss on row | Quick, no extra tap | |
| Explicit remove icon per row | Matches project's "explicit action" pattern | ✓ |

**User's choice:** Explicit remove icon per row

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately per drop | Full reordered trackIds PUT right away on each drop | ✓ |
| Explicit "Save order" action | Batched behind a separate save action | |

**User's choice:** Immediately per drop

| Option | Description | Selected |
|--------|-------------|----------|
| Both always visible | Drag handle + remove icon shown simultaneously | |
| Toggle "Edit" mode | Read-only by default, "Edit" reveals both | ✓ |

**User's choice:** Toggle "Edit" mode

---

## Edit & delete setlist

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen, mirrors create | Separate EditSetlistScreen, same fields minus track picker | ✓ |
| Dialog | Lighter form | |

**User's choice:** Full-screen, mirrors create

| Option | Description | Selected |
|--------|-------------|----------|
| Lightweight Cancel/Confirm | Matches Delete Track/Leave-Band precedent | ✓ |
| Type-to-confirm | Matches Delete Band's heavier friction | |

**User's choice:** Lightweight Cancel/Confirm

| Option | Description | Selected |
|--------|-------------|----------|
| Band's setlist list | Returns to SetlistListScreen(bandId), matches Track/Band precedent | ✓ |
| Something else | — | |

**User's choice:** Band's setlist list

---

## Global Setlists tab (raised during "anything else?" check)

**User's prompt:** "setlists section in the bottom nav" — flagged as a new-capability question (mirrors Phase 3's TRACK-06 global-tab precedent) rather than assumed in scope.

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom-nav tab (global) | New capability, cross-band setlist view with band filter, requires roadmap/requirements amendment + new API endpoint | ✓ |
| Per-band only, no nav tab | Stays as already decided this discussion — no bottom-nav change | |

**User's choice:** Bottom-nav tab (global)
**Notes:** Treated identically to Phase 3's TRACK-06 amendment — added SETL-10 to REQUIREMENTS.md, updated ROADMAP.md Phase 4 success criteria and PROJECT.md Active requirements/Key Decisions, and added a matching API gap (`GET /api/setlist/list`) to `publicapi.yml`.

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern as Tracks tab | Flat list, band-name badge, filter dropdown | ✓ |
| Different layout | — | |

**User's choice:** Same pattern as Tracks tab

**Tab position/order:** Initial options offered ("Setlists after Tracks" / "Setlists after Bands") were both declined — user requested a full reorder instead: "actually change the whole order to Home / Bands / Tracks / Setlists / Profile". Captured as D-21 (reorders existing Bands/Tracks tabs too, not just appending Setlists).

---

## Claude's Discretion

None — every question in this discussion reached a concrete choice.

## Deferred Ideas

None — the global Setlists tab was accepted as an in-scope expansion (consistent with Phase 3 precedent), not deferred to a future phase.
