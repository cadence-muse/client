# Requirements: Cadence

**Defined:** 2026-08-25
**Core Value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

## v1.2 Requirements

Requirements for the v1.2 milestone (i18n and duration input). Each maps to roadmap phases.

### Localization

- [ ] **I18N-01**: User can switch app language between English and Russian from Profile settings; English is the default
- [ ] **I18N-02**: Language switch applies live across the whole app with no restart required
- [ ] **I18N-03**: Selected language persists locally on-device across app restarts (no API/account sync)
- [x] **I18N-04**: All UI strings — labels, buttons, dialogs, validation messages — are localized in English and Russian
- [x] **I18N-05**: Known API error codes are mapped to localized messages in the user's selected language; unmapped codes fall back to the raw server text
- [x] **I18N-06**: Count-bearing localized strings (e.g. band member count, track count) use grammatically correct Russian plural forms (1 / 2–4 / 5+), not English-style pluralization

### Duration Input

- [x] **DUR-01**: User enters track duration as mm:ss in the create/edit track forms; input converts to `durationSeconds` at submit — the API field itself is unchanged
- [x] **DUR-02**: Duration input rejects invalid mm:ss values (seconds ≥ 60, negative values, malformed/incomplete text) with clear validation feedback
- [x] **DUR-03**: Track and setlist duration display uses one consistent mm:ss format across every screen (lists, detail views, setlist views) — replacing today's two divergent formats
- [x] **DUR-04**: Duration input auto-formats as the user types (e.g. typing "230" becomes "2:30") to reduce manual colon entry

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Server-side language preference sync | Would require a new `publicapi.yml` field — against the project's "no inventing API fields not in the contract" constraint; local persistence is sufficient |
| Offline language-pack downloads | Strings ship baked into the binary; no network-dependent localization needed at this scale |
| Device-locale auto-detection on first launch | User explicitly chose English-default over auto-detect — bilingual/traveling-band devices make auto-detect unreliable |
| Date/time localization | No dates surface in current UI (band/track/setlist screens show no timestamps) |
| HH:mm:ss duration format | No tracks longer than 1 hour in current data/UX; mm:ss is sufficient |
| In-app language toggle outside Profile (e.g. app-bar quick switch) | Profile-only toggle is sufficient for v1.2; avoids UI clutter |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| I18N-01 | Phase 12: Locale + i18n Infrastructure | Mapped |
| I18N-02 | Phase 12: Locale + i18n Infrastructure | Mapped |
| I18N-03 | Phase 12: Locale + i18n Infrastructure | Mapped |
| I18N-04 | Phase 13: String Extraction & Screen Localization | Complete |
| I18N-05 | Phase 14: API Error Localization | Complete |
| I18N-06 | Phase 13: String Extraction & Screen Localization | Complete |
| DUR-01 | Phase 11: Duration mm:ss Input + Display | Complete |
| DUR-02 | Phase 11: Duration mm:ss Input + Display | Complete |
| DUR-03 | Phase 11: Duration mm:ss Input + Display | Complete |
| DUR-04 | Phase 11: Duration mm:ss Input + Display | Complete |

**Coverage:**
- v1.2 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-08-25*
*Last updated: 2026-08-25 after v1.2 roadmap creation*
