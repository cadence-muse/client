# Phase 1: Foundation, Profile & Home - Context

**Gathered:** 2026-08-14
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase migrates app-level state (auth, theme) from constructor-injected `ChangeNotifier`/`ValueNotifier` to Riverpod, builds the local cache-store infrastructure (Hive-backed) that every later phase's offline caching depends on, and proves both end-to-end on exactly two screens: Profile (`GET /api/me`) and Home (`GET /api/homepage`). No new capabilities beyond viewing profile/homepage data — Bands/Tracks/Setlists screens and full staleness UI are out of scope here.

</domain>

<decisions>
## Implementation Decisions

### Local Cache Technology
- **D-01:** Cache store is Hive (typed box store, pure Dart, no native deps) — chosen over sqflite (rejected: no relational/join needs since the cache stores per-endpoint response blobs, not normalized data) and plain JSON files. — **Reversibility:** costly — **Rationale:** every later phase (Bands/Tracks/Setlists) builds its caching on this same layer; swapping the storage engine later means rewriting cache read/write across all screens, not just Profile/Home.
- **D-02:** One Hive box per endpoint (e.g. `profileBox`, `homepageBox`), not a shared box with prefixed keys. Each later phase adds its own box as new cached endpoints are introduced (e.g. `bandsBox` in Phase 2).
- **D-03:** Each box stores the raw decoded JSON `Map<String, dynamic>` from the API response, not Hive TypeAdapters/typed objects. Reuses the same `fromJson` parsing path already used for live network responses — one decode path for both cache-hit and cache-miss.

### Refresh Strategy
- **D-04:** Cache-first loading: on screen load, show cached data immediately if present, then fire a network refresh in the background. — **Reversibility:** costly — **Rationale:** this is the read pattern every cached screen in Phases 2-4 (Bands/Tracks/Setlists) will also use; switching to network-first later means revisiting every screen's load logic, not just Profile/Home.
- **D-05:** Full staleness indicator ("last synced Xm ago" with escalation past ~30min) is explicitly **deferred to Phase 5** per roadmap OFFL-03 — Phase 1 does NOT build any visual "this is cached" cue. Loading is silent cache-first; Phase 5 owns the indicator as a single cross-screen pass. See Deferred Ideas below.
- **D-06:** When a background refresh completes with data that differs from what's cached, the screen updates silently in place (normal Riverpod rebuild-on-state-change) — no transition/animation required.
- **D-07:** First-ever load (no cache yet) while offline shows an empty/error state with a retry action, since there's nothing to fall back to.

### Riverpod Migration Scope
- **D-08:** Both `AuthSession` (required by roadmap — no dual source of truth for auth state) and `ThemeController` migrate to Riverpod in this phase, as one clean pass, rather than leaving `ThemeController` as `ValueNotifier` for a later phase to touch.
- **D-09:** `ApiClient`, `PublicApi`, and `TokenStorage` construction moves inside Riverpod via `ProviderScope` + provider overrides (not a thin Provider wrapping the same `main()`-constructed instances). — **Reversibility:** costly — **Rationale:** this touches the API layer's construction path (currently built once in `main()` per CLAUDE.md's "reuse existing ApiClient/AuthSession/TokenStorage, minimize churn" constraint) rather than just wrapping it; unwinding back to constructor injection means re-threading dependencies through every provider that currently reads them via `ref`.
- **D-10:** Providers use codegen (`riverpod_generator` + `@riverpod` annotations + `build_runner`), not hand-written `Provider`/`NotifierProvider` declarations. — **Reversibility:** costly — **Rationale:** introduces a build_runner/codegen step this codebase doesn't currently have (no `freezed`/`json_serializable` in use today per CONVENTIONS.md); every provider written this way depends on generated code, so reverting to manual providers means rewriting all of them, not just new ones.

### Claude's Discretion
- **AuthGate restructuring:** user explicitly deferred to "most idiomatic Riverpod approach" — whether `AuthGate` keeps its current widget-watches-provider shape or gets restructured (e.g. router-based redirect) is left to the researcher/planner to decide based on what's idiomatic for this codebase's scale.
- **Transition/animation styling** for silent in-place refresh updates (D-06) — exact visual treatment, if any, left to implementation.
- **Empty-state copy/layout** for the no-cache-and-offline case (D-07) — exact wording/design left to implementation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API contract
- `lib/api/publicapi.yml` — source of truth for all request/response shapes. Relevant for this phase: `GET /api/me` → `UserProfile` (`id`, `username`, both required), `GET /api/homepage` → `HomepageData` (`username`, `bandsCount`, both required).

### Project-level constraints
- `.planning/PROJECT.md` — "Constraints" section: reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns, minimize churn on already-working auth; offline scope is read-only cache; Android/iOS only, web excluded.
- `.planning/ROADMAP.md` — Phase 1 success criteria (profile/homepage view, offline last-fetched display, Riverpod migration with no dual source of truth) and Phase 5 boundary (staleness indicators, offline banner, mutation blocking are Phase 5's scope, not Phase 1's).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/api/api_client.dart` (`ApiClient`) — HTTP wrapper, token injection, 403 auto-logout. Reused as-is; only its construction path moves into Riverpod (D-09).
- `lib/api/auth_session.dart` (`AuthSession`) — auth state `ChangeNotifier` with three-state enum (unknown/unauthenticated/authenticated). Its state and transition logic carry over into the new Riverpod auth provider; only the reactivity mechanism changes.
- `lib/api/token_storage.dart` (`TokenStorage`) — secure token persistence, unchanged.
- `lib/features/profile/profile_screen.dart`, `lib/features/home/home_screen.dart` — current placeholder screens to be wired to real data + cache.

### Established Patterns
- Dependency injection via constructor/prop-drilling (flagged as an anti-pattern in `ARCHITECTURE.md`) is what this phase's Riverpod migration replaces.
- No codegen currently in the codebase (per `CONVENTIONS.md`) — D-10 is a deliberate, scoped exception for Riverpod providers only.
- `ApiException` error-handling pattern (statusCode/code/message, caught at UI layer) stays as the error contract; cache-fallback logic wraps around it rather than replacing it.

### Integration Points
- `lib/app.dart` (theme `ListenableBuilder`) and `lib/features/auth/auth_gate.dart` (auth status gating) are the two places where the old `ChangeNotifier`/`ValueNotifier` reactivity gets replaced with Riverpod `ref.watch`.
- `lib/main.dart` — current single point of dependency construction; becomes the `ProviderScope` root per D-09.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual requirements beyond what's captured in Decisions — `UserProfile` and `HomepageData` are minimal schemas (id/username; username/bandsCount), so screen layout is low-stakes and left to implementation.

</specifics>

<deferred>
## Deferred Ideas

- **Full staleness indicator** ("last synced Xm ago", escalating to warning style past ~30min stale) — belongs to Phase 5 per roadmap OFFL-03, which owns it as a single cross-screen pass (profile, bands, tracks, setlists together). Phase 1 deliberately ships cache-first loading with zero visual staleness cue rather than a throwaway placeholder that Phase 5 would replace anyway.

### Reviewed Todos (not folded)
None — no pending todos matched this phase (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 1-Foundation, Profile & Home*
*Context gathered: 2026-08-14*
