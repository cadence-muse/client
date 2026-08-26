# Roadmap: Cadence

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-08-17)
- ✅ **v1.1 UI Improvements** — Phases 6-10 (shipped 2026-08-22)
- 🚧 **v1.2 i18n and Duration Input** — Phases 11-14 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-08-17</summary>

- [x] Phase 1: Foundation, Profile & Home (3/3 plans) — completed 2026-08-15
- [x] Phase 2: Bands (6/6 plans) — completed 2026-08-15
- [x] Phase 3: Tracks (4/4 plans) — completed 2026-08-16
- [x] Phase 4: Setlists (5/5 plans) — completed 2026-08-17
- [x] Phase 5: Offline Trust & Connectivity UX (5/5 plans) — completed 2026-08-17

Full detail: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v1.1 UI Improvements (Phases 6-10) — SHIPPED 2026-08-22</summary>

- [x] Phase 6: Foundation Info & Settings Polish (4/4 plans) — completed 2026-08-21
- [x] Phase 06.1: API contract catch-up (1/1 plans) — completed 2026-08-21
- [x] Phase 7: Cache Behavior Flip — Online-First (5/5 plans) — completed 2026-08-22
- [x] Phase 8: Band Owner Tools (1/1 plans) — completed 2026-08-21
- [x] Phase 9: Homepage Quick Actions (1/1 plans) — completed 2026-08-22
- [x] Phase 10: Searchable Setlist Track Picker (1/1 plans) — completed 2026-08-22

Full detail: `.planning/milestones/v1.1-ROADMAP.md`

</details>

### 🚧 v1.2 i18n and Duration Input (In Progress)

**Milestone Goal:** Users can switch the app's language between English and Russian, and enter track duration as minutes:seconds instead of raw seconds.

- [x] **Phase 11: Duration mm:ss Input + Display** - Track duration entered and shown as mm:ss everywhere, with typing auto-format and invalid-input rejection (completed 2026-08-25)
- [x] **Phase 12: Locale + i18n Infrastructure** - LocaleController, ARB/gen-l10n pipeline, and a live no-restart Profile-screen language switch persisted on-device (completed 2026-08-25)
- [x] **Phase 13: String Extraction & Screen Localization** - Every UI string localized EN/RU across all screens, with grammatically correct Russian pluralization for counts (completed 2026-08-26)
- [ ] **Phase 14: API Error Localization** - Known API error codes map to localized messages; unmapped codes fall back to raw server text

## Phase Details

### Phase 1: Foundation, Profile & Home

**Goal**: Users can view their profile and homepage summary, on an app now running on Riverpod state management with a working local cache layer.
**Plans**: 3 plans (complete)

### Phase 2: Bands

**Goal**: Users can create, view, edit, delete, and join bands, with membership management.
**Plans**: 6 plans (complete)

### Phase 3: Tracks

**Goal**: Users can manage a band's song catalog with full CRUD, plus a cross-band filterable view.
**Plans**: 4 plans (complete)

### Phase 4: Setlists

**Goal**: Users can manage setlists per band — CRUD, track add/remove/reorder, and a cross-band filterable view.
**Plans**: 5 plans (complete)

### Phase 5: Offline Trust & Connectivity UX

**Goal**: Every cached screen shows consistent staleness/connectivity signals with mutations gated while offline.
**Plans**: 5 plans (complete)

Full detail for Phases 1-5: `.planning/milestones/v1.0-ROADMAP.md`

---

### Phase 6: Foundation Info & Settings Polish

**Goal**: Users can change their account password and see richer, at-a-glance info (member count/role, key metadata icons) on Bands/Track/Setlist screens.
**Plans**: 4 plans (complete)

### Phase 06.1: API contract catch-up

**Goal**: `public_api.dart`'s `removeSetlistTrack`, `listUserTracks`, and `listUserSetlists` methods match the current `publicapi.yml` wire contract.
**Plans**: 1 plan (complete)

### Phase 7: Cache Behavior Flip — Online-First

**Goal**: Users always see the freshest server data when online, and get an honest, simple signal when viewing cached data offline.
**Plans**: 5 plans (complete)

### Phase 8: Band Owner Tools

**Goal**: A band owner can manage the band's invite code and hand off ownership to another member.
**Plans**: 1 plan (complete)

### Phase 9: Homepage Quick Actions

**Goal**: Users can jump straight from the Homepage into creating a band, song, or setlist without extra navigation.
**Plans**: 1 plan (complete)

### Phase 10: Searchable Setlist Track Picker

**Goal**: Users can quickly find and add the right track to a setlist even when the band has many tracks.
**Plans**: 1 plan (complete)

Full detail for Phases 6-10: `.planning/milestones/v1.1-ROADMAP.md`

---

### Phase 11: Duration mm:ss Input + Display

**Goal**: Users enter and view track duration as mm:ss everywhere in the app — create/edit forms auto-format and validate as the user types, and every screen that displays duration (track and setlist, list and detail) uses one consistent mm:ss format. The `durationSeconds` API field itself is unchanged; conversion happens only at the input/display boundary.
**Depends on**: Nothing (independent of Phase 12's i18n work; sequenced first per user request)
**Requirements**: DUR-01, DUR-02, DUR-03, DUR-04
**Success Criteria** (what must be TRUE):

  1. On the create/edit track form, typing digits (e.g. "230") auto-formats into mm:ss shape (e.g. "2:30") as the user types, without requiring manual colon entry.
  2. Submitting a valid mm:ss duration saves correctly, converting to the right `durationSeconds` integer on the wire with the API contract unchanged.
  3. Entering an invalid duration (seconds ≥ 60, negative values, malformed/incomplete text like "2:") shows clear validation feedback and blocks submission.
  4. Every screen showing track or setlist duration (lists, detail views, setlist views) displays the same mm:ss format — the previous two divergent formats (`mm:ss` vs. words-based `"42m 35s"`) no longer both exist.

**Plans**: 2/2 plans executed

Plans:

- [x] 11-01-PLAN.md — Duration mm:ss input auto-format, validation, and parsing (create/edit track forms)
- [x] 11-02-PLAN.md — Unify track/setlist duration display to mm:ss format

### Phase 12: Locale + i18n Infrastructure

**Goal**: Users can switch the app's language between English and Russian from Profile settings, the switch applies live with no restart, and the selection persists locally across restarts — establishing the ARB/gen-l10n pipeline and locale-propagation pattern every later i18n phase builds on.
**Depends on**: Nothing new — independent of Phase 11's duration work
**Requirements**: I18N-01, I18N-02, I18N-03
**Success Criteria** (what must be TRUE):

  1. Profile settings shows a Language section with English and Russian options.
  2. Selecting a different language updates visible localized text immediately, with no app restart.
  3. A fresh install (no prior selection) defaults to English.
  4. After choosing Russian and fully closing/reopening the app, the app reopens in Russian — the selection persisted locally, with no API/account round-trip.
  5. A screen kept alive in the background (an `IndexedStack` bottom-nav tab not visible when the language was switched) shows the new language once navigated to, not stale text from before the switch.

**Plans**: 1/1 plans executed

Plans:

- [x] 12-01-PLAN.md — ARB/gen-l10n pipeline + LocaleController + live Settings-screen language switch, wired end-to-end

### Phase 13: String Extraction & Screen Localization

**Goal**: Every hardcoded UI string across the app's 20+ screens/dialogs — labels, buttons, dialogs, validation messages, and count-bearing strings — is replaced with localized EN/RU lookups, with grammatically correct Russian pluralization for counts.
**Depends on**: Phase 12 (needs `LocaleController`, the ARB/gen-l10n pipeline, the proven "watch locale" propagation pattern, and the centralized test-strings utility already in place)
**Requirements**: I18N-04, I18N-06
**Success Criteria** (what must be TRUE):

  1. Switching to Russian replaces every visible label, button, dialog, and validation message across Home, Songs/Tracks, Bands, Setlists, and Profile with Russian text — no screen retains hardcoded English.
  2. Count-bearing strings (e.g. band member count, track count) show grammatically correct Russian plural forms — 1 / 2–4 / 5+ — not a single English-style plural suffix applied to Russian.
  3. The existing automated test suite passes by asserting against a centralized test-strings utility rather than hardcoded English literals in `find.text(...)` calls.
  4. An `IndexedStack` tab that wasn't visible at the moment of a language switch still renders fully localized text once the user navigates to it.

**Plans**: 13/13 plans executed

Plans:
**Wave 1**

- [x] 13-01-PLAN.md — ARB pipeline tracer (Bands tab + Band Detail) + complete phase-wide ARB key batch

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 13-02-PLAN.md — Band simple confirm dialogs (delete/leave/remove member)
- [x] 13-03-PLAN.md — Band privileged confirm dialogs (rotate invite code, transfer ownership)
- [x] 13-04-PLAN.md — Band CRUD + join dialog (create/edit band, join with code)
- [x] 13-05-PLAN.md — Home tab + band picker sheet + locale_live_switch_test strengthening
- [x] 13-06-PLAN.md — Profile tab + change password screen
- [x] 13-07-PLAN.md — Bottom nav labels + offline banner + offline_cross_tab_test
- [x] 13-08-PLAN.md — Offline empty-state widget + login screen
- [x] 13-09-PLAN.md — Setlist track-cap consolidation + detail screen + global Setlists tab + create-setlist + add-tracks dialog
- [x] 13-10-PLAN.md — Edit setlist + delete-setlist dialog + per-band setlist list
- [x] 13-11-PLAN.md — Per-band track list, detail screen, delete-track dialog
- [x] 13-12-PLAN.md — Create/edit track forms + global Tracks tab

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 13-13-PLAN.md — Cross-cutting smoke test (widget_test.dart) migration

### Phase 14: API Error Localization

**Goal**: Known API error codes surface as localized messages in the user's selected language; any error code the client doesn't recognize still shows the server's raw text instead of breaking or going silent.
**Depends on**: Phase 12 (ARB/locale infrastructure); benefits from Phase 13's established localization conventions but has no hard code dependency on it, so it is sequenced last as the smallest, most isolated surface (catch blocks only)
**Requirements**: I18N-05
**Success Criteria** (what must be TRUE):

  1. A known API error code (e.g. `already_exists`, `unauthorized`) shown to the user is displayed as a localized message matching the currently selected language.
  2. An API error code absent from the client's mapping falls back to the server's raw error text rather than a blank state or generic failure message.
  3. Switching the app's language changes the language of error messages shown afterward, with no restart required.

**Plans**: 0/4 plans executed

Plans:
**Wave 1**

- [ ] 14-01-PLAN.md — ApiException localization extension + ARB keys + CreateBandScreen wiring (tracer)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 14-02-PLAN.md — Bands: remaining 7 catch sites
- [ ] 14-03-PLAN.md — Tracks: remaining 3 catch sites + login/change-password override refactor (D-04)
- [ ] 14-04-PLAN.md — Setlists: remaining 5 catch sites

## Progress

**Execution Order:**
Phases execute in numeric order: 11 → 12 → 13 → 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|-----------------|--------|-----------|
| 1. Foundation, Profile & Home | v1.0 | 3/3 | Complete | 2026-08-15 |
| 2. Bands | v1.0 | 6/6 | Complete | 2026-08-15 |
| 3. Tracks | v1.0 | 4/4 | Complete | 2026-08-16 |
| 4. Setlists | v1.0 | 5/5 | Complete | 2026-08-17 |
| 5. Offline Trust & Connectivity UX | v1.0 | 5/5 | Complete | 2026-08-17 |
| 6. Foundation Info & Settings Polish | v1.1 | 4/4 | Complete | 2026-08-21 |
| 06.1. API contract catch-up | v1.1 | 1/1 | Complete | 2026-08-21 |
| 7. Cache Behavior Flip — Online-First | v1.1 | 5/5 | Complete | 2026-08-22 |
| 8. Band Owner Tools | v1.1 | 1/1 | Complete | 2026-08-21 |
| 9. Homepage Quick Actions | v1.1 | 1/1 | Complete | 2026-08-22 |
| 10. Searchable Setlist Track Picker | v1.1 | 1/1 | Complete | 2026-08-22 |
| 11. Duration mm:ss Input + Display | v1.2 | 2/2 | Complete    | 2026-08-25 |
| 12. Locale + i18n Infrastructure | v1.2 | 1/1 | Complete    | 2026-08-25 |
| 13. String Extraction & Screen Localization | v1.2 | 13/13 | Complete    | 2026-08-26 |
| 14. API Error Localization | v1.2 | 0/? | Not started | — |
