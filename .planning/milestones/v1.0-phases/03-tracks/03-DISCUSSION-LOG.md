# Phase 3: Tracks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-16
**Phase:** 3-Tracks
**Areas discussed:** Navigation entry point, Track list display, Add/edit track form, Delete track confirmation

---

## Navigation entry point

| Option | Description | Selected |
|--------|-------------|----------|
| Section in Band detail screen | Add a Tracks section/button to the existing Band detail screen | ✓ |
| Songs tab → band picker → tracks | Keep global tab, add a band-picker screen | |
| You decide | | |

**User's choice:** Section in Band detail screen (as the per-band entry point).

**Follow-up — fate of the global "Songs" placeholder tab:**

| Option | Description | Selected |
|--------|-------------|----------|
| Remove it | Bottom nav becomes Home/Bands/Profile | |
| Leave as-is | Out of scope, don't touch nav | |
| You decide | | |

**User's free-text response:** "rename to tracks and use as all songs from user's bands display. add open api missing endpoint for all tracks of the user with filters (only by band for now)"

**Notes:** This expanded scope beyond the original per-band-only Phase 3 boundary (TRACK-01–05 in REQUIREMENTS.md are all per-band). Flagged as scope creep per the scope guardrail — user chose to fold it into this phase rather than defer:

| Option | Description | Selected |
|--------|-------------|----------|
| Add to this phase (like Phase 2's API gap) | Add missing endpoint directly to publicapi.yml, document in REQUIREMENTS.md API Gaps, build against it now | ✓ |
| Defer to its own phase/backlog | Note as deferred idea, keep Phase 3 per-band-only | |
| You decide | | |

**Resulting decision:** New requirement TRACK-06 added; `GET /api/track/list` added to `publicapi.yml`; REQUIREMENTS.md and ROADMAP.md updated. See CONTEXT.md D-01.

**Follow-up — new endpoint response shape:**

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — bandId + bandName per track | Extends TrackListItem for display/grouping and the filter param | ✓ |
| No — raw TrackListItem only | | |
| You decide | | |

**Follow-up — Band detail Tracks presentation:**

| Option | Description | Selected |
|--------|-------------|----------|
| Separate screen (tap 'Tracks' → TrackListScreen(bandId)) | Mirrors Edit Band's full-screen pattern | ✓ |
| Inline section below members | Single scrollable page | |
| You decide | | |

---

## Track list display

**Per-band row fields:**

| Option | Description | Selected |
|--------|-------------|----------|
| Duration only | Title, artist, duration — matches TrackListItem's actual schema (no tempo/key on list item) | ✓ |
| Duration + tempo + key | Denser subtitle line | |
| You decide | | |

**Duration format:**

| Option | Description | Selected |
|--------|-------------|----------|
| mm:ss (e.g. 3:45) | Standard music-app convention, computed client-side | ✓ |
| Raw seconds/minutes label | e.g. '225s' or '3 min' | |
| You decide | | |

**Sort order:**

| Option | Description | Selected |
|--------|-------------|----------|
| Alphabetical by title | Predictable, easy to scan | |
| Insertion order (as returned by API) | No client-side sort logic | ✓ |
| You decide | | |

**Global tab band presentation:**

| Option | Description | Selected |
|--------|-------------|----------|
| Grouped by band (section headers) | Sticky section titles per band | |
| Flat list + band-name badge per row, with filter dropdown | Single scrollable list, filter via bandId query param | ✓ |
| You decide | | |

---

## Add/edit track form

**Form type:**

| Option | Description | Selected |
|--------|-------------|----------|
| Full screen | Consistent with Create Band (D-10); 6 fields too much for a dialog | ✓ |
| Dialog | Matches Join Band's single-field pattern, doesn't fit 6 fields | |
| You decide | | |

**Add vs. edit screen structure:**

| Option | Description | Selected |
|--------|-------------|----------|
| One shared form screen | Optional existing-track param toggles create/edit mode | |
| Separate screens | CreateTrackScreen / EditTrackScreen, mirrors Create/Edit Band being separate | ✓ |
| You decide | | |

**Key field input:**

| Option | Description | Selected |
|--------|-------------|----------|
| Free text field | Matches API schema (key: string, no enum) | |
| Dropdown of standard keys | Constrained picker, client-only convention | ✓ |
| You decide | | |

**Key dropdown scope:**

| Option | Description | Selected |
|--------|-------------|----------|
| 12 roots + major/minor toggle | 24 combinations (C, Cm, C#, C#m, ... B, Bm) | ✓ |
| 12 roots only | No major/minor distinction | |
| You decide | | |

---

## Delete track confirmation

**Confirmation style:**

| Option | Description | Selected |
|--------|-------------|----------|
| Lightweight Cancel/Confirm dialog | Matches Leave/Remove-member (D-14) | ✓ |
| Type-to-confirm | Same friction as Delete band (D-13) | |
| You decide | | |

**Delete entry point:**

| Option | Description | Selected |
|--------|-------------|----------|
| Track detail screen only | Mirrors Delete Band living on Band detail | ✓ |
| Both detail screen and swipe-to-dismiss in list | Faster catalog cleanup | |
| You decide | | |

**Post-delete navigation:**

| Option | Description | Selected |
|--------|-------------|----------|
| Back to the (band) track list | Mirrors D-15 (delete/leave band → Bands list) | ✓ |
| You decide | | |

---

## Claude's Discretion

None — every question in this discussion reached a concrete user choice.

## Deferred Ideas

None — the one scope-expanding idea raised (global cross-band Tracks tab) was folded into this phase's scope (TRACK-06) rather than deferred; see "Navigation entry point" above.
