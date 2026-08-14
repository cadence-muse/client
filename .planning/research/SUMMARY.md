# Project Research Summary

**Project:** Cadence (band repertoire / setlist management app)
**Domain:** Flutter mobile app (Android/iOS) — REST-backed CRUD + offline read cache + state management migration
**Researched:** 2026-08-14
**Confidence:** MEDIUM

## Executive Summary

Cadence's next milestone is two things at once: (1) build out the CRUD surface (bands, tracks, setlists, membership) already fully specified in `lib/api/publicapi.yml`, and (2) retrofit two cross-cutting architectural changes underneath it — a state management migration off constructor-injected `ChangeNotifier`/prop-drilling onto Riverpod, and an offline read-cache so band members can view their last-synced setlist with no signal at a venue. Every piece of research (features, architecture, pitfalls) converges on the same sequencing conclusion: the two foundational changes (Riverpod wiring, cache infrastructure) must land before any feature CRUD phase, because every subsequent screen depends on both, and retrofitting either into four already-built feature phases is strictly more expensive than building on top of them once.

The recommended approach is a network-first-with-cache-fallback repository pattern: each repository attempts the real API call first, writes successful responses into a cache, and only falls back to cache on network-class failures (never on 403/4xx/5xx, which must still propagate to trigger existing auth behavior). State management moves to Riverpod (not Provider or BLoC) using `Notifier`/`AsyncNotifier` directly, not the legacy `ChangeNotifierProvider` bridge. For local storage, this summary standardizes on a **generic key→JSON-blob cache store**, not a relational schema (see reconciliation below) — this keeps the offline layer honest to the milestone's actual scope (last-fetched snapshot, read-only, no relational queries across cached entities).

The primary risks are UX trust and cross-boundary state bugs, not raw feasibility: (a) cached data that looks identical to fresh data misleads users about staleness at exactly the moment (no signal, at a gig) the feature exists to serve; (b) cache not scoped/cleared per user+band leaks data across accounts or bands on a shared device; (c) a half-migrated auth state (some screens on old `ChangeNotifier`, some on new Riverpod) is the highest-risk failure mode in the whole milestone because it touches the already-working 403 auto-logout behavior. All three are addressed by explicit patterns below and should be non-negotiable acceptance criteria in the phases that touch them.

## Key Findings

### Recommended Stack

Core additions: **flutter_riverpod ^3.4.2** (non-codegen to start) for state management, replacing constructor-injected `ChangeNotifier`, and **connectivity_plus** as a UI-only "offline" banner hint (never as the gate for whether to attempt a network call — see Architecture Approach below). `sqflite` or an equivalent lightweight embedded store backs the cache layer (see Reconciled Storage Decision). No changes to the existing `ApiClient`/`AuthSession`/`TokenStorage` layer.

**Core technologies:**
- `flutter_riverpod ^3.4.2` — app-wide reactive state, no `BuildContext` coupling, `AsyncValue` for loading/data/error — directly solves the migration PROJECT.md already flags as required
- `sqflite` (or equivalent) — backing store for a generic `CacheStore` (key → JSON blob + timestamp), gated behind a conditional-import (web gets a no-op stub, matching the existing `http_client_factory_*` pattern)
- `connectivity_plus` — optional, UI-hint only (drives an app-wide offline banner); explicitly NOT used to gate repository read/write logic, since an "up" interface doesn't mean the API is reachable

### Expected Features

Full feature scope is fixed by `lib/api/publicapi.yml` — no invented fields/endpoints. All P1 items below are already committed in PROJECT.md's Active requirements, not speculative.

**Must have (table stakes):**
- Band CRUD (list/create/view/edit/delete) + join via invite code + member list + remove member (self/owner)
- Track catalog CRUD within a band (title/artist/duration, optional tempo/key/notes)
- Setlist CRUD within a band (name, event date/location) + add/remove/reorder tracks (drag-and-drop) + running duration display
- Offline read cache for all GET-backed screens (profile, homepage, band/track/setlist list & detail)
- State management migration to Riverpod
- Empty states and client-side form validation matching API-required fields

**Should have (competitive differentiators):**
- Explicit "last synced" + staleness indicator (this is Cadence's actual differentiator vs. cloud-first competitors that assume connectivity)
- Persistent offline-mode banner (global, not per-screen)
- Setlist duration vs. target-slot comparison (pure client-side, no API change)

**Defer (v2+):**
- Offline mutation queue / sync-on-reconnect (no conflict resolution strategy exists yet — explicitly out of scope)
- Real-time collaborative editing (no websocket/push in API)
- Lyrics/chords/tabs, audio attachments, richer roles, push notifications (all require API changes not sanctioned this milestone)
- Client-side search/filter and setlist duplication — cheap v1.x candidates, not v1, flag before building

### Architecture Approach

Three new layers are inserted between the existing (unmodified) `lib/api/` layer and feature screens: a generic **Cache** layer (`lib/cache/`, feature-agnostic key→JSON store), a per-entity **Repository** layer (`lib/repositories/`, owns network-first/cache-fallback policy for reads, online-only for writes), and a **Provider** layer (`lib/providers/`, Riverpod wiring that replaces constructor DI). `ApiClient`, `AuthSession`, and existing 403 auto-logout behavior stay completely untouched.

**Major components:**
1. `CacheStore` (new, `lib/cache/`) — generic key→JSON+timestamp store, zero domain knowledge, platform-gated (sqflite on io, no-op on web)
2. `*Repository` (new, one per entity: Bands/Tracks/Setlists/Profile) — network-first-with-cache-fallback on reads; on writes, online-only, and updates/invalidates the corresponding cache key on success
3. Riverpod providers (new, `lib/providers/`) — wire `ApiClient`/`AuthSession`/repositories without constructor threading; screen-facing `FutureProvider`/`AsyncNotifierProvider` (non-autoDispose for cached list/detail data, since `RootScaffold`'s `IndexedStack` keeps tabs mounted)
4. Feature screens (existing dirs, rewritten as `ConsumerWidget`s) — render `AsyncValue`, surface a "fromCache"/"last synced" affordance instead of showing stale data silently

Key pattern: classify errors before falling back to cache. Only network-class exceptions (no HTTP response reached) trigger cache fallback; 403s and 4xx/5xx business errors always propagate unchanged, so the existing auto-logout behavior is never masked by stale cached data.

**Reconciled Storage Decision:** STACK.md recommends Drift (relational, type-safe SQL, reactive streams) as the general 2026 default for Flutter local persistence; ARCHITECTURE.md recommends a simple generic key→JSON-blob store, arguing the actual v1 scope is read-only with no relational queries or cross-entity joins needed offline. **This summary adopts ARCHITECTURE.md's recommendation: a generic key→JSON-blob cache store (e.g., backed by `sqflite` with a single `cache_entries(key, json, fetched_at)` table), not Drift.** Rationale: the milestone is explicitly "last-fetched response, read-only, no offline mutation queue, no conflict resolution" (PROJECT.md Out of Scope) — the relationship between a band and its tracks is already expressed by the cache *key* (`band:$id:tracks`), not by SQL foreign keys. A relational schema with FK constraints, migrations, and generated code (Drift's `drift_dev`/`build_runner` codegen) solves problems this milestone doesn't have (offline querying/filtering, cross-entity joins while offline) and is meaningfully more moving parts for no v1 benefit — this is exactly the "Anti-Pattern 2" ARCHITECTURE.md calls out. Revisit Drift only if a future milestone needs offline search/filtering across cached entities or a mutation-queue/outbox table; if that happens, migrate the same schema-migration discipline (see Pitfall 5) forward rather than starting over.

### Critical Pitfalls

1. **Cache not scoped/cleared per user+band** — every cache key must include `bandId` (and ideally `userId`); wire `CacheStore.clearAll()` into `AuthSession.signOut()` (both manual logout and 403 auto-logout paths), or risk cross-account/cross-band data bleed on a shared device.
2. **Stale cache indistinguishable from fresh data** — thread `CacheResult{data, fromCache, fetchedAt}` all the way to the UI and always render an explicit "offline — data from {time}" affordance when `fromCache == true`. This is the milestone's core value proposition; silently serving stale data as if fresh defeats the entire feature.
3. **Successful online mutations don't invalidate the read cache** — "read-only cache" means writes require connectivity, not that writes never touch the cache. Every mutation method must update/invalidate the corresponding cache key as part of its own repository method, or users see their own edits "disappear" the next time they go offline.
4. **Two competing sources of truth for auth state during migration** — do not leave `AuthSession` on old `ChangeNotifier`/constructor-injection while new screens read auth via Riverpod (or vice versa, ad hoc). Pick one rule for the whole migration window and apply it consistently; this is the highest-risk pitfall because it touches the already-working 403 auto-logout behavior.
5. **`autoDispose` (Riverpod's typical default) fights the caching goal** — `RootScaffold`'s `IndexedStack` keeps all four tabs mounted; band/track/setlist providers must be `keepAlive` (non-autoDispose), or every tab switch triggers a fresh network/cache read and defeats the point of caching.

## Implications for Roadmap

Based on combined research, the natural phase structure is: two foundational cross-cutting phases first (state management, cache infra), then one vertical CRUD feature slice per phase (each building directly on both foundations), then a dedicated offline-integration/UX pass that verifies staleness/trust signals across all screens.

### Phase 1: State Management Migration (Riverpod skeleton)
**Rationale:** Every subsequent phase (cache infra, repositories, feature screens) is easier to build directly against Riverpod providers than to retrofit later; also the highest-risk single decision (auth-state duality) should be resolved in isolation, not as a side effect of building a feature screen.
**Delivers:** `ProviderScope` at app root; `authSessionProvider`/`apiClientProvider` bridging the existing unmodified `AuthSession`/`ApiClient` classes; a documented single rule for how auth state is read across the whole migration window; a shared test harness (`pumpCadenceApp`) wiring `ProviderScope` + overrides for all future widget tests.
**Addresses:** State management migration requirement (PROJECT.md Active requirement).
**Avoids:** Pitfall 4 (two competing auth sources), Pitfall 5 (`ChangeNotifierProvider` legacy trap — target `Notifier`/`AsyncNotifier` directly), Pitfall (testing regressions from missing provider overrides).

### Phase 2: Cache Infrastructure (generic key→JSON store)
**Rationale:** Cross-cutting — every list/detail screen in every later phase depends on it; more efficient to build once than bolt onto each feature phase separately. Can build in parallel with new typed `*Api` classes (both depend only on the existing unchanged `ApiClient`).
**Delivers:** `CacheStore` abstract interface + `sqflite`-backed impl (conditional-import gated, web gets no-op stub) + `clearAll()`/`clearForUser()` wired into `AuthSession.signOut()` + explicit schema-migration discipline from the first version (even if version 1 has no migration yet, the test/pattern exists).
**Uses:** Generic key→JSON-blob store (reconciled decision above), `sqflite`.
**Implements:** `CacheStore` component from Architecture Approach.
**Avoids:** Pitfall (cache not scoped per user/band), Pitfall (skipped/destructive schema migrations), Anti-Pattern 2 (building a full relational offline mirror for v1).

### Phase 3: Bands (CRUD + join + membership) — first vertical feature slice
**Rationale:** Bands is the root scoping entity — tracks and setlists are always nested under a `bandId` in the API, so band CRUD + band detail must exist before track/setlist screens are buildable at all.
**Delivers:** `BandsApi`, `BandsRepository` (network-first-with-cache-fallback), band list/create/edit/delete screens as `ConsumerWidget`s, join-via-invite-code flow, member list + remove member (self/owner), offline "fromCache"/"last synced" affordance on band screens.
**Addresses:** Band CRUD, join via invite code, remove member (FEATURES.md P1 items).
**Avoids:** Pitfall 1 (collapsed DTO/cache/domain model — keep three distinct types with mappers from the start, since this is the first entity built).

### Phase 4: Tracks (catalog CRUD within a band)
**Rationale:** Depends on Phase 3 (tracks are scoped under a band) but is otherwise independent of setlists; a clean second vertical slice reusing the Phase 1/2 foundation and the repository pattern established in Phase 3.
**Delivers:** `TracksApi`, `TracksRepository`, track catalog CRUD screens (title/artist/duration, optional tempo/key/notes), mutation-success cache invalidation.
**Addresses:** Track catalog CRUD (FEATURES.md P1).
**Avoids:** Pitfall (mutations not invalidating cache — verify edit-online-then-view-offline shows the edit).

### Phase 5: Setlists (CRUD + track add/remove/reorder + duration)
**Rationale:** Depends on both Phase 3 (band scoping) and Phase 4 (need tracks to exist before adding them to a setlist) — the natural last vertical slice in the bands→tracks→setlists dependency chain.
**Delivers:** `SetlistsApi`, `SetlistsRepository`, setlist CRUD screens, add/remove/reorder tracks (`ReorderableListView` + optimistic reorder-then-confirm against `PUT .../tracks/reorder`), running duration display (server-computed, no client math).
**Addresses:** Setlist CRUD, add/remove/reorder tracks, duration display (FEATURES.md P1/P2).
**Avoids:** Pitfall (mutations not invalidating cache, same as Phase 4, verified again here since setlist-track membership mutates more frequently).

### Phase 6: Offline UX Integration Pass (staleness trust, cross-screen verification)
**Rationale:** Staleness/trust UX is a cross-cutting requirement (PITFALLS.md treats it as UX acceptance criteria, not a data-layer detail) — best verified once all four entity types have real cache-backed screens to test against, rather than partially verified per-phase.
**Delivers:** Consistent "last synced Xm ago" + offline banner across all screens; manual airplane-mode verification across bands/tracks/setlists/profile; verification that mutation UI is disabled/clearly labeled offline; verification that tab-switching doesn't trigger redundant fetches (autoDispose check).
**Addresses:** Last-synced/staleness indicator, offline-mode banner (FEATURES.md differentiators).
**Avoids:** Pitfall 2 (stale cache indistinguishable from fresh — this is the phase's primary acceptance criterion), Pitfall (`autoDispose` fighting cache goal).

### Phase Ordering Rationale

- Foundation-first ordering (Riverpod, then cache infra) is not optional sequencing preference — it's a hard dependency every research file independently converges on: ARCHITECTURE.md's "Suggested Build Order" states it explicitly, FEATURES.md's dependency graph shows both as cross-cutting prerequisites, and PITFALLS.md flags "cache-layer foundation phase" and "state-management migration phase" as the correct prevention point for 7 of 9 critical pitfalls.
- Bands → Tracks → Setlists ordering follows the API's own resource nesting (`bandId` scopes both tracks and setlists; setlist-track operations require tracks to exist) — this is a hard dependency, not a preference.
- A dedicated Phase 6 (rather than folding staleness UX into each feature phase) avoids the risk of inconsistent per-screen staleness affordances — PITFALLS.md's "Looks Done But Isn't" checklist treats this as something that's easy to half-implement per-screen and needs a cross-screen verification pass.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Cache Infrastructure):** Needs `--research-phase` — schema-migration strategy details (even for a simple key-value table, the migration test pattern from PITFALLS.md Pitfall 5 needs concrete implementation guidance) and the exact conditional-import wiring to mirror `http_client_factory_*.dart`.
- **Phase 1 (State Management Migration):** Needs `--research-phase` — the specific mechanics of bridging the existing `ChangeNotifier`-based `AuthSession` into Riverpod without creating the dual-source-of-truth trap (Pitfall 4) deserve concrete code-level research, not just the pattern-level guidance already gathered.

Phases with standard patterns (skip research-phase):
- **Phases 3, 4, 5 (Bands/Tracks/Setlists CRUD):** ARCHITECTURE.md's repository pattern (Pattern 1, with full code example) is directly reusable across all three; each phase is a mechanical repeat of the same shape against a different API resource group. Standard CRUD-over-REST-with-cache-fallback, well-documented in this research.
- **Phase 6 (Offline UX Integration):** The UX pattern (fromCache/fetchedAt threading to a banner/badge) is fully specified in ARCHITECTURE.md Pattern 1 and PITFALLS.md Pitfall 2 — implementation is additive UI work, not novel research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Versions verified directly against pub.dev registry listings, but dates are relative not absolute — re-run `flutter pub outdated` before pinning. No curated-docs provider (Context7/Ref) available this session, so confidence defaults to the generic web-fetch tier. Storage-engine recommendation itself was LOW-confidence community opinion, resolved by architecture-scope reasoning (see Reconciled Storage Decision) rather than by re-verifying package facts. |
| Features | MEDIUM | Cross-referenced against multiple competitor apps (Band Mule, Setlist Helper, BandHelper, etc. — MEDIUM-confidence sources each) but grounded against the HIGH-confidence local `publicapi.yml` and `PROJECT.md` for what's actually buildable — API-boundary filtering reduces risk of scope drift even though individual competitor sources are MEDIUM. |
| Architecture | MEDIUM-HIGH | Repository/cache-fallback pattern is corroborated by official Flutter first-party architecture docs (HIGH); local-DB package comparison sources are LOW individually but the generic-store recommendation is justified independently by this milestone's explicit read-only scope, not by the package comparison. |
| Pitfalls | MEDIUM-HIGH | Cross-checked against official Riverpod docs (HIGH) and this repo's own `ARCHITECTURE.md`/`CONCERNS.md` codebase map (HIGH, primary source) for the auth/DI-specific pitfalls; general offline-caching pitfalls draw on MEDIUM-confidence community blog sources. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Drift vs. generic-store reconciliation:** Resolved in this summary by scope reasoning (see above), but flag explicitly in Phase 2 planning that this was a synthesis-level decision, not independently re-verified against package facts — if a future milestone needs offline search/filtering, revisit rather than assuming the generic store scales to that requirement.
- **Riverpod codegen (annotations) vs. plain API:** STACK.md recommends starting without codegen given the app's current size (~4 tabs, ~3 resources) and revisiting past ~15-20 providers — this threshold should be tracked informally during Phases 3-5 rather than decided upfront.
- **Cache encryption/at-rest security posture:** PITFALLS.md flags plaintext cache storage as an explicit, deliberate decision to make (not an oversight) — low-sensitivity repertoire data is likely fine unencrypted, but this should be confirmed as an explicit call in Phase 2 planning, not left implicit.
- **`ApiException.isNetworkError` classification exact mechanics:** ARCHITECTURE.md sketches this as `statusCode == null`, but the existing `ApiException` type's actual shape needs confirming against the current codebase before Phase 1/2 planning finalizes the pattern.

## Sources

### Primary (HIGH confidence)
- `lib/api/publicapi.yml` — ground truth for buildable API surface
- `.planning/PROJECT.md` — ground truth for milestone scope/constraints
- `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/CONCERNS.md`, `.planning/codebase/STRUCTURE.md` — ground truth for current component boundaries and known anti-patterns
- Flutter official docs — Offline-first design pattern (docs.flutter.dev/app-architecture/design-patterns/offline-first)
- Riverpod official docs — Migrating from 2.0 to 3.0, From ChangeNotifier, Provider vs Riverpod (riverpod.dev)
- pub.dev registry pages for `drift`, `flutter_riverpod`, `riverpod_annotation`, `sqlite3_flutter_libs`, `sqflite`, `provider`, `flutter_riverpod` changelog

### Secondary (MEDIUM confidence)
- drift.simonbinder.eu/setup — official Drift Flutter setup guide
- connectivity_plus package page (pub.dev)
- Multiple 2025/2026 Flutter local-DB and Riverpod-vs-Provider-vs-BLoC comparison articles (Luci Studio, Bacancy, Softaims, FlutterFever, StartDebugging, Flutter Studio, Vibe Studio, DEV Community) — treated as directional consensus signal
- Competitor app research: Band Mule, Band Central, BandHelper, Setlist Helper, Setlistly, SetBook, Set List Maker, All Set — treated as feature-landscape signal, filtered through the API-boundary constraint

### Tertiary (LOW confidence)
- Individual community blog posts on Hive/Isar/Drift maintenance status — treated as directional input only, not as version/maintenance fact

---
*Research completed: 2026-08-14*
*Ready for roadmap: yes*
