# Cadence

## What This Is

Cadence is a Flutter mobile app (Android/iOS, with web build support) for bands to manage their repertoire together: shared song catalog, band membership, and setlists for gigs. As of v1.0, the app has full band/track/setlist CRUD against the public API, runs on Riverpod state management with a Hive-backed cache-store pattern, and every cached screen shows staleness/connectivity signals with mutations gated while offline.

## Core Value

A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## Requirements

### Validated

- ✓ User can register with username/password — existing
- ✓ User can log in and session token persists across app restarts (secure storage) — existing
- ✓ 403 responses trigger automatic logout — existing
- ✓ App shell exists: bottom nav (Home/Songs/Bands/Profile), light/dark theme — existing
- ✓ User can view their profile (`GET /api/me`) and homepage summary (`GET /api/homepage`) — Phase 1
- ✓ App migrates off constructor-injected ChangeNotifier/prop-drilling to Riverpod, with a working local cache layer (proven end-to-end on profile/homepage) — Phase 1
- ✓ User can list, create, view, update, and delete tracks within a band, plus view them cross-band via a global filterable Tracks tab — Phase 3
- ✓ User can list, create, view, update, and delete setlists within a band — Phase 4
- ✓ User can add/remove tracks on a setlist and reorder them — Phase 4
- ✓ User can view all setlists across every band they belong to via a global filterable Setlists tab — Phase 4
- ✓ All GET-able band/track/setlist/profile data is cached locally on Android/iOS and remains viewable when offline; staleness indicators and connectivity-gated mutations are consistent across every screen — Phase 5
- ✓ User can list, create, view, update, and delete bands they belong to — Phase 2
- ✓ User can join a band via invite code — Phase 2
- ✓ User (owner) can remove a band member; any member can remove themselves — Phase 2

### Active

_(None yet — define next milestone's requirements via `/gsd-new-milestone`)_

### Out of Scope

- Offline writes / mutation queue with sync-on-reconnect — deferred; v1 is read-only cache, no conflict resolution needed yet
- Offline caching on web build — web stays online-only this milestone
- Real-time collaboration (live updates when another member edits) — not requested
- Track audio file storage/playback — API has no such field; out of scope until API adds it

## Context

**Shipped state (v1.0, 2026-08-17):** ~20,600 LOC Dart across `lib/` + `test/`, 284 tests passing, `flutter analyze` clean, zero TODO/stub/placeholder markers in production code. State flows through Riverpod (codegen'd AsyncNotifiers/family providers) end-to-end — no `ChangeNotifier`/prop-drilling remains. `lib/cache/cache_service.dart`'s Hive-backed `_HiveStore` (with recursive `_deepConvert` for nested collections) backs 5 boxes (profile, homepage, bands, tracks, setlists) via a `{data, syncedAt}` envelope on all 10 cache keys, giving every cached screen a staleness badge and connectivity-gated mutations (`isOnlineProvider`, `connectivity_plus`).

**API surface:** Full scope defined in `lib/api/publicapi.yml` (OpenAPI 3.0) — Users (register/login/me/homepage), Bands (CRUD, join, remove-member), Band Tracks (CRUD), Band Setlists (CRUD, add/remove/reorder track, bulk-add), plus a cross-band `GET /api/track/list` and `GET /api/setlist/list` added this milestone for the global filterable tabs. All endpoints except register/login require `sessionAuth`.

**Platform note:** Repo builds for Android, iOS, and web. Offline caching (v1.0) targets Android/iOS only — web stays online-only.

**API gaps closed this milestone:** `publicapi.yml` was extended with `UserProfile.id`, `Band.ownerId`, `GET /api/track/list`, `GET /api/setlist/list`, and bulk setlist-track add — all now implemented and integrated.

**Known non-blocking items carried into next milestone:** one manual accessibility check outstanding (offline-banner text under ≥200% font scaling, Phase 5); Nyquist `/gsd-validate-phase` never run this milestone (coverage TODO, not a compliance failure) — see `.planning/milestones/v1.0-MILESTONE-AUDIT.md`.

## Constraints

- **Tech stack**: Flutter/Dart, must reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns rather than replacing them — minimize churn on already-working auth
- **Offline scope**: Read-only cache (last-fetched data viewable offline); no offline mutation queue, no conflict resolution — keeps v1 scope bounded
- **Platform scope**: Local caching required on Android/iOS; web excluded this milestone
- **API contract**: `lib/api/publicapi.yml` is the source of truth for all request/response shapes — no inventing fields or endpoints not defined there

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Read-only offline cache, not offline writes+sync | Keeps v1 scope bounded — no conflict resolution or retry-queue complexity needed | ✓ Good — held through Phase 5 |
| Offline caching mobile-only (Android/iOS), web excluded | Web already requires network for the pipeline/hosting model; avoids browser storage quirks this milestone | ✓ Good |
| Persist login token across restarts | Already implemented via flutter_secure_storage; confirmed as desired behavior going forward | ✓ Good |
| Introduce Provider or Riverpod for state management | Band/track/setlist screens need shared state across tabs; current ChangeNotifier+DI prop-drilling was already flagged as an anti-pattern in the codebase map | ✓ Good — Phase 1 |
| Extend `publicapi.yml` with `UserProfile.id` and `Band.ownerId` rather than fake it client-side | Client genuinely cannot self-identify or gate owner-only UI without these; username-matching or hiding-nothing were the only workarounds and both are fragile/wrong | ✓ Good — backend shipped it, Phase 2 uses it directly |
| Extend `publicapi.yml` with `GET /api/track/list` (cross-band, `bandId`-filterable) for TRACK-06 | No existing endpoint returns tracks across all of a user's bands; per-band-only would require N calls and defeats the global tab's purpose | ✓ Good — Phase 3 |
| Track/setlist mutation endpoints must always send all editable fields on update (not just changed ones) | Server's partial-update semantics treat an omitted field as "keep" and an explicit `null` as "clear" — conditional-send silently failed to clear optional fields (03-04 CR-02 gap) | ✓ Good — Phase 3, applies to any future PUT/PATCH with optional clearable fields |
| Extend `publicapi.yml` with `POST .../setlist/{setlistId}/tracks` (bulk add) and `GET /api/setlist/list` (cross-band, `bandId`-filterable) for SETL-06/SETL-10 | No bulk-add endpoint existed (only single-track add); no endpoint returned setlists across all of a user's bands, mirroring Phase 3's TRACK-06 gap | ✓ Good — Phase 4 |
| Recursive `_deepConvert()` at the Hive store boundary rather than per-call-site casting | Phase 2's initial verification (02-VERIFICATION.md) found Hive returns untyped `Map<dynamic,dynamic>`/`List<dynamic>` for nested collections; a shallow top-level conversion missed it, only catchable by a real Hive close+reopen test (in-memory test double hid it entirely) | ✓ Good — Phase 2 gap-closure (02-06); pattern reused for free by every later Hive-backed box |
| Monotonic `_version` counter guard on AsyncNotifier background refreshes | Unawaited background `_refresh()` on cache-hit could silently overwrite a local mutation (rename, setBands) that landed first, with no ordering guarantee | ✓ Good — Phase 2 gap-closure (02-06); reused as-is for Tracks/Setlists providers |
| `ref.exists()` guard before reading a sibling provider's `.notifier` from an unrelated screen | Reading `.notifier` on a never-watched provider instantiates it and fires an unplanned network call as a side effect — broke 3 pre-existing tests when first hit in Phase 2 | ✓ Good — established as the standing pattern for any cross-provider notifier read |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-17 after v1.0 milestone*
