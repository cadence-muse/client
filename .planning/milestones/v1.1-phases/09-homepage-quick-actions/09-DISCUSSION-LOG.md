# Phase 9: Homepage Quick Actions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-22
**Phase:** 9-Homepage Quick Actions
**Areas discussed:** Quick action placement, Band-picker dialog design, Zero/one-band edge cases, Post-selection navigation

---

## Quick action placement

| Option | Description | Selected |
|--------|-------------|----------|
| Button row | Three buttons below welcome text, simplest, always visible | ✓ |
| FAB + bottom sheet | Single FAB opening a bottom-sheet menu, mirrors bands_screen.dart | |
| AppBar action icons | Compact icon buttons in the AppBar | |

**User's choice:** Button row
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Icon + label chips | Icon and text together | ✓ |
| Icon-only, compact | Just icons with tooltips | |

**User's choice:** Icon + label chips
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible near top | Actions show above/near welcome text regardless of band count | |
| Replace zero-bands empty state's single button | Zero-bands state also gets the full 3-action layout | |
| (free text) | User described a specific layout instead of picking an offered option | ✓ |

**User's choice:** "put welcome text at top in a rounded rectangle (for future improvements on it like adding user avatar in greeting), below it a header (Quick Actions) and then the buttons"
**Notes:** This layout applies uniformly to zero-bands and populated states, effectively resolving both offered options at once (captured as D-01/D-03 in CONTEXT.md).

| Option | Description | Selected |
|--------|-------------|----------|
| Coexist, no change to bands_screen (recommended) | Home gets its own quick actions; bands_screen's FAB stays as-is | ✓ |
| You decide | Leave the relationship to Claude's discretion | |

**User's choice:** Coexist, no change to bands_screen
**Notes:** None

---

## Band-picker dialog design

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom sheet list | Mirrors bands_screen.dart's _showCreateJoinMenu | ✓ |
| AlertDialog list | Modal dialog with a scrollable band list | |

**User's choice:** Bottom sheet list
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Band name only | Simple ListTile, name only | ✓ |
| Name + member count/role | Matches bands_screen.dart's row content | |

**User's choice:** Band name only
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse bandsListDataProvider (recommended) | Same cached/online-first provider as bands_screen.dart | ✓ |
| Fresh fetch on open | Independent publicApi.listBands() call each time | |

**User's choice:** Reuse bandsListDataProvider
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, using cached data with normal offline banner | Same posture as rest of app, no special-case needed | ✓ |
| You decide | Leave offline wiring to planner/executor | |

**User's choice:** Yes, using cached data with normal offline banner
**Notes:** None

---

## Zero/one-band edge cases

| Option | Description | Selected |
|--------|-------------|----------|
| Button disabled | Add song/setlist greyed out at 0 bands | ✓ |
| Tappable, shows a message | Buttons stay enabled, tapping shows a message | |

**User's choice:** Button disabled
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Skip the picker | Auto-select the single band, go straight to create screen | |
| Always show the picker | Picker always shows regardless of band count | ✓ |

**User's choice:** Always show the picker
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Never hidden, only disabled | All 3 buttons always render, disabled state carries the 0-band case | ✓ |
| You decide | Leave hide-vs-disable specifics to planner/executor | |

**User's choice:** Never hidden, only disabled
**Notes:** None

---

## Post-selection navigation

| Option | Description | Selected |
|--------|-------------|----------|
| Direct push (recommended) | Navigator.push straight to the create screen, same pattern as bands_screen.dart | ✓ |
| You decide | Leave push mechanics to planner/executor | |

**User's choice:** Direct push (recommended)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| No special handling needed | Home already re-fetches on tab-switch (Phase 7 D-01) | ✓ |
| You decide | Leave it to planner/executor if edge cases turn up | |

**User's choice:** No special handling needed
**Notes:** A third question in this batch ("what happens on bottom-sheet dismiss without picking") was dropped before asking — it had only one genuine answer (standard dismiss, no action) and is recorded directly in CONTEXT.md as D-08 rather than as an asked question.

---

## Claude's Discretion

- Exact Material icons for the 3 quick-action buttons.
- Rounded-rectangle welcome-card styling specifics (corner radius, padding, elevation/color).
- Exact button widget type (`ElevatedButton.icon` vs `OutlinedButton.icon` vs `FilledButton.icon`) and row layout on narrow screens.
- Exact bottom-sheet builder structure for the band-picker.

## Deferred Ideas

None — discussion stayed within phase scope. The future user-avatar-in-greeting idea was captured as a layout constraint (D-01 in CONTEXT.md), not as a scope item to build this phase.
