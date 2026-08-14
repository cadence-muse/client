# Architecture Research

**Domain:** Flutter mobile app — REST-backed feature CRUD + offline read cache, migrating off constructor-DI to Riverpod
**Researched:** 2026-08-14
**Confidence:** MEDIUM-HIGH (repository/cache pattern is corroborated by official Flutter architecture docs — HIGH; specific local-DB package choice is LOW-confidence community opinion, treated as a recommendation not a fact)

## Standard Architecture

### System Overview

The existing `lib/api/` layer (ApiClient, AuthSession, PublicApi, TokenStorage) stays intact and unchanged. Three new layers are inserted between it and the feature screens: a generic **Cache** layer, a per-entity **Repository** layer that implements network-first-with-cache-fallback, and a **Provider (Riverpod)** layer that replaces constructor-injected prop-drilling.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UI Layer (existing)                         │
│  lib/features/{home,songs,bands,profile}/  — now ConsumerWidgets     │
│  watch Riverpod providers instead of receiving DI via constructors   │
└───────────────────────────────┬───────────────────────────────────────┘
                                 │ ref.watch(xProvider)
┌───────────────────────────────▼───────────────────────────────────────┐
│                    Provider Layer (NEW — lib/providers/)              │
│  apiClientProvider · authSessionProvider · cacheStoreProvider         │
│  bandsRepositoryProvider · tracksRepositoryProvider · ...             │
│  bandsListProvider(FutureProvider) · bandTracksProvider(family) · ... │
└───────────────────────────────┬───────────────────────────────────────┘
                                 │
┌───────────────────────────────▼───────────────────────────────────────┐
│                Repository Layer (NEW — lib/repositories/)             │
│  BandsRepository · TracksRepository · SetlistsRepository ·            │
│  ProfileRepository                                                    │
│  Reads: network-first, fall back to cache on network-class failure    │
│  Writes: online-only, update/invalidate cache keys on success         │
└──────────┬───────────────────────────────────────────┬────────────────┘
           │                                            │
┌──────────▼──────────────────┐          ┌──────────────▼─────────────────┐
│   API Layer (existing +NEW) │          │   Cache Layer (NEW — lib/cache/) │
│   lib/api/                  │          │   CacheStore (abstract)          │
│   ApiClient (unchanged)     │          │   ├─ sqflite impl (Android/iOS)  │
│   AuthSession (unchanged)   │          │   └─ no-op impl (web, excluded)  │
│   PublicApi (unchanged)     │          │   Stores {key → json, fetchedAt} │
│   BandsApi/TracksApi/       │          │   keyed by request signature     │
│   SetlistsApi/ProfileApi(NEW)│         └───────────────────────────────────┘
└──────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `ApiClient` (existing, unchanged) | HTTP transport, auth header injection, 403 auto-logout | Already in `lib/api/api_client.dart` — do not modify for caching |
| `BandsApi` / `TracksApi` / `SetlistsApi` / `ProfileApi` (new) | Thin typed wrappers over `ApiClient.send()`, one per `publicapi.yml` resource group | Mirror `PublicApi`'s existing pattern exactly — same file layout, same error propagation |
| `CacheStore` (new) | Generic, feature-agnostic key→JSON blob store with a timestamp; no domain knowledge | Single-table local store (see Technology Choice below), abstract interface + platform impls via conditional import (same technique as `http_client_factory_*`) |
| `*Repository` (new, one per entity) | Owns the network-first/cache-fallback policy for reads; online-only for writes; decides cache keys and invalidation | Plain Dart class depending on one `*Api` + `CacheStore`; returns a small `CacheResult<T>{data, fromCache, fetchedAt}` wrapper, not raw models |
| Riverpod providers (new) | Wire dependencies without constructor threading; expose async state to widgets | `Provider` for singletons (ApiClient, CacheStore, Repositories), `FutureProvider`/`AsyncNotifierProvider` (optionally `.family` for band-scoped data) for screen-facing state |
| Feature screens (existing dirs, rewritten) | Render `AsyncValue`, show "offline — showing cached data from HH:mm" affordance when `fromCache == true` | `ConsumerWidget`/`ConsumerStatefulWidget` |

## Recommended Project Structure

```
lib/
├── api/                          # existing — HTTP/auth, extended with new typed clients
│   ├── api_client.dart           # unchanged
│   ├── auth_session.dart         # unchanged
│   ├── public_api.dart           # unchanged (login/register)
│   ├── bands_api.dart            # NEW — /api/bands* CRUD + join + remove-member
│   ├── tracks_api.dart           # NEW — /api/bands/{id}/tracks* CRUD
│   ├── setlists_api.dart         # NEW — /api/bands/{id}/setlists* CRUD + track add/remove/reorder
│   ├── profile_api.dart          # NEW — /api/me, /api/homepage
│   ├── api_exception.dart        # existing — add an isNetworkError classifier (see Pattern 2)
│   └── token_storage.dart        # unchanged
├── cache/                        # NEW — generic offline cache infra, no domain knowledge
│   ├── cache_store.dart          # abstract interface: get(key), put(key, json, fetchedAt), clear()
│   ├── cache_store_io.dart       # sqflite-backed impl, used on Android/iOS
│   ├── cache_store_web.dart      # no-op impl — every get() misses (web excluded this milestone)
│   └── cache_store_factory.dart  # conditional-import selector (mirrors http_client_factory.dart)
├── repositories/                 # NEW — network-first-with-cache-fallback per entity
│   ├── bands_repository.dart
│   ├── tracks_repository.dart
│   ├── setlists_repository.dart
│   └── profile_repository.dart
├── providers/                    # NEW — Riverpod wiring, replaces constructor DI
│   ├── api_providers.dart        # apiClientProvider, authSessionProvider, *ApiProviders
│   ├── cache_providers.dart      # cacheStoreProvider
│   └── repository_providers.dart # *RepositoryProvider + screen-facing Future/AsyncNotifier providers
├── features/                     # existing — screens become ConsumerWidgets
│   ├── bands/  songs/  profile/  home/  auth/  settings/
└── navigation/, theme/, config/  # unchanged
```

### Structure Rationale

- **`lib/cache/` is a new top-level infra dir, not nested under `lib/api/`:** the cache store has zero knowledge of HTTP or the API shape — it is a generic key/JSON/timestamp store. Keeping it a sibling of `lib/api/` (matching the existing convention that `api/`, `config/`, `theme/` are infra-level, feature-agnostic directories) keeps `ApiClient` untouched and testable in isolation.
- **`lib/repositories/` is a new top-level dir, not folded into `lib/features/{feature}/`:** repository instances are typically consumed by more than one screen within a feature (e.g., a bands list screen and a band detail screen both need `BandsRepository`) and sometimes across features (Home screen's summary likely reads from the same `BandsRepository`/`ProfileRepository`). A shared top-level location avoids duplicating fetch/cache logic per screen.
- **`lib/providers/` is separated from both `api/` and `repositories/`:** keeps Riverpod-specific wiring (which is inherently a cross-cutting, app-wide concern) out of the plain-Dart data layer, so the API and repository layers stay framework-agnostic and unit-testable without a `ProviderContainer`.
- **`lib/features/{feature}/` keeps its existing role** (screens + feature-local models like `band.dart`) — only the *how it gets data* changes (from constructor-injected instances to `ref.watch(...)`), not the directory's purpose.

## Architectural Patterns

### Pattern 1: Repository as network-first-with-cache-fallback (the core pattern)

**What:** Each repository read method first attempts the real API call. On success, it decodes the response, writes the raw JSON to `CacheStore` under a deterministic key, and returns fresh data. On failure classified as a *network-class* error (no connectivity, DNS failure, timeout — not a 4xx/5xx business error, not a 403), it reads the same cache key and returns cached data if present; if there is no cached entry, it rethrows the original error.

**When to use:** All GET-backed reads for bands/tracks/setlists/profile (the milestone's entire offline-cache requirement).

**Trade-offs:** Simpler and more honest than a "stream cached-then-fresh" pattern (see Pattern 1b) because it never shows the user two different answers for the same screen load; costs one extra round trip to check cache only on the failure path, which is cheap.

**Example:**
```dart
class CacheResult<T> {
  final T data;
  final bool fromCache;
  final DateTime fetchedAt;
  const CacheResult(this.data, this.fromCache, this.fetchedAt);
}

class TracksRepository {
  TracksRepository(this._api, this._cache);
  final TracksApi _api;
  final CacheStore _cache;

  String _key(String bandId) => 'band:$bandId:tracks';

  Future<CacheResult<List<Track>>> getTracks(String bandId) async {
    final key = _key(bandId);
    try {
      final json = await _api.listTracks(bandId); // ApiClient under the hood
      await _cache.put(key, json, DateTime.now());
      return CacheResult(_decode(json), false, DateTime.now());
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow; // 403/4xx/5xx must propagate, not be masked by cache
      final cached = await _cache.get(key);
      if (cached == null) rethrow;
      return CacheResult(_decode(cached.json), true, cached.fetchedAt);
    }
  }

  List<Track> _decode(String json) => /* ... */ [];
}
```

### Pattern 1b (rejected for v1): Stream that emits cache-then-fresh

**What:** `Stream<T> getX()` emits the cached value immediately (if any), then emits the fresh network value when it arrives — the pattern shown in Flutter's own offline-first architecture guide.

**When to use:** Apps that want instant paint from cache even while online, with a background refresh.

**Trade-offs:** More responsive UX, but adds `StreamProvider`/subscription-lifecycle complexity and a "the screen just changed values under the user's cursor" UX question that v1 doesn't need. **Recommendation: skip for this milestone** — Pattern 1 (single Future, cache only as a fallback) is sufficient because the requirement is "viewable when offline," not "instant paint while online." Revisit if a later milestone wants perceived-latency optimization.

### Pattern 2: Classify errors before deciding to fall back to cache

**What:** Add an `isNetworkError` (or `ApiExceptionKind` enum) to the existing `ApiException` type so repositories can distinguish "device/API unreachable" (→ fall back to cache) from "403 unauthorized" (→ must still trigger `AuthSession.signOut()`, must NOT be masked by stale cached data) and "422/500 business error" (→ must surface to the user, must NOT be silently replaced by cache).

**When to use:** Every repository read/write method.

**Trade-offs:** A few extra lines in `ApiClient`/`ApiException`; without this, a 403 or validation error could be incorrectly swallowed by a cache-fallback and the auto-logout requirement (an already-validated, working behavior) could silently regress.

**Example:**
```dart
extension on ApiException {
  bool get isNetworkError => statusCode == null; // no HTTP response reached at all
}
```

### Pattern 3: connectivity_plus is a UI hint, not the read/write gate

**What:** Do not use `connectivity_plus`'s `checkConnectivity()`/`onConnectivityChanged` as the trigger for whether a repository attempts a network call or falls back to cache. `connectivity_plus` reports whether a network *interface* is up — not whether the API is actually reachable (captive portals, VPN drops, server outages all look "connected" to it). The correct trigger is Pattern 2: attempt the real request, classify the resulting exception.

**When to use:** Reserve `connectivity_plus` (optional dependency) purely for a lightweight, app-wide "You're offline" banner (e.g., in `RootScaffold`) for user feedback — it should never gate correctness.

**Trade-offs:** Slightly less "obviously offline-aware" code path than gating on connectivity state, but avoids both false positives (banner says offline while API is actually reachable over a different route) and false negatives (banner says online, but request still times out) — the network attempt itself is always the ground truth.

## Data Flow

### Read Flow (online/offline branching, this is the flow that matters most for the roadmap)

```
Screen (ConsumerWidget)
   │ ref.watch(bandTracksProvider(bandId))
   ▼
FutureProvider.family in lib/providers/repository_providers.dart
   │ calls
   ▼
TracksRepository.getTracks(bandId)
   │
   ├─ 1. await TracksApi.listTracks(bandId)  ──▶ ApiClient.send('GET', ...)
   │
   ├─ 2a. SUCCESS ─▶ decode JSON ─▶ CacheStore.put(key, json, now)
   │                 ─▶ return CacheResult(data, fromCache: false, fetchedAt: now)
   │
   └─ 2b. ApiException thrown
          │
          ├─ isNetworkError == false (403 / 4xx / 5xx)
          │      ─▶ rethrow (403 still drives AuthSession.signOut() as today;
          │         business errors still surface to the user — never masked by cache)
          │
          └─ isNetworkError == true (timeout / unreachable / DNS failure)
                 │
                 ├─ CacheStore.get(key) HIT
                 │      ─▶ decode cached JSON
                 │      ─▶ return CacheResult(data, fromCache: true, fetchedAt: cachedAt)
                 │
                 └─ CacheStore.get(key) MISS
                        ─▶ rethrow (nothing to show — screen shows an error state)
   ▼
AsyncValue<CacheResult<List<Track>>> in the provider
   ▼
Screen renders list; if result.fromCache, shows
"Offline — showing data from {fetchedAt}" banner instead of a stale-looking silent list
```

### Write Flow (online-only, per "mutations require connectivity")

```
Screen action (e.g. "add track")
   ▼
TracksRepository.createTrack(bandId, input)
   │ await TracksApi.create(bandId, input)  — no cache read/fallback attempted
   ├─ SUCCESS ─▶ update/merge the band:$bandId:tracks cache entry immediately
   │             (the device was online for this write — keep the cache fresh so
   │             the very next offline read reflects the mutation without a refetch)
   └─ FAILURE ─▶ rethrow ApiException as-is; screen shows retry-when-online error
                 (no queue, no optimistic local write — out of scope this milestone)
```

### State Management (Riverpod, replacing constructor DI)

```
ProviderScope (root, in main.dart/app.dart)
   │
   ├─ authSessionProvider   → wraps the *existing* AuthSession instance/class as-is
   ├─ apiClientProvider     → reads authSessionProvider, constructs ApiClient (unchanged class)
   ├─ cacheStoreProvider    → platform-selected CacheStore (sqflite on io, no-op on web)
   ├─ *ApiProviders (bandsApiProvider, tracksApiProvider, ...) → wrap apiClientProvider
   ├─ *RepositoryProviders (bandsRepositoryProvider, ...) → wrap *ApiProvider + cacheStoreProvider
   └─ screen-facing providers (bandsListProvider, bandTracksProvider(bandId), ...)
        → FutureProvider / FutureProvider.family calling into a repository
   ▼
Widgets: ConsumerWidget.build(context, ref) → ref.watch(...) → AsyncValue.when(...)
```

### Key Data Flows

1. **Cache-key scoping:** cache keys are request signatures, not entity IDs alone (`band:$bandId:tracks`, `band:$bandId:setlists`, `setlist:$setlistId`, `bands:list`, `me:profile`, `me:homepage`) — this keeps the cache a dumb, generic key→JSON store with no relational/foreign-key modeling, matching the "last-fetched response, read-only" scope explicitly chosen for v1.
2. **AuthSession stays authoritative for 403 handling:** the cache-fallback path never intercepts a 403; `ApiClient`'s existing auto-logout behavior is preserved unchanged, so the offline feature cannot accidentally let a logged-out/revoked session keep showing cached data as if it were a valid, authenticated view. (Whether cached data should be purged on sign-out is a product decision to make explicit in the phase that builds `CacheStore` — recommend clearing on `signOut()` to avoid one user's cached band data leaking into a different user's session on a shared device.)

## Scaling Considerations

This is a small per-device local cache, not a server-scaling concern — "scale" here means data volume per band, not concurrent users.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Small band (few tracks/setlists) | Current design (whole-list JSON blob per cache key) is more than sufficient; no pagination needed |
| Large band (hundreds of tracks/setlists) | Still fine for a read-only "last fetched snapshot" cache; if the API paginates, cache per-page keys rather than one giant blob |
| Multiple bands, long-term app use | Add a simple TTL/eviction policy (e.g., drop cache entries not read in N days) and clear cache on `signOut()` — otherwise the local store grows unbounded across every band/setlist a user has ever viewed |

### Scaling Priorities

1. **First real risk:** stale-looking data with no indication it's stale — mitigated by always carrying `fetchedAt`/`fromCache` through to the UI (Pattern 1), not a storage-scale problem.
2. **Second risk:** cache leaking across accounts on a shared device — mitigated by clearing `CacheStore` on sign-out.

## Anti-Patterns

### Anti-Pattern 1: Gating cache-fallback on `connectivity_plus` connectivity state

**What people do:** Check `connectivity_plus` before deciding whether to call the API at all, and treat "connected" as "cache fallback not needed."
**Why it's wrong:** An "up" network interface doesn't mean the API is reachable (captive portals, VPN misconfiguration, server outage). This produces both false "online, but request still fails" surprises and unnecessary offline banners when the API is actually fine.
**Do this instead:** Always attempt the request; classify the resulting exception (Pattern 2) to decide whether to read from cache. Use `connectivity_plus` only for an optional, non-authoritative UI banner.

### Anti-Pattern 2: Building a full relational offline mirror for v1

**What people do:** Reach for a relational embedded DB (e.g., Drift/SQLite) and replicate every API entity with foreign keys, on the assumption offline caching always means "a local copy of the database."
**Why it's wrong:** The milestone's scope is explicitly "last-fetched response, read-only, no offline mutation queue, no conflict resolution" — a relational schema with FK constraints, migrations, and joins solves problems (offline querying/filtering, cross-entity joins while offline) that this milestone doesn't have. It's meaningfully more code and more moving parts (schema versioning, generated code) for no v1 benefit.
**Do this instead:** A single generic `cache_entries(key TEXT PRIMARY KEY, json TEXT, fetched_at INTEGER)` table (or equivalent key-value store) is sufficient — the "relation" between a band and its tracks is already expressed by the cache *key* (`band:$id:tracks`), not by SQL foreign keys. Revisit only if a future milestone needs offline filtering/search across cached entities.

### Anti-Pattern 3: Silently serving stale data without surfacing staleness

**What people do:** Return cached data from the repository looking identical to fresh data, with no `fromCache`/`fetchedAt` signal reaching the UI.
**Why it's wrong:** Users at a venue with no signal (the stated core value) need to trust what they're looking at — a setlist that's actually 3 days old, shown with no indication, can lead to on-stage surprises (a track was removed/reordered since).
**Do this instead:** Thread `CacheResult{data, fromCache, fetchedAt}` all the way to the widget layer and always render an "offline — data from {time}" affordance when `fromCache == true`.

### Anti-Pattern 4: Letting cache-fallback mask auth/business errors

**What people do:** Catch *every* exception in the repository and fall back to cache, including 403s and validation errors.
**Why it's wrong:** A 403 must still trigger `AuthSession.signOut()` (an already-validated, working behavior per `PROJECT.md`) — masking it with cached data would mean a logged-out session appears to still work. A 422/500 is a real, actionable error the user needs to see, not something the cache should paper over.
**Do this instead:** Only network-class exceptions (no HTTP response reached) trigger cache fallback (Pattern 2); everything else propagates unchanged.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Cadence public API (`lib/api/publicapi.yml`) | Existing `ApiClient.send()`, extended with new typed `*Api` classes per resource group | Source of truth for shapes — no inventing fields/endpoints per `PROJECT.md` constraint |
| Local cache store (sqflite or equivalent) | New `CacheStore` abstraction behind conditional import (mirrors existing `http_client_factory_*` web/io/stub split) | Android/iOS only this milestone; web gets a no-op impl so behavior there is unchanged (network-only, as today) |
| `connectivity_plus` (optional, new) | Read-only UI hint via `onConnectivityChanged` stream, e.g. driving a `RootScaffold`-level banner | Not used to gate repository read/write logic (Pattern 3) |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI ↔ Provider layer | `ref.watch(provider)` / `AsyncValue.when(...)` | Replaces constructor-injected prop-drilling flagged as an anti-pattern in the existing codebase map |
| Provider layer ↔ Repository layer | Direct method calls, repositories are plain Dart (no Riverpod imports inside `lib/repositories/`) | Keeps repositories unit-testable without a `ProviderContainer` |
| Repository ↔ API layer | Repository owns exactly one `*Api` instance; `*Api` classes never know about caching | Mirrors the existing `PublicApi` → `ApiClient` relationship exactly, so the pattern is already familiar in this codebase |
| Repository ↔ Cache layer | Repository owns cache-key naming and invalidation; `CacheStore` is dumb (key→JSON+timestamp only) | Keeps the cache layer entity-agnostic and reusable across all four repositories |
| `ApiClient`'s existing 403 auto-logout ↔ new cache-fallback | Cache-fallback only triggers on network-class errors (Pattern 2); 403 handling in `ApiClient` is untouched | Prevents the new offline feature from regressing the already-validated auto-logout behavior |

## Suggested Build Order

1. **Riverpod skeleton** — add `ProviderScope`, bridge existing `AuthSession`/`ApiClient` (unmodified classes) into `authSessionProvider`/`apiClientProvider`. No behavior change, but unblocks everything else and directly satisfies the "migrate off constructor-injected ChangeNotifier/prop-drilling" requirement first, in isolation, with minimal risk.
2. **Generic cache infra** (`lib/cache/`) — `CacheStore` interface + sqflite (or chosen store) impl + web no-op impl + conditional-import wiring. No dependency on domain models; can be built/tested standalone against fake keys.
3. **New typed `*Api` classes** (`lib/api/bands_api.dart`, `tracks_api.dart`, `setlists_api.dart`, `profile_api.dart`) — can proceed in parallel with step 2 since both depend only on the existing, unchanged `ApiClient`.
4. **Repository layer**, one entity at a time (Bands → Tracks → Setlists → Profile, matching dependency order since tracks/setlists are nested under a band) — each depends on steps 1–3 being done for that entity.
5. **Feature screens rewritten as `ConsumerWidget`s**, one feature at a time, consuming the repository providers and adding the offline/`fromCache` UI affordance — depends on step 4 for that feature.

This ordering means "state management migration" and "cache infrastructure" are natural early, foundational phases before any of the CRUD feature phases (Bands/Tracks/Setlists/Profile), which is a strong signal for how the roadmap should sequence phases: foundation first, then one vertical feature slice per phase reusing that foundation.

## Sources

- [Flutter official docs — Offline-first design pattern](https://docs.flutter.dev/app-architecture/design-patterns/offline-first) — HIGH confidence, official first-party architecture guidance; repository-as-single-source-of-truth, cache-then-fresh stream pattern, and online-only vs offline-first write tradeoffs are drawn directly from this source.
- [connectivity_plus package](https://pub.dev/packages/connectivity_plus) — MEDIUM confidence, official package page; confirms `checkConnectivity()`/`onConnectivityChanged` semantics and the explicit caveat that interface-connected ≠ API-reachable.
- Community comparison articles on Hive/Isar/Drift for local caching (Medium/blog sources aggregated via web search) — LOW confidence, general community opinion, not verified against current maintenance status of each package. Treated only as directional input to the "generic key-value cache, not a relational mirror" recommendation above, which is justified independently by this milestone's explicit read-only/no-relational-query scope (see Anti-Pattern 2) rather than by the package comparison itself.
- Existing codebase: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/PROJECT.md` — HIGH confidence, ground truth for current component boundaries, naming conventions, and milestone scope constraints.

---
*Architecture research for: Flutter offline-cache + band/track/setlist CRUD milestone*
*Researched: 2026-08-14*
