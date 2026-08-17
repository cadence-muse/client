# Cadence

## What This Is

Cadence is a Flutter mobile app (Android/iOS, with web build support) for bands to manage their repertoire together: shared song catalog, band membership, and setlists for gigs. Auth, band membership, and secure token persistence already exist; this milestone builds out full band/track/setlist management against the public API and adds offline read caching on mobile.

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

### Active

- [ ] User can list, create, view, update, and delete bands they belong to
- [ ] User can join a band via invite code
- [ ] User (owner) can remove a band member; any member can remove themselves

### Out of Scope

- Offline writes / mutation queue with sync-on-reconnect — deferred; v1 is read-only cache, no conflict resolution needed yet
- Offline caching on web build — web stays online-only this milestone
- Real-time collaboration (live updates when another member edits) — not requested
- Track audio file storage/playback — API has no such field; out of scope until API adds it

## Context

**Existing codebase (brownfield):** `lib/api/` already has `ApiClient` (HTTP wrapper + auth header injection + 403 auto-logout), `AuthSession` (ChangeNotifier), `PublicApi` (login/register only), `TokenStorage` (flutter_secure_storage). `lib/features/{home,songs,bands,profile}/` are placeholder screens; `bands_screen.dart` has a `Band` model stub only. No local database or offline support exists yet (`ARCHITECTURE.md` confirms: "No backend state management: no local database or offline support; app assumes network access").

**API surface:** Full scope is defined in `lib/api/publicapi.yml` (OpenAPI 3.0) — Users (register/login/me/homepage), Bands (CRUD, join, remove-member), Band Tracks (CRUD), Band Setlists (CRUD, add/remove/reorder track). All endpoints except register/login require `sessionAuth` (token via Authorization header / cookie).

**Platform note:** Repo builds for Android, iOS, and web (release pipeline + Dockerfile for web/ghcr exist per recent commits). Offline caching this milestone targets Android/iOS only.

**API gap:** `publicapi.yml` was extended with `UserProfile.id` and `Band.ownerId` (both required, both missing before this milestone) — the client cannot self-identify (for self-leave) or gate owner-only actions without them. See REQUIREMENTS.md "API Gaps" for the backend work needed and the client-side fallback until it ships.

## Constraints

- **Tech stack**: Flutter/Dart, must reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns rather than replacing them — minimize churn on already-working auth
- **Offline scope**: Read-only cache (last-fetched data viewable offline); no offline mutation queue, no conflict resolution — keeps v1 scope bounded
- **Platform scope**: Local caching required on Android/iOS; web excluded this milestone
- **API contract**: `lib/api/publicapi.yml` is the source of truth for all request/response shapes — no inventing fields or endpoints not defined there

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Read-only offline cache, not offline writes+sync | Keeps v1 scope bounded — no conflict resolution or retry-queue complexity needed | — Pending |
| Offline caching mobile-only (Android/iOS), web excluded | Web already requires network for the pipeline/hosting model; avoids browser storage quirks this milestone | — Pending |
| Persist login token across restarts | Already implemented via flutter_secure_storage; confirmed as desired behavior going forward | ✓ Good |
| Introduce Provider or Riverpod for state management | Band/track/setlist screens need shared state across tabs; current ChangeNotifier+DI prop-drilling was already flagged as an anti-pattern in the codebase map | ✓ Good — Phase 1 |
| Extend `publicapi.yml` with `UserProfile.id` and `Band.ownerId` rather than fake it client-side | Client genuinely cannot self-identify or gate owner-only UI without these; username-matching or hiding-nothing were the only workarounds and both are fragile/wrong | — Pending (needs backend implementation) |
| Extend `publicapi.yml` with `GET /api/track/list` (cross-band, `bandId`-filterable) for TRACK-06 | No existing endpoint returns tracks across all of a user's bands; per-band-only would require N calls and defeats the global tab's purpose | ✓ Good — Phase 3 |
| Track/setlist mutation endpoints must always send all editable fields on update (not just changed ones) | Server's partial-update semantics treat an omitted field as "keep" and an explicit `null` as "clear" — conditional-send silently failed to clear optional fields (03-04 CR-02 gap) | ✓ Good — Phase 3, applies to any future PUT/PATCH with optional clearable fields |
| Extend `publicapi.yml` with `POST .../setlist/{setlistId}/tracks` (bulk add) and `GET /api/setlist/list` (cross-band, `bandId`-filterable) for SETL-06/SETL-10 | No bulk-add endpoint existed (only single-track add); no endpoint returned setlists across all of a user's bands, mirroring Phase 3's TRACK-06 gap | ✓ Good — Phase 4 |

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
*Last updated: 2026-08-17 — Phase 5 complete*
