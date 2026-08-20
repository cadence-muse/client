# Project Research Summary: Cadence v1.1 UI Improvements

**Project:** Cadence (Flutter mobile app for band repertoire management)  
**Milestone:** v1.1 UI Improvements  
**Researched:** 2026-08-20  
**Confidence:** HIGH (all recommendations grounded in v1.0 production validation, schema finalization)

---

## Executive Summary

Cadence v1.1 is a 7-feature UI improvement milestone that flips the app from cache-first to online-first offline support, removes owner-only permission gates (schema now allows any member to edit/delete), adds owner-exclusive admin tools (rotate invite code, transfer ownership), and polishes UX with search and metadata icons. The recommended tech stack requires **zero new dependencies**—all features integrate cleanly with Cadence's proven Riverpod + Hive foundation, already shipping in v1.0. The primary risk is the cache-behavior flip (high-touch, affects all 10 data providers), which must be implemented carefully to avoid in-flight mutations being silently overwritten by background fetches. Recommended phase order prioritizes the cache flip first (foundational for all screens), then role/permission gating (enables owner tools), then polish features, completing in ~9–11 developer-days with rigorous testing of offline scenarios.

---

## Key Findings

### Recommended Stack

**Summary:** The v1.0 production stack is fully equipped for v1.1 features. No package additions or version upgrades are needed.

**Core technologies (unchanged from v1.0, production-validated):**
- **Flutter 3.12.2+ / Dart 3.12.2+** – Mobile framework with 284 passing tests, zero analysis violations
- **flutter_riverpod 2.6.1** – State management; AsyncNotifier pattern proven end-to-end for cache + mutations
- **hive 2.2.3 + hive_flutter 1.1.0** – Local key-value store with 5 cache boxes; {data, syncedAt} envelope supports offline fallback + v1.2 smart sync
- **connectivity_plus 7.3.1** – Online/offline detection; powers isOnlineProvider used by all v1.1 providers
- **http 1.6.0** – REST client; ApiClient wraps this with auth header attachment + 403 auto-logout
- **flutter_secure_storage 11.0.0** – Token persistence across restarts
- **Material Icons (built-in)** – 4264+ icons cover all v1.1 metadata labels; no font_awesome or extra icon package needed
- **flutter_lints 6.0.0** – Analysis passes; zero violations

**Implementation highlights:**
- Password change: Add POST endpoint to PublicApi, reuse ApiException error handling, TextField + validation (built-in)
- Cache flip: Conditional routing in AsyncNotifier build() based on isOnlineProvider; no schema changes needed
- Owner tools: New POST endpoints (rotate-invite-code, transfer-ownership), multi-step confirmation dialogs, password confirmation (Material showDialog)
- Search picker: Riverpod's native debounce via ref.onDispose() + Future.delayed(); no throttle_debounce package needed
- Member display + icons: Read-only display from schema fields; pure UI work

---

### Expected Features

**Summary:** 7 features organized by priority and dependency. Total scope: ~1,500–2,250 LOC, ~9–11 developer-days (one dev, full testing).

**Table stakes (users expect these):**
1. **Change Password Form** – Current password, new password, confirm fields; success toast + error feedback
2. **Band Member Count + Role Display** – Show "3 members" in list items; badge for Owner/Member role
3. **Remove Owner-Only UI Gates** – Edit/delete buttons now visible to all members (schema permits)
4. **Cache Behavior Flip: Online-First** – Online always fetches fresh; offline serves cache + warning banner
5. **Icons for Metadata** – Material icons for duration, musical key, notes, location on track/setlist screens

**Differentiators (competitive advantage):**
6. **Owner Tools** – Rotate invite code + transfer ownership with multi-step confirmation + password verification
7. **Setlist Track Picker with Search** – Replace flat-list dialog with searchable modal; search-as-you-type (debounce 300ms)

**Complexity by feature:**
- #1, #2, #5, #6: LOW (1 day each, 100–200 LOC)
- #3: LOW (50–100 LOC, remove conditionals)
- #4, #7: MEDIUM (2–3 days each, 300–500 LOC, higher testing burden)

---

### Architecture Approach

**Summary:** v1.1 integrates cleanly with the existing Riverpod + Hive foundation. No infrastructure rewrites needed; changes are localized to provider logic and UI widgets.

**Major architectural shifts:**

1. **Cache-First → Online-First Pattern** – All 10 data providers change from "return cache immediately + refresh in background" to "check isOnlineProvider in build(); if online, fetch fresh; if offline, serve cache or throw OfflineNoCacheException." The `_version` guard remains for user-initiated refresh() to prevent concurrent background refreshes from clobbering mutations.

2. **{data, syncedAt} Envelope Persists** – Hive schema unchanged; SyncStatusBadge widget removed (which aged timestamps every minute). New OfflineFallbackBanner shows only when offline AND cache exists, displaying static "Last synced Xm/h ago" text (no timer).

3. **Dual-Gate Permission Pattern** – Replace tri-state ownership check with two separate helpers:
   - `_isMemberResolved(profileAsync)` → boolean, gates all-member edit/delete
   - `_isOwnerFromMembers(profileAsync, band)` → tri-state, gates owner-only tools

4. **searchQuery Optional Param** – PublicApi.listBandTracks(bandId, {searchQuery}) backward-compatible; v1.1 uses local filtering.

**Components added:**
- OfflineFallbackBanner (replaces SyncStatusBadge)
- SetlistTrackPickerScreen (searchable modal)
- ChangePasswordScreen, RotateInviteCodeDialog, TransferOwnershipDialog

**Components removed:**
- SyncStatusBadge widget (10 call-sites)
- _refresh() method (background silent refresh)
- Tri-state _isOwner() pattern (replaced with dual-gate)

---

### Critical Pitfalls

**Top pitfalls requiring prevention:**

1. **Pitfall 10: In-Flight Fetch Overwrites Local Mutation** – When flipping to online-first, if a user mutation completes while a background fetch is in-flight, stale data can overwrite the edit. Prevention: Implement `_inFlightMutation` guard or bump `_version` synchronously before any await. **Test mutation + refresh race explicitly.**

2. **Pitfall 11: Ownership Gate Removal Without Full Audit** – Removing UI gates without updating cache invalidation means non-owner mutations succeed on server but don't refresh global lists. Prevention: Audit all mutation endpoints, expand invalidation to always invalidate global lists, add non-owner mutation tests.

3. **Pitfall 12: Transfer Ownership Without Invalidating Profile** – Transferring ownership updates band cache but not ProfileData. Prevention: Always invalidate profileDataProvider after ownership mutations. **Test: transfer ownership → attempt owner-only action → server rejects with 403.**

4. **Pitfall 4 (v1.0): Mutations Don't Invalidate Cache** – User edits track online, cache still has old title, offline view shows stale data. Prevention: Every successful mutation updates or invalidates cache as part of the same repository method. **Test: edit online → go offline → verify edit is visible.**

5. **Pitfall 2 (v1.0): Cache Not Scoped Per User/Band** – User logs out, another logs in, previous user's cached bands still visible. Prevention: Include bandId in cache keys, call clearAll() during signOut(). **Test: log out → log in as different user → previously cached data not visible.**

---

## Implications for Roadmap

Suggested phase structure (roadmapper will refine during planning):

### Phase 1: Foundation Features

**Rationale:** Low-risk features de-risk while planning cache-flip logic.

**Delivers:** Password form, member count + role display, metadata icons

**Scope:** Features #1, #2, #6 from FEATURES.md

**Duration:** 1–2 days

**Research need:** Standard patterns; skip research-phase

---

### Phase 2: Permission Gating Refactor

**Rationale:** Prerequisite for cache flip and owner tools.

**Delivers:** Edit/delete buttons visible to all members; dual-gate helpers established

**Scope:** Feature #3 from FEATURES.md; foundation for #4

**Addresses pitfalls:** #11 (full audit), #7 (auth consistency)

**Duration:** 1–1.5 days

**Research need:** Code review for all gating removals

---

### Phase 3: Cache-Behavior Flip (Online-First)

**Rationale:** Foundational for v1.1's core value; affects all 10 data providers.

**Delivers:** Online-first fetching, offline-fallback banner, elimination of background-refresh race

**Scope:** Feature #5 from FEATURES.md

**Addresses pitfalls:** #10 (mutation race), #3 (stale data UX), #14 (invalidation), #15 (consistency)

**Duration:** 3–5 days (2 implementation + 2–3 testing)

**Research need:** **HIGH-PRIORITY research-phase** — offline testing strategy, feature-flag rollout, banner accessibility

---

### Phase 4: Ownership Mutations (Owner Tools)

**Rationale:** High-value admin features; depends on Phase 2 gating refactor.

**Delivers:** Rotate invite code, transfer ownership with multi-step dialogs + password confirmation

**Scope:** Feature #4 from FEATURES.md

**Addresses pitfalls:** #12 (profile invalidation), #16 (member list refresh), #17 (family invalidation)

**Duration:** 2–3 days

**Research need:** Confirm API contract for password field, UX validation for multi-step flow

---

### Phase 5: Searchable Track Picker

**Rationale:** High-UX value; independent, low-touch; ship after foundational work.

**Delivers:** Full-screen searchable modal, search-as-you-type (300ms debounce), local filtering

**Scope:** Feature #7 from FEATURES.md

**Addresses pitfalls:** #13 (unimplemented backend field, graceful degradation), #6 (autoDispose)

**Duration:** 1–2 days

**Research need:** Confirmed debounce pattern in v1.0; skip research-phase

---

### Phase Ordering Rationale

- Phase 1 first: Low-risk, builds confidence
- Phase 2 before Phase 3: Gating refactor influences cache invalidation strategy
- Phase 3 mid-timeline: Highest-risk; implement when team warmed up
- Phase 4 after Phase 3: Owner tools depend on correct gating + invalidation
- Phase 5 last: Independent; ship after other features stable

**Critical dependencies:**
- Phase 2 → Phase 3 (gating logic influences invalidation)
- Phase 3 → Phase 4 (ownership mutations rely on cache invalidation)
- Phase 1, 5 independent; can overlap

---

## Research Flags

**Phases requiring deeper research during planning:**

- **Phase 3 (Cache Flip):** HIGH-risk architectural change. Recommend `/gsd-plan-phase --research-phase 3` for:
  - _version guard interaction modeling
  - Offline banner accessibility (WCAG AA contrast)
  - Feature-flag rollout strategy
  - Real device offline testing (Android/iOS, not just simulator)

- **Phase 4 (Owner Tools):** Recommend `/gsd-plan-phase --research-phase 4` for:
  - API contract verification (password field, error codes)
  - Multi-step dialog UX validation (Slack pattern for high-stakes ops)
  - Permission flip testing (transfer, then immediate next action)

**Phases with standard patterns (skip research-phase):**

- **Phase 1:** Password forms, badges, icons are standard Flutter patterns
- **Phase 2:** Conditional rendering, dual-gate pattern documented in ARCHITECTURE.md
- **Phase 5:** Debounce pattern already in v1.0 codebase (ref.onDispose())

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | HIGH | All technologies in v1.0 production; zero new packages; versions stable |
| **Features** | HIGH | Schema finalized (fe72e78); scope clear; estimates grounded in codebase |
| **Architecture** | HIGH | Patterns leverage existing Riverpod + Hive; no rewrites; localized changes |
| **Pitfalls** | MEDIUM–HIGH | Critical pitfalls documented with prevention strategies; recovery costs understood |

**Overall: HIGH confidence**

### Gaps to Address During Implementation

1. **Offline banner placement** – Decide during Phase 3: global in RootScaffold vs. per-screen
2. **Profile invalidation scope** – Confirm GET /api/me returns ownership metadata during Phase 4
3. **Backend searchQuery timeline** – Clarify v1.2 backend support; implement graceful degradation in Phase 5
4. **Web build handling** – Scope web for v1.1 (defer? stub cache?); affects Phase 3 testing
5. **Password confirmation UX** – Validate Slack-style password entry acceptable friction during Phase 4

---

## Sources

**Research files (primary):**
- `.planning/research/STACK.md` – Technology stack, no new dependencies
- `.planning/research/FEATURES.md` – 7 features, complexity, screen mapping
- `.planning/research/ARCHITECTURE.md` – Online-first flip, dual-gate pattern, searchQuery integration
- `.planning/research/PITFALLS.md` – 17 pitfalls with prevention/recovery strategies

**Official sources:**
- [Riverpod Debouncing](https://riverpod.dev/docs/how_to/cancel) – ref.onDispose() pattern
- [Flutter Material Icons](https://api.flutter.dev/flutter/material/Icons-class.html) – 4264+ icons
- [Riverpod 3.0 Migration](https://riverpod.dev/docs/3.0_migration) – AsyncNotifier, provider lifecycle

**Codebase (PRIMARY, HIGH confidence):**
- v1.0: 284 tests passing, zero analysis violations
- Providers: ProfileData, BandsListData, BandDetailData, TracksData, SetlistsData
- Cache: lib/cache/cache_service.dart (Hive {data, syncedAt})
- API: lib/api/public_api.dart, lib/api/api_client.dart (auth, 403 logout, error handling)

---

**Researched:** 2026-08-20  
**Ready for roadmap:** YES

Next step: `/gsd-plan-phase --research-phase 3` (cache flip, highest-risk work)
