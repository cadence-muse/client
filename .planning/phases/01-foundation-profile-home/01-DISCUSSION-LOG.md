# Phase 1: Foundation, Profile & Home - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-14
**Phase:** 1-Foundation, Profile & Home
**Areas discussed:** Local cache technology, Refresh strategy, Riverpod migration scope

---

## Local Cache Technology

| Option | Description | Selected |
|--------|-------------|----------|
| sqflite (SQLite) | Real relational DB; best fit if joins/relations needed | |
| Hive | Lightweight typed box store, pure Dart, no native deps | ✓ |
| JSON files (path_provider) | Simplest, zero query layer | |

**User's choice:** Hive.
**Notes:** User challenged the initial framing that offered sqflite on the basis of future joins — correctly pointed out the v1 cache stores per-endpoint response blobs with no cross-entity queries planned, so sqflite's relational advantage doesn't apply. Question was reframed to Hive vs JSON files before asking.

| Option | Description | Selected |
|--------|-------------|----------|
| Box per endpoint | Separate Hive box per screen/endpoint (`profileBox`, `homepageBox`, ...) | ✓ |
| One shared box, prefixed keys | Single box, keys namespaced by prefix | |

**User's choice:** Box per endpoint.

| Option | Description | Selected |
|--------|-------------|----------|
| TypeAdapters (typed objects) | Hive codegen per model, type-safe reads | |
| Raw JSON map | Store decoded `Map<String,dynamic>`, reuse existing `fromJson` path | ✓ |

**User's choice:** Raw JSON map.

---

## Refresh Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Cache-first, then background refresh | Show cache instantly, refresh silently in background | ✓ |
| Network-first, cache fallback | Always try network first, fall back to cache on failure | |

**User's choice:** Cache-first, then background refresh.
**Notes:** User's initial answer also asked for a staleness visual cue, which overlaps Phase 5's explicitly-scoped OFFL-03 work (full "last synced Xm ago" indicator with escalation styling). Flagged as a scope boundary and reframed into a follow-up choice.

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal placeholder now | Bare-bones "cached" cue in Phase 1, replaced by Phase 5's full indicator | |
| Defer fully to Phase 5 | No visual cue at all in Phase 1; Phase 5 builds it once, correctly, across all screens | ✓ |

**User's choice:** Defer fully to Phase 5.
**Notes:** Captured as a deferred idea rather than lost.

| Option | Description | Selected |
|--------|-------------|----------|
| Silent in-place update | Normal Riverpod rebuild when background refresh lands new data | ✓ |
| You decide | Leave exact UX to implementation | |

**User's choice:** Silent in-place update.

| Option | Description | Selected |
|--------|-------------|----------|
| Empty/error state with retry | Standard empty-state pattern when no cache and offline | ✓ |
| You decide | Leave exact copy/layout to implementation | |

**User's choice:** Empty/error state with retry.

---

## Riverpod Migration Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Migrate ThemeController too | One clean pass — auth + theme both become Riverpod together | ✓ |
| Leave ThemeController as-is | Only migrate what roadmap requires (auth) + new cache state | |

**User's choice:** Migrate ThemeController too.

| Option | Description | Selected |
|--------|-------------|----------|
| Provider-wraps-constructor (compat shim) | Keep `main()` construction, expose via thin Provider | |
| Full ProviderScope + overrides | Rebuild dependency construction inside Riverpod | ✓ |

**User's choice:** Full ProviderScope + overrides.

| Option | Description | Selected |
|--------|-------------|----------|
| Manual providers | Hand-written Provider/NotifierProvider, no codegen | |
| Codegen (@riverpod) | riverpod_generator + build_runner | ✓ |

**User's choice:** Codegen (@riverpod).

| Option | Description | Selected |
|--------|-------------|----------|
| Keep AuthGate structure, watch provider | Same widget shape, new state source | |
| You decide | Leave restructuring approach to implementation-time judgment | ✓ |

**User's choice:** You decide — "choose the most idiomatic way for this."

---

## Claude's Discretion

- AuthGate restructuring approach (keep current shape vs router-based redirect) — user deferred to "most idiomatic Riverpod approach."
- Transition/animation styling for silent in-place refresh updates.
- Empty-state copy/layout for the no-cache-and-offline case.

## Deferred Ideas

- Full staleness indicator ("last synced Xm ago" + escalation styling past ~30min) — belongs to Phase 5 per roadmap OFFL-03, not built in Phase 1.
