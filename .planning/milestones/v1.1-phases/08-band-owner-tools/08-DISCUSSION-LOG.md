# Phase 8: Band Owner Tools - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-21
**Phase:** 8-Band Owner Tools
**Areas discussed:** New-owner picker UI, Transfer confirmation depth, Rotate invite code UX, Post-action state & landing

---

## New-owner picker UI

| Option | Description | Selected |
|--------|-------------|----------|
| Per-row action | Icon button on each non-owner member row, mirroring the existing person_remove icon | ✓ |
| Dedicated list item + picker | A "Transfer ownership" ListTile that opens a dialog listing members to choose from | |
| You decide | Claude picks based on layout fit | |

**User's choice:** Per-row action.

**Follow-up 1 — Row icon:**

| Option | Description | Selected |
|--------|-------------|----------|
| Icons.workspace_premium / "crown" icon | Distinct from red destructive person_remove icon | ✓ |
| Text button "Make owner" | Explicit label, costs more horizontal space | |
| You decide | Claude picks a semantically clear icon | |

**User's choice:** crown-style icon.

**Follow-up 2 — Row layout with two actions:**

| Option | Description | Selected |
|--------|-------------|----------|
| Row of two icons | Both visible side by side | |
| Overflow menu (PopupMenuButton) | Single "⋮" icon opens a menu with both actions | ✓ |
| You decide | Claude picks based on overflow risk | |

**User's choice:** Overflow menu (PopupMenuButton).

**Follow-up 3 — Does Remove's own behavior change once it's a menu item?**

| Option | Description | Selected |
|--------|-------------|----------|
| No change — same confirm dialog | Only entry point moves from icon to menu item | ✓ |
| You decide | | |

**User's choice:** No change — same confirm dialog.

**Notes:** Member row trailing slot converts from a standalone remove icon to a PopupMenuButton holding "Make owner" (crown icon) and "Remove" (unchanged behavior).

---

## Transfer confirmation depth

| Option | Description | Selected |
|--------|-------------|----------|
| Single AlertDialog | Same weight as ConfirmRemoveMemberDialog | |
| Single dialog + explicit consequence line | Body explicitly states "You will no longer be the owner" | ✓ |
| Typed confirmation | User must type new owner's username before button enables | |

**User's choice:** Single dialog + explicit consequence line.

**Follow-up — Dialog error/loading behavior:**

| Option | Description | Selected |
|--------|-------------|----------|
| Match ConfirmRemoveMemberDialog exactly | _isSubmitting spinner, ApiException.message inline, isOnline-gated | ✓ |
| You decide | | |

**User's choice:** Match ConfirmRemoveMemberDialog exactly.

**Notes:** Transfer is the only owner-tool action that demotes the *acting* user — dialog copy must say so explicitly, not just describe the effect on the target member.

---

## Rotate invite code UX

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm dialog first | Warns the current code will stop working before rotating | ✓ |
| Direct action, no dialog | Fires immediately, feedback via snackbar only | |

**User's choice:** Confirm dialog first.

**Follow-up 1 — Where does Rotate live in the Invite Code row?**

| Option | Description | Selected |
|--------|-------------|----------|
| Third button next to Copy | [code text] [Copy] [Rotate] as separate buttons | |
| Icon button next to Copy | Icon-only, saves horizontal space | |
| You decide | | |

**User's free-text answer:** "make them both icons, the copy icon and rotate icon (little arrow circle)" — user asked for *both* Copy and Rotate to become icon buttons (Copy converts from its current TextButton), Rotate using a circular-arrow icon.

**Follow-up 2 — Post-rotate feedback:**

| Option | Description | Selected |
|--------|-------------|----------|
| Row updates in place + snackbar | Local patch via newInviteCode response, plus confirmation snackbar | ✓ |
| Row updates in place, no snackbar | Visible code change considered sufficient feedback | |

**User's choice:** Row updates in place + snackbar.

---

## Post-action state & landing

| Option | Description | Selected |
|--------|-------------|----------|
| Local patch using known target userId | Optimistic client-side ownerId patch, no refetch | |
| Invalidate and refetch bandDetailDataProvider | Trust server as source of truth, same pattern ConfirmRemoveMemberDialog already uses | ✓ |

**User's choice:** Invalidate and refetch bandDetailDataProvider.

**Follow-up 1 — Bands-tab list staleness:**

| Option | Description | Selected |
|--------|-------------|----------|
| Patch bandsListDataProvider too | Mirrors renameBand()'s in-place list patch, using known target userId | ✓ |
| Leave it — accept the staleness window | Same posture as Phase 7 D-05's simplicity tradeoff | |

**User's choice:** Patch bandsListDataProvider too.

**Follow-up 2 — Landing/navigation after either action:**

| Option | Description | Selected |
|--------|-------------|----------|
| Stay on band_detail_screen | Dialog closes, screen re-renders in place, no navigation | ✓ |
| You decide | | |

**User's choice:** Stay on band_detail_screen.

**Notes:** Rotate doesn't need a matching list-side patch — `BandListItem` has no `inviteCode` field.

---

## Claude's Discretion

- Exact Material icon for "Make owner" (crown-style) and Rotate (circular-arrow style) — no specific icon name mandated.
- `PopupMenuButton` internal structure/styling — mechanical widget choice.
- Whether/how `BandDetailData`'s existing `_version` monotonic-counter guard needs to be bumped inside the new rotate-patch and transfer-invalidate methods — the guard itself must be preserved, exact wiring left to planner/executor.

## Deferred Ideas

None — discussion stayed within phase scope. Homepage quick actions (Phase 9) and the searchable setlist track picker (Phase 10) were not raised as scope creep during this discussion.
