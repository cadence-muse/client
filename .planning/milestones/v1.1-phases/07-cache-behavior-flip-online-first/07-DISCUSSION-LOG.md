# Phase 7: Cache Behavior Flip — Online-First - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-21
**Phase:** 7-Cache Behavior Flip — Online-First
**Areas discussed:** Fresh-on-open trigger point, Online-but-fetch-fails fallback, Offline + no-cache state, In-flight fetch loading UX

---

## Fresh-on-open trigger point

| Option | Description | Selected |
|--------|-------------|----------|
| Every tab switch | Refetch whenever the tab becomes visible again, not just app cold-start | ✓ |
| Cold start only | Fetch fresh once at first build; tab switches show memory state until pull-to-refresh | |
| Cold start + app foreground-resume | Fetch on first build and on app returning from background | |

**User's choice:** Every tab switch
**Notes:** Needs a tab-visibility trigger wired into each of the 5 IndexedStack tab screens (e.g. off `selectedTabIndexProvider`), since providers currently `build()` once per app session.

| Option | Description | Selected |
|--------|-------------|----------|
| Push-per-visit already counts | Navigator.push already creates a fresh autoDispose provider instance each time; no extra wiring needed for detail screens | ✓ |
| Also add explicit refetch | Belt-and-suspenders explicit online-first check in build() even though autoDispose already covers it | |

**User's choice:** Push-per-visit already counts
**Notes:** Only the 5 tab screens need the new mechanism; Band/Track/Setlist detail screens are unaffected.

---

## Online-but-fetch-fails fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to cache silently | Same code path as true-offline, no distinct error dialog | ✓ |
| Distinct "couldn't refresh" error | Different messaging than true offline | |
| Blank error state (current behavior) | Any fetch failure becomes AsyncError even with cache present | |

**User's choice:** Fall back to cache silently

| Option | Description | Selected |
|--------|-------------|----------|
| Make banner connectivity-agnostic | Reword to something like "Showing cached data — may be out of date" | ✓ |
| Keep two distinct messages | Separate "You're offline" vs. "Couldn't reach server" copy | |
| Leave banner as-is, only offline triggers it | No wording change | |

**User's choice:** Make banner connectivity-agnostic

| Option | Description | Selected |
|--------|-------------|----------|
| Per-screen banner | Each screen embeds its own banner reflecting its own cache-serving status | |
| Keep global banner, ignore the edge case | Global banner stays tied to isOnlineProvider only; fetch-fail-while-online shows no banner at all | ✓ |
| Global banner, OR'd across all 5 screens | One global banner driven by "is any provider serving cache" | |

**User's choice:** Keep global banner, ignore the edge case
**Notes:** Deliberate simplicity tradeoff — the reworded wording (previous question) only changes copy for the true-offline case; the online-but-fetch-failed edge case gets no banner at all, accepted as acceptable.

---

## Offline + no-cache state

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated offline-empty state | "No cached data — connect to the internet to load this" + cloud-off icon, no Retry button | ✓ |
| Reuse existing error state as-is | Let it fall through to the generic "Couldn't load X" + Retry | |

**User's choice:** Dedicated offline-empty state

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-retry on reconnect | Screen listens to isOnlineProvider and refetches automatically the moment it flips online | ✓ |
| Manual pull-to-refresh only | User must act to recover | |

**User's choice:** Auto-retry on reconnect

---

## In-flight fetch loading UX

| Option | Description | Selected |
|--------|-------------|----------|
| Keep old content, subtle refresh indicator | Old content stays visible; thin progress bar/AppBar spinner while fetch runs | ✓ |
| Full-screen loading spinner | Standard AsyncValue.when() loading branch, every fetch | |

**User's choice:** Keep old content, subtle refresh indicator

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, exactly | Full-screen spinner only on true cold start (no data yet); subtle indicator for every fetch once there's something to show | ✓ |
| No — full-screen spinner always on first build() per session | Even with cross-session cache, first build this session still gets full-screen treatment | |

**User's choice:** Yes, exactly

---

## Claude's Discretion

- Exact mechanism for wiring "every tab switch" refetch (e.g. listening to `selectedTabIndexProvider` vs. a shared mixin/helper).
- Exact widget/icon choice for the subtle in-flight refresh indicator and the offline-empty-state icon.
- Whether the per-resource `XxxSyncedAt` providers are kept, repurposed, or removed once `SyncStatusBadge` is deleted.
- Precise `SyncStatusBadge` removal mechanics across its 10 call-sites.

## Deferred Ideas

None — discussion stayed within phase scope.
