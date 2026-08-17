# Walking Skeleton — Cadence

**Phase:** 1
**Generated:** 2026-08-15

## Capability Proven End-to-End

A signed-in band member can view their real profile (username + id) on a screen backed by `GET /api/me`, rendered through a Riverpod provider that reads/writes a Hive-backed local cache — and the same screen still shows the last-fetched profile when the device has no connectivity.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| State management | Riverpod 3.x (`flutter_riverpod` ^3.4.2) with codegen (`riverpod_annotation` ^4.0.6 / `riverpod_generator` ^4.0.8 / `build_runner` ^2.16.0) | Per CONTEXT.md D-08/D-09/D-10 — replaces `ChangeNotifier`/`ValueNotifier` + constructor DI; codegen is a deliberate, scoped exception introducing `build_runner` to this codebase for the first time. Versions re-verified live against the pub.dev registry during planning (2026-08-15), superseding earlier stale figures in 01-RESEARCH.md. |
| Local cache | Hive 2.2.3 (`hive_flutter` ^1.1.0), one `Box<Map>` per endpoint (`profileBox`, `homepageBox`), storing raw decoded JSON | D-01/D-02/D-03 — pure Dart, no native deps; the cache stores per-endpoint response blobs, not normalized/relational data, so a KV store beats sqflite. |
| Auth token storage | Unchanged: `flutter_secure_storage` via `TokenStorage`, read/written through a Riverpod `AuthSession` AsyncNotifier instead of a `ChangeNotifier` | Minimizes churn on the already-working token mechanism (CLAUDE.md constraint); only the reactivity layer moves. |
| API client wiring | `ApiClient` decoupled from the concrete `AuthSession` type via two callbacks — `getToken` (`String? Function()`) and `onUnauthorized` (`Future<void> Function()`) — constructed by `apiClientProvider` | D-09 requires `ApiClient`/`PublicApi`/`TokenStorage` construction to move inside Riverpod. A Riverpod-generated `AuthSession` class is not a plain object with a synchronous `.token` getter, so `ApiClient` depends on two closures instead of the concrete class — keeping it framework-agnostic while auth state is Riverpod-native. |
| Deployment target | `flutter run` on Android/iOS simulators/devices; web excluded this milestone | CLAUDE.md platform scope. |
| Directory layout | New `lib/providers/` (Riverpod codegen providers) and `lib/cache/` (Hive service); existing `lib/api/`, `lib/features/*`, `lib/theme/`, `lib/navigation/` retained | Matches 01-RESEARCH.md's Recommended Project Structure. |

## Stack Touched in Phase 1

- [x] Project scaffold — `pubspec.yaml` gains `flutter_riverpod`, `riverpod_annotation`, `hive`, `hive_flutter` (deps) and `riverpod_generator`, `build_runner` (dev deps); `dart run build_runner build --delete-conflicting-outputs` becomes a required pre-run step.
- [x] Routing — `AuthGate` rewritten as a `ConsumerWidget` watching `authSessionProvider`; routes to `LoginScreen` or the authenticated `RootScaffold` builder.
- [x] Database — real read AND write: `CacheService.readProfile()`/`writeProfile()` against Hive's `profileBox`, exercised by `ProfileData.build()`.
- [x] UI — `ProfileScreen` is a real interactive `ConsumerWidget`: renders live data, has a working refresh `IconButton`, and a working "Log out" action wired to `authSessionProvider.notifier.signOut()`.
- [x] Local full-stack run — documented command: `flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run` (add `--dart-define=API_BASE_URL=...` to point at a real backend; defaults to `http://localhost:8080`).

## Out of Scope (Deferred to Later Slices)

- Bands/Tracks/Setlists CRUD (Phase 2-4) — `BandsScreen`/`SongsScreen` remain untouched placeholders this phase.
- "Last synced Xm ago" staleness indicator and its warning-style escalation — explicitly deferred to Phase 5 (OFFL-03/D-05); Phase 1 ships cache-first loading with zero staleness cue.
- Offline mutation blocking / global offline banner — Phase 5 (OFFL-03/OFFL-05); Phase 1 has no mutation UI at all yet.
- Real "Create Band" flow — Home's empty-state button navigates to the existing (placeholder) Bands tab; it does not create a band.

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Bands — full CRUD + membership, reusing the Riverpod + Hive-per-endpoint pattern proven here (new `bandsBox`).
- Phase 3: Tracks — song catalog CRUD within a band.
- Phase 4: Setlists — setlist CRUD, track ordering, running duration.
- Phase 5: Offline Trust & Connectivity UX — staleness indicators, offline banner, mutation blocking, applied consistently across every screen built in Phases 1-4.
