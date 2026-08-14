# Stack Research

**Domain:** Flutter mobile app (Android/iOS) — offline read-cache for REST data + state management migration
**Researched:** 2026-08-14
**Confidence:** MEDIUM (web-sourced findings cross-checked directly against pub.dev package pages and official docs; no curated-docs provider (Context7/Ref) was available in this session, so the generic confidence tier defaults to LOW per the classify-confidence seam — treat the specific version numbers below as verified against the authoritative registry, but re-run `flutter pub outdated` before committing to versions since pub.dev listing dates are relative ("N days/months ago") not absolute)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **drift** | `^2.34.3` | Type-safe, reactive local database (SQLite under the hood) for the offline read cache | The 2025/2026 consensus pick for Flutter local persistence: SQL-backed, compile-time type-safe, actively maintained, reactive streams out of the box (a `Stream<List<Track>>` query auto-updates the UI when cache is refreshed — no manual `setState`/notify wiring needed), and works on every Flutter target including web (future-proofs the "web excluded this milestone" constraint if that changes later). Multiple independent 2026 sources converge on "default to Drift" language specifically because Hive/Isar lost their maintainer and Realm's sync layer was discontinued by MongoDB — Drift is the one option in this space with no maintenance-risk asterisk. |
| **drift_flutter** | `^0.3.1` | Flutter-specific helper to open/locate the SQLite database file | Provides `driftDatabase(name: ...)`, which auto-resolves the correct storage path via `path_provider` and loads the native SQLite library correctly per-platform. Replaces the old manual `sqlite3_flutter_libs` + `path_provider` wiring — `sqlite3_flutter_libs` is now published as `0.6.0+eol` and explicitly marked obsolete on pub.dev, so do not add it to a new project. |
| **flutter_riverpod** | `^3.4.2` | App-wide state management — replaces constructor-injected `ChangeNotifier` + prop-drilling | This is the change PROJECT.md already flags as needed ("app migrates off constructor-injected ChangeNotifier/prop-drilling"). Riverpod is the 2025/2026 default recommendation for new/actively-growing Flutter apps: no `BuildContext` dependency (works in services/repositories, not just widgets), compile-time-safe provider graph, and `AsyncValue` gives loading/data/error states for free — which matters directly here because every band/track/setlist screen is "fetch from API, fall back to cache when offline," i.e. an async-state problem Riverpod is built for. It also composes cleanly with a Drift-backed repository: a `StreamProvider` can wrap a Drift watch-query directly. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `drift_dev` (dev dependency) | `^2.34.5` | Code generator that turns Drift table/DAO definitions into type-safe Dart classes and query methods | Always, alongside `drift` — required at build time, not runtime. |
| `build_runner` (dev dependency) | `^2.15.2` | Runs `drift_dev`'s code generation (`dart run build_runner build` / `watch`) | Always, alongside `drift_dev`. Already the standard Dart codegen entrypoint — no new tooling concept for the team. |
| `connectivity_plus` | latest (`^7.x` as of 2026) | Detect online/offline state to decide "hit network" vs "read from cache" and to gate mutation UI (mutations require connectivity per PROJECT.md) | Needed the moment you implement the read-through-cache pattern (see ARCHITECTURE.md pattern below) and to disable create/edit/delete actions while offline. Simpler and more actively maintained than rolling your own `Socket`/DNS probe. |
| `riverpod_annotation` + `riverpod_generator` (dev) | `^4.0.6` / matching `riverpod_generator` release | Code-generation flavor of Riverpod (`@riverpod` annotations instead of manually typed `Provider`/`StateNotifierProvider` classes) | **Optional, not required.** Riverpod's own docs present codegen as one of two equally valid starting points, not the default. Given this app is still small (4 tabs, CRUD over ~3 resources) and already uses `build_runner` for Drift, you *can* adopt codegen for consistency — but the plain (non-codegen) `flutter_riverpod` API is less machinery for a codebase migrating off constructor injection for the first time. Recommend starting **without** codegen and revisiting if the provider graph grows past ~15-20 providers. |
| `riverpod_lint` + `custom_lint` (dev) | latest matching `flutter_riverpod` major | Lint rules that catch common Riverpod misuse (e.g., providers that should be `.autoDispose`, missing `ref.watch` vs `ref.read` misuse) | Add once Riverpod is in and the team wants stricter guardrails; not a blocker for adoption. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Drift's `NativeDatabase`/`driftDatabase` inspector (via `drift_dev` codegen) | Compile-time verification that SQL queries match table schema | Catches typos in column names and type mismatches at build time instead of at runtime — directly reduces the risk class this migration is meant to avoid (broken offline cache silently returning wrong data). |
| `flutter pub outdated` | Verify the exact pinned versions above are still current before implementation | Pub.dev version numbers in this report were fetched live but dated relatively ("17 days ago", "2 months ago") — re-check immediately before `pubspec.yaml` edits land. |

## Installation

```bash
# Core: offline cache
flutter pub add drift drift_flutter path_provider
flutter pub add -d drift_dev build_runner

# Core: state management
flutter pub add flutter_riverpod

# Supporting: connectivity detection for cache/mutation gating
flutter pub add connectivity_plus

# Optional (only if adopting Riverpod codegen from the start):
# flutter pub add riverpod_annotation
# flutter pub add -d riverpod_generator custom_lint riverpod_lint
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| drift | **sqflite** (raw) | If the cache schema is truly trivial (one or two flat tables, no joins) and the team wants zero codegen. `sqflite` (`^2.4.3`, still a "Flutter Favorite," actively maintained, published ~2 months ago) is fine for hand-written SQL, but you lose compile-time query safety and get no built-in reactive streams — you'd have to bolt those on yourself. Given this milestone caches four related resources (bands, tracks, setlists, setlist-track join data) with real relationships, Drift's type safety and joins pay for themselves quickly. |
| drift | **Hive** / **Isar** | Only if the team already has deep Hive/Isar experience and the data is purely key-value/document-shaped with no relational queries. Both lost their original maintainer in 2025; Isar in particular has had long-running "is this still maintained?" community threads. Not a place to start a new dependency in 2026 — existing apps that already use them have no urgency to migrate, but greenfield code (this cache layer is greenfield) should avoid them. |
| drift | **shared_preferences + manual JSON** | Never for structured relational data like this milestone's (bands → tracks → setlists → setlist_tracks). `shared_preferences` is a flat key-value store; you'd be reimplementing a database's serialization/query logic by hand for every screen. Reasonable only for tiny singleton blobs (e.g., "last selected band ID," a single feature flag) — keep using it for exactly that if it's already in the app, but not for the offline dataset. |
| flutter_riverpod (non-codegen) | **flutter_riverpod + riverpod_generator (codegen)** | Once the provider graph grows (many async providers, families, complex dependency chains) or the team wants stricter lint-enforced discipline. Revisit after this milestone ships; don't front-load the extra generator/lint setup for a first migration off prop-drilling. |
| flutter_riverpod | **Provider** (`^6.1.5+1`) | Only if you want the absolute smallest conceptual jump from the current `ChangeNotifier`+`ListenableBuilder` pattern already in the codebase (Provider is essentially "ChangeNotifier + InheritedWidget, formalized"). It's still maintained (Flutter Favorite, verified publisher, ~1M+ downloads) and viable for small/legacy apps, but 2025/2026 guidance is consistent: no reason to *start* new work on Provider when Riverpod removes its main pain points (BuildContext coupling, no compile-time provider-type safety) at a modest learning cost. Since PROJECT.md explicitly names "Provider or Riverpod" as the two options and this is new state (bands/tracks/setlists, not a refactor of existing AuthSession), Riverpod is the better default. |
| flutter_riverpod | **BLoC/flutter_bloc** | If the team anticipates needing a highly auditable, ceremony-heavy state pattern (common in larger/regulated teams) or already has BLoC expertise. Overkill for a 4-tab CRUD app at this stage — steeper boilerplate than Riverpod for the same async-data-fetching problem this milestone actually has. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| `sqlite3_flutter_libs` | Published as `0.6.0+eol` on pub.dev and explicitly documented as obsolete — it targeted `sqlite3` 2.x and serves no purpose once you're on `sqlite3` 3.x, which `drift_flutter` already pulls in transitively. | `drift_flutter` (handles native library loading internally) |
| Hive / Isar for new tables | Original maintainer stepped away in 2025; community forks (e.g. `hive_ce`) exist but add a second layer of "will this be maintained" risk on top of a milestone whose whole point is reliability of the offline cache. | `drift` |
| GetIt / service-locator pattern as the *only* fix for prop-drilling | Solves dependency access but not reactive UI updates — you'd still need a separate mechanism (ChangeNotifier, Riverpod, etc.) to make widgets rebuild when band/track/setlist data changes. ARCHITECTURE.md's own "Anti-Patterns" section already names this class of problem. | `flutter_riverpod` (handles both DI *and* reactive rebuilds in one abstraction) |
| Rolling a custom retry-queue / mutation-sync layer this milestone | PROJECT.md explicitly scopes this out ("Offline writes / mutation queue with sync-on-reconnect — deferred"). Building it now is scope creep beyond what was researched/decided. | Read-only cache: fetch-then-cache-then-serve-from-cache-when-offline; mutations simply require connectivity and surface a clear error via the existing `ApiException` pattern when offline. |

## Stack Patterns by Variant

**If the read-cache needs to survive app reinstall or be shared across the phone/tablet split (not this milestone, but worth flagging for later):**
- Drift's `NativeDatabase` file lives in app-private storage by default via `drift_flutter` — this is already the correct, sandboxed location for Android/iOS. No extra work needed for this milestone's stated scope.

**If offline writes/sync are added in a future milestone:**
- Keep the same Drift schema; add a `pending_mutation` outbox table and a sync worker. Riverpod's `AsyncNotifier` is the natural place to own "is there a pending sync" state. Do not build this now — it's explicitly out of scope for this milestone, called out above.

**Given the existing `ApiClient`/`AuthSession`/`TokenStorage` layer must be preserved as-is (per milestone constraint):**
- Introduce a `Repository` layer (e.g., `BandRepository`, `TrackRepository`) between the UI/Riverpod providers and `ApiClient`. Repository methods do: try network via existing `ApiClient` → on success, write result into Drift tables → on failure/offline, read last-cached rows from Drift and return those. This is the standard "single source of truth" repository pattern for offline-capable apps and keeps `ApiClient`/`AuthSession` completely untouched, satisfying "minimize churn on already-working auth."
- Wrap repository methods in Riverpod `FutureProvider`/`StreamProvider` (e.g., a `StreamProvider<List<Track>>` that watches the Drift table directly for UI, refreshed by a repository-triggered network fetch) — this gives automatic UI updates when the cache is written to, without extra plumbing.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| `drift ^2.34.3` | `drift_dev ^2.34.5`, `drift_flutter ^0.3.1` | Drift's own setup docs (drift.simonbinder.eu) pin these together as of the current release line; keep `drift` and `drift_dev` on matching minor lines to avoid codegen/runtime mismatches. |
| `flutter_riverpod ^3.4.2` | `riverpod ^3.4.2` (transitive), `riverpod_annotation ^4.0.6` (if codegen adopted) | Riverpod 3.x is the current major generation as of this research; `riverpod_annotation` 4.x is the version line that targets Riverpod 3.x — don't mix `riverpod_annotation` 2.x docs/examples (common in older tutorials) with `flutter_riverpod` 3.x, the annotation API changed across the 2→3 major bump. |
| Dart `^3.12.2` (existing project SDK constraint) | `drift ^2.34.x`, `flutter_riverpod ^3.4.2` | Both packages' current release lines target modern Dart 3.x SDKs; no constraint conflict expected with the existing `pubspec.yaml` SDK floor. |

## Sources

- pub.dev/packages/drift — version (2.34.3), dependency list — fetched directly, MEDIUM confidence (official registry, but generic web-fetch tooling tier)
- pub.dev/packages/flutter_riverpod — version (3.4.2), dependencies — fetched directly
- pub.dev/packages/riverpod_annotation — version (4.0.6), riverpod 3.x dependency confirmed
- pub.dev/packages/sqlite3_flutter_libs — confirmed `0.6.0+eol`/obsolete status
- pub.dev/packages/sqflite — version (2.4.3), maintenance signals (Flutter Favorite, recent publish)
- pub.dev/packages/provider — version (6.1.5+1), maintenance signals
- drift.simonbinder.eu/setup — official Drift Flutter setup guide (dependency list, `drift_flutter` role)
- riverpod.dev/docs/introduction/getting_started — confirms codegen is optional, not the default, in official docs
- General web search (multiple 2025/2026 comparison articles: Luci Studio "Flutter Local Database Landscape in 2026," Bacancy/Softaims/FlutterFever/StartDebugging Riverpod-vs-Provider-vs-BLoC 2026 pieces) — cross-checked consensus on Drift-as-default and Riverpod-as-default-for-new-projects; treated as directional/consensus signal (LOW-tier individually), not as version source of truth

---
*Stack research for: Flutter offline caching + state management migration (Cadence, band repertoire app)*
*Researched: 2026-08-14*
