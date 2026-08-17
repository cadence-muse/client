# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-08-17
**Phases:** 5 | **Plans:** 23 | **Tasks:** 46

### What Was Built
- Riverpod state management + Hive-backed cache-store pattern, proven end-to-end on Profile/Home before any other screen depended on it (Phase 1)
- Full band management — list, create, view, edit, delete, join via invite code, leave, remove-member (Phase 2)
- Song catalog CRUD within a band plus a global cross-band Tracks tab (Phase 3)
- Setlist CRUD with drag-and-drop reordering and a global cross-band Setlists tab (Phase 4)
- Consistent offline trust UX (staleness badges, global offline banner, connectivity-gated mutations) across every screen (Phase 5)

### What Worked
- Landing the Riverpod + Hive cache pattern in Phase 1 and proving it on Profile/Home meant every later phase (Bands, Tracks, Setlists) reused the same shape with no retrofitting — the roadmap's up-front architecture bet paid off.
- Deferring OFFL-02..05 (staleness/banner/mutation-gating) to a dedicated Phase 5 cross-screen pass, instead of building it piecemeal per phase, kept each earlier phase's scope bounded and gave Phase 5 a clean, verifiable target (19/19 must-haves, a static-content regression guard checking all 10 cached screens + 19 mutation-control files by name).
- Gap-closure plans (02-06, 03-04) that immediately follow a `gaps_found` verification and close every flagged item same-day, with regression tests specifically targeting the failure mode (e.g., real Hive close+reopen round-trip tests to catch what in-memory test doubles hide) — this is the pattern that actually worked, not just "write more tests."
- Establishing a small set of reusable guards early (the `_version` counter against background-refresh races, `ref.exists()` before reading a sibling provider's `.notifier`) meant later phases (Tracks, Setlists) copied the shape without rediscovering the bug.

### What Was Inefficient
- Phase 2's gap-closure plan (02-06) fixed all 4 flagged issues and shipped passing regression tests the same day, but `02-VERIFICATION.md` and `REQUIREMENTS.md`'s traceability table were never re-stamped to reflect it — both sat stale (`gaps_found`/unchecked) through Phases 3, 4, and 5, and were only caught and corrected during this milestone's close-out audit. A phase that closes its own gaps should re-run (or at least re-stamp) verification before moving on, not leave the fix undocumented for a future close-out to rediscover.
- `STATE.md`'s `current_phase`/`status` fields also drifted (stuck reporting "Phase 2, planning" after Phase 5 had already completed) — state tracking fields need a cheaper, more reliable update path than relying on every phase transition to touch them correctly.

### Patterns Established
- Cache-store generalization: `_ProfileStore` → `_KeyValueStore` → recursive `_deepConvert()` at the Hive read boundary — any future Hive-backed box gets nested-collection safety for free, no per-call-site casting.
- `{data, syncedAt}` envelope on every cache key, read by a shared `SyncStatusBadge` (10m-hidden/30m-warning) and `isOnlineProvider`-gated mutation controls — the standard shape for any new cached, mutable resource.
- AsyncNotifier mutations always go through a method the notifier class itself defines (`setBands()`, `renameBand()`, `setFilter()`) — never a raw `notifier.state = ...` assignment from outside, which fails `flutter analyze`'s protected-member checks.

### Key Lessons
1. A same-day gap-closure plan is only as good as its paper trail — closing the code without re-stamping the verification/requirements docs leaves a false-negative "gaps_found" signal that costs a full audit cycle to rediscover and clear.
2. Real serialization round-trips (Hive close+reopen) catch bugs that in-memory test doubles structurally cannot — worth the extra setup cost specifically for the cache-store layer, where the whole point is surviving a real disk round-trip.
3. Building the cross-cutting concern (offline/staleness/connectivity) last, as a dedicated retrofit phase across all earlier screens, was cheaper and more consistent than threading it through each phase as it was built — confirmed by Phase 5 landing 19/19 with a single regression guard covering all 10 screens + 19 mutation controls in one pass.

### Cost Observations
- Sessions: multiple across 2026-08-11 → 2026-08-17 (6-day span)
- Notable: 216 commits, 233 files changed, ~20,600 LOC Dart, 284 tests passing at ship time, `flutter analyze` clean, zero TODO/stub/placeholder markers in `lib/`.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | multiple | 5 | First milestone — established Riverpod+Hive cache pattern, gap-closure-plan convention, and the offline-retrofit-as-dedicated-phase approach |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 284 | — | `connectivity_plus` (Phase 5); reordering used Flutter SDK's `ReorderableListView`, zero new deps |

### Top Lessons (Verified Across Milestones)

1. Re-stamp verification/requirements docs immediately when a gap-closure plan lands — don't let a same-day fix look stale for a full milestone.
