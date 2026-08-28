# Requirements: Cadence

**Defined:** 2026-08-27
**Core Value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## v1.3 Requirements

Requirements for the "Quality of Life" milestone. Each maps to roadmap phases.

### Band Management

- [x] **BAND-13**: Invite-code copy button works offline (clipboard copy needs no network); fixes WR-01 regression from v1.1 Phase 8 where the button was incorrectly gated behind `isOnline`

### Quality Assurance

- [x] **QA-01**: Stale gaps in `02-VERIFICATION.md` (Hive deep-convert, mutation error handling, band-rename list propagation, background-refresh version guard) are re-verified against current code and re-stamped resolved

### API Contract Sync

- [x] **API-01**: `ListUserTracks`/`ListUserSetlists` migrate from POST+body to GET+`SearchQuery` query param, and the setlist track picker's `searchQuery` field adopts the shared `SearchQuery` `$ref`, replacing offline substring filtering with real server-side search
- [x] **API-02**: Registration and password-change forms enforce a client-side 8-character minimum password length, matching the updated `publicapi.yml` schema

### Track Terminology

- [x] **RENAME-01**: No user-facing or internal "song" references remain; renamed to "track" throughout (bottom-nav tab label, `lib/features/songs/` directory, `SongsScreen` class, ARB keys/translations)

### Setlists

- [x] **SETL-13**: Setlist date field uses the platform's native `showDatePicker` instead of raw text input

### Metronome

- [x] **METR-01**: User can open a metronome tool from a new Homepage "Tools" section, defaulting to 120 BPM
- [x] **METR-02**: User can open the metronome from a track's detail screen, prefilled with that track's `tempo`
- [x] **METR-03**: Metronome plays an audio tick synced to a visual pulse, in 4/4 time only, with an accented first beat
- [x] **METR-04**: User can adjust tempo via a large round selector plus ±1/±5 quick-adjust buttons

## v2 Requirements

None deferred this milestone — all discussed items are in v1.3 scope.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Metronome tap-tempo | Not requested; deferred per research (FEATURES.md) as a v2+ differentiator |
| Metronome background audio (continues when app backgrounded) | Not requested; requires platform-specific lifecycle work, deferred per research |
| Metronome time signatures other than 4/4 | Explicitly out of scope per user — "only supports 4/4 time signature for now" |
| Custom calendar popover for setlist dates | Native `showDatePicker` chosen instead — less custom code, consistent with platform conventions |
| Backend `searchQuery` fuzzy/soundex matching | Client sends plain substring text; matching strategy is a backend concern (carried from v1.1) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BAND-13 | Phase 15 | Complete |
| QA-01 | Phase 15 | Complete |
| SETL-13 | Phase 15 | Complete |
| RENAME-01 | Phase 16 | Complete |
| API-01 | Phase 17 | Complete |
| API-02 | Phase 17 | Complete |
| METR-01 | Phase 18 | Complete |
| METR-02 | Phase 18 | Complete |
| METR-03 | Phase 18 | Complete |
| METR-04 | Phase 18 | Complete |

**Coverage:**

- v1.3 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-27*
*Last updated: 2026-08-27 after roadmap creation (Phases 15-18)*
