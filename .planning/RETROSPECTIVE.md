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

## Milestone: v1.1 — UI Improvements

**Shipped:** 2026-08-22
**Phases:** 6 | **Plans:** 13

### What Was Built
- Password change end-to-end plus icon-based key/duration/notes and location/duration indicators replacing prefixed text labels on Track/Setlist screens (Phase 6)
- Urgent same-milestone catch-up to the server's `fe72e78` schema update — batch setlist-track removal, GET→POST cross-band list endpoints (Phase 06.1, inserted)
- Cache behavior flip from cache-first to online-first across all 10 cached screens, replacing the staleness-tier badge system with a persistent offline warning banner (Phase 7)
- Band owner tools: invite-code rotation and ownership transfer, both via confirm dialogs and local-patch provider updates (Phase 8)
- Homepage quick actions (Add Band/Song/Setlist) with a shared band-picker bottom sheet (Phase 9)
- Searchable setlist track picker with offline substring filtering and a forward-compatible `searchQuery` API field (Phase 10)

### What Worked
- Phase 7's tracer-plan approach (07-01 built the online-first `build()` template, `OfflineNoCacheException`/`OfflineNoCacheView`, and tab-switch-refetch pattern on Bands first) meant the 4 remaining plans mirrored a proven shape instead of re-deriving it — zero pattern drift across 5 plans touching 10 screens.
- Post-execution code review on Phase 7 caught 2 critical bugs (a cache-write race that bypassed the same version guard protecting in-memory state; a dropdown crash on a vanished filter selection) that all automated tests had missed — the review pass earned its cost on the highest-risk phase in the milestone.
- Treating an urgent, unplanned API contract drift (server shipped `fe72e78` mid-milestone) as an inserted decimal phase (06.1) rather than silently folding it into Phase 6 kept the scope change visible and traceable in the roadmap instead of being buried in an unrelated phase's diff.

### What Was Inefficient
- Phase 7's code review surfaced a fifth finding (WR-03: 10 `XSyncedAt` provider classes with zero UI consumers) that the fixer correctly declined to auto-resolve since it required a product decision (build a "last synced" UI vs. delete the dead code) — this had to be escalated to the user during milestone close instead of being caught and decided during Phase 7's own execution or verification. A phase whose code review flags an architectural question should resolve it before the phase is marked complete, not carry it forward to milestone close.
- The milestone-close audit caught that Phase 7 had 5/5 plans executed with SUMMARY.md files but no `07-VERIFICATION.md` — the verify step had never run, and ROADMAP.md's own Progress table (bottom of file) still read "0/5 Not started" for Phase 7 despite the phase-detail section above it marking `[x]` complete. Two independent staleness signals (missing VERIFICATION.md, contradictory ROADMAP progress table) both should have been caught at Phase 7's own close, not five phases later at milestone close.

### Patterns Established
- Online-first provider template: `isOnlineProvider`-gated `build()` that always attempts a fresh fetch first, falls back to cache when offline, and throws `OfflineNoCacheException` (rendered via `OfflineNoCacheView`, no retry button) when neither is available — the standard shape for any future cached, network-backed provider.
- Persisted cache writes must be gated by the same staleness/version guard as their paired in-memory state commit — a version check on `state` alone is not sufficient to protect the on-disk cache from a stale background response.
- Dropdown filter values sourced from a persisted provider must be clamped against the live source list at render time (not just at set time) — the persisted filter can "stick" for UX continuity while the rendered value still degrades safely if its target disappears.
- Owner-gated mutations use a local-patch pattern: optimistic patch when the response body is usable (rotate), invalidate+refetch plus a separate list-patch when it isn't (transfer).

### Key Lessons
1. A phase's own code review should run and its findings should resolve (fixed or explicitly deferred with a recorded decision) before the phase is marked complete — deferring an unresolved code-review question to milestone close costs a context-switch five phases later, when the original phase's detail has left working memory.
2. Two-signal staleness detection (a missing terminal artifact like VERIFICATION.md, plus a stale summary table contradicting the phase-detail section) is a reliable tell that a phase's close-out was interrupted mid-flow — worth a lightweight per-phase consistency check rather than relying on milestone-close's audit to be the first place it surfaces.
3. Escalating an unplanned, urgent schema/contract drift as a visible inserted decimal phase (rather than silently absorbing it into whichever phase happens to be active) keeps the roadmap an honest record of what actually shipped and why.

### Cost Observations
- Sessions: multiple across 2026-08-20 → 2026-08-22 (3-day span)
- Notable: 144 files changed this milestone (~26,400 insertions / ~4,200 deletions), ~24,800 LOC Dart at ship time, 401 tests passing, `dart analyze` clean. Code review + fix cycle on Phase 7 added 2 extra subagent passes (review + fix) plus one manual dead-code-removal pass beyond the original 5-plan phase.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | multiple | 5 | First milestone — established Riverpod+Hive cache pattern, gap-closure-plan convention, and the offline-retrofit-as-dedicated-phase approach |
| v1.1 | multiple | 6 | Tracer-plan pattern for cross-screen retrofits (Phase 7); inserted decimal phase for an urgent mid-milestone API contract drift (06.1); post-execution code review became load-bearing for catching cache-race and UI-crash bugs tests missed |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 284 | — | `connectivity_plus` (Phase 5); reordering used Flutter SDK's `ReorderableListView`, zero new deps |
| v1.1 | 401 | — | No new dependencies — cache/online-first flip, owner tools, and search all built on existing Riverpod/Hive/connectivity_plus stack |

### Top Lessons (Verified Across Milestones)

1. Re-stamp verification/requirements docs immediately when a gap-closure plan lands — don't let a same-day fix look stale for a full milestone.
2. A phase's code review findings should resolve before the phase is marked complete — an unresolved architectural question deferred to milestone close costs a context-switch that a same-phase resolution would avoid (v1.1).
3. A tracer plan that proves a cross-screen pattern once, before the remaining plans mirror it, prevents pattern drift on any retrofit phase touching many similar screens (v1.0 Phase 5, v1.1 Phase 7).
