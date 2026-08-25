# Feature Research: i18n Localization & Duration Input

**Domain:** Flutter mobile app localization and specialized input controls  
**Researched:** 2026-08-25  
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Users in Russian-speaking regions expect English/Russian language switching; musicians expect intuitive duration entry (mm:ss format, not raw seconds).

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Language switching in settings** | Users expect app language to match device locale or offer manual override | LOW | Standard UI pattern: radio buttons or dropdown in Settings/Profile; live switch without restart is baseline expectation |
| **All UI strings localized EN/RU** | Hardcoded strings break UX in non-English regions | MEDIUM | Requires comprehensive string extraction and translation; error messages from API must also localize |
| **Persistent language preference** | User shouldn't need to re-select language on every app restart | LOW | Store in local key-value store (same layer as theme preference); no API sync needed (v1 scope) |
| **mm:ss duration input on tracks** | Musicians universally think in minutes:seconds, not raw seconds; entering "120" when they mean "2:00" is error-prone | MEDIUM | Input validation, parsing to/from API integer field, display formatting; conversion logic is purely client-side |
| **mm:ss duration display across all screens** | Consistency: if track duration shows "2:00", all summary/list views must show the same format | LOW | Apply formatting at display layer; API contract unchanged (`durationSeconds` int) |
| **Known API error codes map to localized messages** | Default server error text ("validation_error", "band_not_found") should surface in user's chosen language | MEDIUM | Maintain error code → localized message map; unmapped errors fall back to raw server text (safe default) |

### Differentiators (Competitive Advantage)

These set Cadence apart from basic band-management apps:

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Live language switch with animated transitions** | Smooth locale change without reload feels polished; competitors often require restart | MEDIUM | Use Flutter's `Localizations` rebuilt trigger to animate locale changes; requires a StateNotifier or Riverpod provider holding locale |
| **Placeholder text in mm:ss format** | Hints like "2:30" in duration input guide users on expected format | LOW | Clarifies expected input format without extra explanation |
| **Duration input with separator hints** | Auto-format as user types (e.g., "2" → "2:", "230" → "2:30") improves UX | MEDIUM | Requires custom text formatter and cursor handling; high polish but adds complexity |
| **Plural/gender forms in localized strings** | Russian has complex pluralization (1 track, 2–4 tracks, 5+ tracks); proper forms feel native | HIGH | Use `intl` package's plural/gender support; requires translator to provide plural forms upfront |
| **Fast language toggle in app bar** | Quick language switch without opening Profile (e.g., EN/РУ button in header) | MEDIUM | Adds new UI surface; risks clutter if not carefully placed; Profile-only toggle is safer v1 |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Server-side language preference sync** | "Cloud sync all settings like web apps do" | Out of scope for v1; adds API round-trip on app start, complicates logout/re-login flow, and requires new endpoint | Local-only persistence is sufficient (musicians don't switch devices mid-rehearsal); defer to v2 |
| **Offline language pack downloads** | "Support language switching without network" | Offline packs add app size (~100–200 KB per language), background download complexity, and versioning headaches (packs diverge from app) | v1 ships strings baked into binary; network-free languages are future work |
| **Date/time format localization** | "Respect locale date conventions" | No dates in v1 UI (band/track/setlist screens show no timestamps); premature scope creep | Defer until dates surface in future phases (e.g., gig history, event calendar) |
| **Duration in hours:minutes format** | "Support longer rehearsals (>1 hour)" | API spec caps track duration reasonably (e.g., "session" setlists run ~2–3 hours); hour format adds input complexity for no current benefit | mm:ss format sufficient; if/when 60+ min tracks appear, upgrade to HH:mm:ss at that time |
| **Auto-detect device locale on first launch** | "Respect system language preference" | Device locale ≠ user preference (bilingual devices, traveling bands); auto-detect often wrong and requires manual override anyway | English default is safe (universal); user can choose RU in Profile on first run (one-time cost) |

## Feature Dependencies

```
[Language Switching (Live)]
    ├──requires──> [String Extraction & Translation (EN/RU)]
    │                  └──requires──> [Profile Settings UI]
    │
    └──enhances──> [Error Code Localization]
                       └──depends on──> [API Exception Model + Known Code Map]

[mm:ss Duration Input]
    ├──requires──> [Duration Formatter (seconds ↔ mm:ss)]
    │
    ├──enhances──> [Track Create/Edit Forms]
    │
    └──conflicts with──> [Raw Seconds Display in Lists]
                             (both cannot coexist; must standardize on mm:ss everywhere)

[Persistent Language Preference]
    └──requires──> [Local Storage Layer] (already exists for theme)
```

### Dependency Notes

- **Language Switching requires String Extraction & Translation:** Every hardcoded string must move into a `.arb` (Application Resource Bundle) JSON file per language; Flutter's `intl` package generates type-safe `AppLocalizations` class from these.
- **String Extraction requires Profile Settings UI:** Profile screen must gain a language radio-button or dropdown; tapping it updates Riverpod locale provider, which triggers `Localizations` widget rebuild.
- **Language Switch enhances Error Code Localization:** Known API error codes (e.g., "band_not_found", "already_exists") map to localized strings; unmapped codes display raw server text as fallback.
- **mm:ss Duration Input requires Duration Formatter:** Reusable `formatDurationSeconds(int)` → `"mm:ss"` and `parseDurationString(String)` → `int` utility functions.
- **Duration Input enhances Track Forms:** Track create/edit dialogs and setlist track pickers must use mm:ss input instead of raw seconds.
- **Duration Input conflicts with Raw Seconds Display:** If some screens show "120" and others show "2:00", users are confused; all lists/details must converge on mm:ss format.
- **Persistent Language Preference reuses Local Storage:** Profile/theme persistence already exists; locale preference uses the same pattern.

## MVP Definition

### Launch With (v1.2)

Minimum viable product for this milestone — what validates the localization and duration features.

- [ ] **Language switcher in Profile settings** — Radio buttons (EN/RU) or dropdown in `/profile` screen; selection immediately rebuilds UI with new locale
- [ ] **All hardcoded UI strings extracted to ARB files (EN/RU)** — String resources for screens, dialogs, error messages, button labels, and validation feedback; validated via `flutter gen-l10n`
- [ ] **Known API error codes mapped to localized messages** — Map for common errors: 400 `already_exists`, 403 `unauthorized`, 409 `conflict`; fallback to raw server text for unmapped
- [ ] **Track duration input as mm:ss in create/edit forms** — Input field accepts "2:30" (or "230"), parses to `durationSeconds: 150`, sends to API unchanged
- [ ] **Track duration display as mm:ss across all screens** — Lists, detail views, setlist pickers all show "2:30" instead of "150"
- [ ] **Language preference persisted locally** — Stored in theme/config storage layer; restored on app restart (no API round-trip)

### Add After Validation (v1.x)

Features to add once core localization works and usage patterns are clear.

- [ ] **Plural forms for localized strings** — Russian grammar rules (1 track vs 2 tracks vs 5 tracks); requires `intl` plural helper and translator input
- [ ] **Auto-format mm:ss input with live separator hints** — "2" → "2:", "230" → "2:30" as user types; improves UX but adds input formatting complexity
- [ ] **In-app language toggle button (not just Profile settings)** — Quick EN/РУ switcher in app bar or drawer (lower priority; Profile toggle sufficient for v1)
- [ ] **Device locale auto-detect on first launch** — Check system language, suggest EN or RU; user can override in Profile immediately

### Future Consideration (v2+)

Features to defer until broader demand or product maturity.

- [ ] **Server-side language preference sync** — Cloud sync with user profile API; requires new `/api/me` field and auth flow changes
- [ ] **Offline language pack downloads** — Support language switching without network; adds binary size and background update complexity
- [ ] **Date/time localization** — Once gig timestamps, rehearsal schedules, or event history surface in UI
- [ ] **Duration in HH:mm:ss format** — Support tracks/setlists longer than 1 hour; defer until API or UX requests it

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Language switcher in Profile | HIGH | LOW | P1 |
| Hardcoded strings → EN/RU ARB files | HIGH | MEDIUM | P1 |
| Known API error codes → localized messages | HIGH | LOW | P1 |
| Track duration input mm:ss | HIGH | MEDIUM | P1 |
| Track duration display mm:ss | HIGH | LOW | P1 |
| Language preference persistence | HIGH | LOW | P1 |
| Plural forms for Russian grammar | MEDIUM | MEDIUM | P2 |
| Auto-format duration input | MEDIUM | MEDIUM | P2 |
| In-app language toggle button | MEDIUM | LOW | P2 |
| Device locale auto-detect | MEDIUM | LOW | P2 |
| Server-side language sync | LOW | HIGH | P3 |
| Offline language packs | LOW | HIGH | P3 |

**Priority key:**
- **P1:** Must have for v1.2 launch (validates core feature)
- **P2:** Should have; add if time/scope permits (polishes UX)
- **P3:** Nice to have; future releases (increases complexity for marginal gain)

## Competitor Feature Analysis

| Feature | Bandcamp Mobile | SetList.co | Cadence Approach |
|---------|-----------------|-----------|------------------|
| **Language switching** | English, limited locales | English-only | EN/RU via ARB; live switch, no restart |
| **Duration format** | Raw minutes as decimal (1.5 hrs) | mm:ss in UI, internal storage | mm:ss everywhere; API unchanged (clean layering) |
| **Error message localization** | Device locale only | English only | User-selected language + fallback to raw text |
| **Settings persistence** | Server sync (cloud account) | Local storage | Local storage only (v1 scope) |
| **Pluralization support** | None (English optimized) | None | Potential (intl plural helpers; defer to v2) |

**Cadence's edge:** Live language switching without restart and mm:ss duration across all views (cleaner UX than decimal formats).

## Implementation Surface

### Candidate Patterns & Tools

**Localization (i18n):**
- **Use:** Flutter's built-in `intl` package (`intl: ^0.19.0`) + code generation (`flutter gen-l10n`)
- **Pattern:** ARB (Application Resource Bundle) JSON files → code-generated `AppLocalizations` class; Riverpod provider holds current locale, `ListenableBuilder` / `watch()` rebuilds on locale change
- **Reuse existing:** Profile screen (add radio buttons), theme storage layer (add locale key)
- **Avoid:** GetIt, Provider package (Riverpod is already the state manager)

**Duration Input:**
- **Use:** Custom `TextInputFormatter` for mm:ss format, or raw string parsing with validation
- **Pattern:** `parseDurationString("2:30")` → `150` (durationSeconds); `formatDurationSeconds(150)` → `"2:30"`; apply formatter/display logic consistently across create/edit/list views
- **Reuse existing:** Track form validation layer
- **Avoid:** Time picker (overkill for a simple duration field; mm:ss text input is faster)

**Error Code Localization:**
- **Use:** Map<String, String> of known error codes to localized strings; look up in current locale's ARB bundle
- **Pattern:** `ApiException` factory catches 4xx/5xx, extracts `code` field, looks up in error code map; if not found, returns raw message
- **Reuse existing:** `ApiException` class and error handling in screens

### Known Gaps & Risks

1. **ARB file maintenance:** Translating 20+ screens' strings requires upfront coordination with translator; missing translations will surface as runtime "key not found" errors
   - **Mitigation:** Code-gen validation (`flutter gen-l10n` catches missing keys); mark untranslated as "TODO" and fall back to English
2. **Duration parsing edge cases:** "2:70" (invalid seconds), "2" (ambiguous: 2 seconds or 2 minutes?), empty input
   - **Mitigation:** Clear validation, placeholder hints ("mm:ss"), and error feedback on invalid input
3. **Live locale switch consistency:** Navigating mid-locale-change (e.g., tapping language button while a dialog is open) can leave stale strings
   - **Mitigation:** Locale change via Riverpod triggers top-level `Localizations` rebuild; dialogs must re-render (any `showDialog` call after change will use new locale)
4. **Riverpod + intl integration:** Riverpod providers must watch the locale provider and rebuild when it changes
   - **Mitigation:** Locale provider is a simple `Riverpod` `StateNotifier`; any screen or dialog that builds localized widgets should `watch()` it

## Recommended Execution Path

1. **Phase 1: Locale infrastructure (low-risk setup)**
   - Create ARB template files (EN empty, RU to-translate)
   - Add locale `StateNotifierProvider` to Riverpod setup
   - Integrate `MaterialApp.localizationsDelegates` and `supportedLocales`
   - Add language radio buttons to Profile screen

2. **Phase 2: String extraction (high-effort, low-complexity)**
   - Move all hardcoded strings into ARB JSON
   - Code-gen `AppLocalizations` class
   - Wire screens to use generated strings (e.g., `AppLocalizations.of(context)!.trackTitle`)

3. **Phase 3: Duration formatting (parallel-safe)**
   - Write `formatDurationSeconds` and `parseDurationString` utilities with tests
   - Update Track create/edit forms to use mm:ss input
   - Update list/detail views to use mm:ss display

4. **Phase 4: Error code localization (integrate with Phase 2)**
   - Maintain known error code map in ARB or as Dart constant
   - Update `ApiException` factory to look up localized messages
   - Test with mock API errors

---

*Feature research for: Flutter i18n (EN/RU language switching) and duration (mm:ss) input*  
*Researched: 2026-08-25*
