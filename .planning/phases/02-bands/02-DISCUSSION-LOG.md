# Phase 2: Bands - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-15
**Phase:** 2-Bands
**Areas discussed:** API gap: owner-gating & self-leave, Band list & detail — data & caching, Create & join band flow, Destructive actions — delete/leave/remove-member

---

## API gap: owner-gating & self-leave

| Option | Description | Selected |
|--------|-------------|----------|
| Ready — build against real fields | Read `id`/`ownerId` directly, no fallback | ✓ |
| Not ready — build the fallback | Username-match self-leave, always-show + 403 for owner actions | |
| Build against real fields, but degrade gracefully | Use fields when present, fall back if missing/null | |

**User's choice:** Ready — build against real fields
**Notes:** Backend considered ready; no defensive fallback built.

| Option | Description | Selected |
|--------|-------------|----------|
| Hidden for non-owners | Owner-only actions not shown at all to non-owners | ✓ |
| Shown disabled with explanation | Grayed out with tooltip | |

**User's choice:** Hidden for non-owners

| Option | Description | Selected |
|--------|-------------|----------|
| Owner can't leave — delete only | Leave hidden/disabled for owner | ✓ |
| Owner can leave like anyone else | Show leave for everyone, let API handle it | |

**User's choice:** Owner can't leave — delete only

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing profile provider | Read current-user id from Phase 1's cache-first `profileProvider` | ✓ |
| Fetch fresh per band screen | New `/api/me` call each time | |

**User's choice:** Reuse existing profile provider

---

## Band list & detail — data & caching

| Option | Description | Selected |
|--------|-------------|----------|
| Name only | Matches `BandListItem` exactly | |
| Name + placeholder avatar/initial | Same data, avatar for scannability | ✓ |

**User's choice:** Name + placeholder avatar/initial
**Notes:** User flagged that future MVPs will add real image avatars — factored into the avatar-widget decision below.

| Option | Description | Selected |
|--------|-------------|----------|
| Cache list + per-band detail | New `bandsBox` + per-band keyed detail cache | ✓ |
| Cache list only | Detail always requires live network | |

**User's choice:** Cache list + per-band detail

| Option | Description | Selected |
|--------|-------------|----------|
| Show cached detail if present, then refresh | Cache-first, matches Phase 1's D-04 | ✓ |
| Always show loading spinner first | Ignore cache for this screen | |

**User's choice:** Show cached detail if present, then refresh

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — reusable BandAvatar widget | Dedicated widget file, swappable later | ✓ |
| No — inline is fine for now | Inline CircleAvatar+initial | |

**User's choice:** Yes — reusable BandAvatar widget

---

## Create & join band flow

| Option | Description | Selected |
|--------|-------------|----------|
| Single FAB → action menu | One FAB opens Create/Join menu | ✓ |
| Two separate buttons | Both actions independently visible | |

**User's choice:** Single FAB → action menu

| Option | Description | Selected |
|--------|-------------|----------|
| Dialog | Modal with name field | |
| Full screen | Dedicated screen | ✓ |

**User's choice (Create band UI):** Full screen

| Option | Description | Selected |
|--------|-------------|----------|
| Dialog | Modal with invite-code field | ✓ |
| Full screen | Dedicated screen | |

**User's choice (Join band UI):** Dialog

| Option | Description | Selected |
|--------|-------------|----------|
| Back to list, new band visible | Return to refreshed list | |
| Navigate straight into band detail | Jump into the new/joined band's detail | ✓ |

**User's choice:** Navigate straight into band detail

---

## Destructive actions — delete/leave/remove-member

| Option | Description | Selected |
|--------|-------------|----------|
| Standard confirm dialog | Cancel/Delete AlertDialog | |
| Type-to-confirm | Must type band name to enable Delete | ✓ |

**User's choice (Delete band):** Type-to-confirm

| Option | Description | Selected |
|--------|-------------|----------|
| Same standard confirm dialog as delete | (Superseded — see follow-up below) | |
| Simple generic yes/no | Generic "Are you sure?" | |

**Note:** Initial answer ("Same standard confirm dialog as delete") was ambiguous once Delete itself became type-to-confirm. Follow-up question asked directly:

| Option | Description | Selected |
|--------|-------------|----------|
| Lighter standard dialog (no typing) | Normal Cancel/Confirm with interpolated copy, type-to-confirm reserved for Delete only | ✓ |
| Same type-to-confirm as delete | Leave/Remove-member also require typing | |

**User's choice (Leave / Remove-member):** Lighter standard dialog (no typing)

**Claude's note (not asked — single viable option):** After deleting/leaving a band, the user is returned to the Bands list. No genuine alternative existed here, so this wasn't put to the user as a question; recorded directly in CONTEXT.md as D-15.

---

## Claude's Discretion

- Bottom-sheet/menu styling for the FAB's Create/Join action menu.
- `BandAvatar` widget's initial-letter rendering details (color, sizing).
- Empty-state copy/layout for "no bands yet" on the list screen (follows Phase 1's established empty/error-state pattern).

## Deferred Ideas

- Real image avatars for bands (mentioned as a future-milestone plan by the user) — not a deferred *capability* for this phase, just informed the avatar-widget's reusability design (D-06 in CONTEXT.md). No separate phase needed yet.
