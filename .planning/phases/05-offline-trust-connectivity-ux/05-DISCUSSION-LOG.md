# Phase 5: Offline Trust & Connectivity UX - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-17
**Phase:** 5-Offline Trust & Connectivity UX
**Areas discussed:** Connectivity detection, Last-synced timestamp storage, Staleness & offline banner UI, Mutation blocking UX

---

## Connectivity detection

| Option | Description | Selected |
|--------|-------------|----------|
| connectivity_plus only | Device radio/interface state, no extra network calls. Misses wifi-with-no-internet. | ✓ |
| Reachability ping | Periodic API hit to confirm real internet. Adds traffic/latency. | |
| Both, layered | connectivity_plus + debounced reachability check. Most accurate, most complex. | |

**User's choice:** connectivity_plus only

| Option | Description | Selected |
|--------|-------------|----------|
| Single global Riverpod provider | One StreamProvider watched everywhere. | ✓ |
| Per-screen checks | Each screen calls connectivity_plus directly. | |

**User's choice:** Single global Riverpod provider

| Option | Description | Selected |
|--------|-------------|----------|
| No debounce | Instant flip on every event. | ✓ |
| Short debounce (~2s) | Wait briefly before flipping state. | |

**User's choice:** No debounce

---

## Last-synced timestamp storage

| Option | Description | Selected |
|--------|-------------|----------|
| Wrap every cache entry | `{data, syncedAt}` shape, touches every read/write method. | ✓ |
| Parallel timestamps store | Separate box mapping key -> syncedAt. Risk of drift. | |

**User's choice:** Wrap every cache entry

| Option | Description | Selected |
|--------|-------------|----------|
| Per cache key | Every keyed entry (list + each detail) gets its own syncedAt. | ✓ |
| One per list/screen | Only top-level list tracks syncedAt. | |

**User's choice:** Per cache key

| Option | Description | Selected |
|--------|-------------|----------|
| Stays at old value | syncedAt only updates on successful write. | ✓ |
| Updates to now | Any refresh attempt resets the clock. | |

**User's choice:** Stays at old value

---

## Staleness & offline banner UI

| Option | Description | Selected |
|--------|-------------|----------|
| Below app bar, above content | One shared widget, consistent placement across all screens. | ✓ |
| Inline per list item | Per-row timestamps. Noisier. | |

**User's choice:** Below app bar, above content

| Option | Description | Selected |
|--------|-------------|----------|
| Color + icon change | Neutral -> warning color/icon at 30min, no copy change. | ✓ |
| Text + color change | Copy also changes to be more explicit. | |

**User's choice:** Color + icon change

| Option | Description | Selected |
|--------|-------------|----------|
| Single widget above RootScaffold's IndexedStack | One banner, watches connectivity provider, shows on every tab. | ✓ |
| Per-screen banner | Each screen renders its own instance. | |

**User's choice:** Single widget above RootScaffold's IndexedStack

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible, 'just now' at 0 | Indicator is a permanent fixture. | |
| Hidden until some age threshold | Indicator fades in after some age. | ✓ |

**User's choice:** Hidden until some age threshold

**Follow-up:** Asked what the threshold should be (offered 1 min / 5 min). User specified **10 minutes** via free text, overriding both offered options.

---

## Mutation blocking UX

| Option | Description | Selected |
|--------|-------------|----------|
| Disabled + grayed out | Buttons visible but visually disabled while offline. | ✓ |
| Hidden entirely | Buttons disappear while offline. | |
| Enabled, blocked on tap | Buttons interactive; tap shows a toast instead of proceeding. | |

**User's choice:** Disabled + grayed out

| Option | Description | Selected |
|--------|-------------|----------|
| Block at entry | FAB/entry button itself disabled while offline. | ✓ |
| Allow entry, block submit | Form opens, only Save is disabled. | |

**User's choice:** Block at entry

| Option | Description | Selected |
|--------|-------------|----------|
| Tooltip/long-press hint | Disabled control shows "Requires connection" on long-press. | ✓ |
| Silently inert | No tap feedback at all. | |

**User's choice:** Tooltip/long-press hint

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, reactive | Save button watches connectivity provider, disables live mid-form. | ✓ |
| No, only checked at entry | Offline only detected when Save is tapped. | |

**User's choice:** Yes, reactive

---

## Claude's Discretion

- Exact banner copy/styling (color, icon, dismissible or persistent).
- Exact tooltip copy for the disabled-mutation-control hint, beyond communicating that connection is required.
- Whether the 10-minute-hidden / 30-minute-warning thresholds are implemented as shared constants (must be used consistently across screens either way).

## Deferred Ideas

None — discussion stayed within phase scope; no new capabilities were proposed.
