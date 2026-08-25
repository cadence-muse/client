# Project Research Summary

**Project:** Cadence (Flutter mobile app for band repertoire management)
**Domain:** Flutter app i18n (EN/RU) + specialized numeric text input (mm:ss duration)
**Researched:** 2026-08-25
**Confidence:** HIGH

## Executive Summary

This is a brownfield localization + input-formatting milestone on a mature, well-tested Flutter app (~24,800 LOC, 401 passing tests, zero i18n today). Two independent features: (1) full EN/RU UI localization with a live, no-restart language switch persisted locally, and known API error codes mapped to localized text with a raw-text fallback; (2) a client-side mm:ss duration input/display for tracks, with the `durationSeconds` int API field completely unchanged.

The recommended approach reuses established patterns rather than introducing new architecture: a `LocaleController` Riverpod provider that mirrors the existing `ThemeController` (ValueNotifier-based settings toggle, already wired into the Profile screen) provides the locale-switch mechanism, Flutter's built-in `gen-l10n` codegen (triggered by `generate: true` in `pubspec.yaml`, requiring only the official `intl` + `flutter_localizations` packages — zero third-party i18n dependency) provides type-safe string lookup, and a small custom `TextInputFormatter` (no external package) handles mm:ss input parsing without touching the duration display extension that already exists.

The main risk is scale, not novelty: ~20+ screens/dialogs carry hardcoded English strings, and the existing 401-test suite widely asserts against those literal English strings — both research and pitfalls agree this string-extraction sweep plus test-string centralization is the highest-effort, highest-regression-risk part of the milestone, not the mm:ss formatter (which is a small, self-contained utility). Locale-change propagation to already-built (`IndexedStack`-kept-alive) tabs is the other cross-cutting risk that needs an explicit pattern established early rather than discovered late.

## Key Findings

### Recommended Stack

Zero third-party i18n dependency: Flutter's official `intl` package plus SDK-bundled `flutter_localizations`, driven by ARB (JSON) translation files and the built-in `gen-l10n` codegen (`generate: true` in `pubspec.yaml`). Locale state and duration formatting reuse the app's existing Riverpod + Hive stack — no new state-management or persistence library.

**Core technologies:**
- `intl` (0.19.0+): message translation/plural/locale support — official Dart package, works with Riverpod, supports plain ARB files with no extra codegen tool
- `flutter_localizations` (Flutter SDK): Material/Cupertino widget localization — required for `MaterialApp.locale` switching
- `riverpod` (existing, 2.6.1): new `LocaleController` provider mirrors the existing `ThemeController` pattern exactly — live switch, no restart
- `hive` (existing, 2.2.3): persists the selected locale locally, alongside theme mode — no API/account sync (matches the "local device only" scope decision)
- Custom `TextInputFormatter` (no dependency): 15–20 line mm:ss formatter + parser; a masking-library dependency isn't justified for this scope

### Expected Features

**Must have (table stakes):**
- Language switcher (EN/RU) in Profile settings, live-switch, no restart
- All UI strings — including error messages, validation feedback, dialogs — localized EN/RU
- Language preference persisted locally, restored on restart, no API round-trip
- Track duration entered and displayed as mm:ss everywhere (create/edit forms, lists, detail views) — `durationSeconds` API contract unchanged
- Known API error codes (e.g. `already_exists`, `unauthorized`) mapped to localized messages; unmapped codes fall back to raw server text

**Should have (competitive, not blocking):**
- mm:ss input placeholder/hint text ("2:30")
- Auto-formatting separator insertion as the user types (e.g. "230" → "2:30")

**Defer (explicitly out of scope, confirmed against user's own scoping answers):**
- Server-side language preference sync (would require a new `publicapi.yml` field — against the project's "no inventing API fields" constraint)
- Offline language-pack downloads (strings ship baked into the binary; no network-dependent localization)
- Device-locale auto-detection on first launch (English default is intentional, per user's explicit answer)
- Russian plural-form grammar (1/2–4/5+ track counts) — real risk if RU strings use counts, but treated as a P2 nice-to-have unless requirements demand it
- Date/time localization (no dates surface in current UI)
- HH:mm:ss duration format (no >1hr tracks in current data model)

### Architecture Approach

`LocaleController` (Riverpod, codegen'd) is a straight structural copy of the existing `ThemeController`: it holds `Locale` state, exposes `setLocale()`, and persists to local storage. `CadenceApp`'s `MaterialApp` watches it via `ref.watch(localeControllerProvider)` and feeds `locale`/`localizationsDelegates`/`supportedLocales` — the same wiring pattern already used for `themeMode`. The Profile screen (where the theme toggle already lives — architecture research calls this "SettingsScreen" but the codebase's actual location is `lib/features/profile/profile_screen.dart`) gains a Language section using the same list-tile pattern as the theme toggle. Duration conversion is a single boundary: a `TextInputFormatter` constrains keystrokes to mm:ss shape in the field, and one parse function converts "3:45" → 225 only at submit time, so `durationSeconds: int` on the wire never changes. Error-code localization is a small provider that watches the locale and maps known `ApiException.code` values to localized strings, falling back to the raw server `message` when a code isn't in the map.

**Major components:**
1. `LocaleController` (new, `lib/providers/locale_provider.dart`) — Riverpod locale state + Hive persistence, mirrors `ThemeController`
2. ARB files (`lib/l10n/app_en.arb`, `app_ru.arb`) + `l10n.yaml` — string source of truth, feeds Flutter's built-in `gen-l10n` codegen
3. `DurationFormatter`/`parseMMSStoSeconds` (new, in or near `lib/features/tracks/track_formatting.dart`) — mm:ss input formatting and seconds conversion, reusing the existing `asMinutesSeconds` display extension unchanged
4. Error-code-to-localized-string mapping provider — watches locale, wraps `ApiException` handling in existing catch blocks

### Critical Pitfalls

1. **~279 test assertions hardcode English strings** — every `find.text('...')` in the 401-test suite is a landmine; tests will silently pass on wrong content or break in bulk the moment strings move to ARB lookups. Catalog and centralize these into a test-strings utility before writing any i18n screen code, not after.
2. **Locale change doesn't propagate to already-built tabs** — the app's `IndexedStack`-based bottom nav keeps all 5 tabs mounted; a screen that doesn't explicitly `ref.watch(localeControllerProvider)` won't rebuild when the user switches language on another tab. Establish a "every localized screen watches locale" rule from the first plan, not discovered mid-milestone.
3. **mm:ss parser must reject malformed input strictly** — "5:60", "-5:30", "5:", empty string, and multi-colon input must all be rejected, not silently coerced; validate each component (minutes ≥0, 0 ≤ seconds ≤ 59) before converting to `durationSeconds`.
4. **Russian text overflows English-sized layouts** — badges, chips, and fixed-width cells sized for English will clip Russian (typically ~20-30% longer). Anything with a fixed `SizedBox` width around text needs to flex instead; test with real RU strings, not placeholder Latin text.
5. **Two existing duration-format conventions must converge before adding input** — `track_formatting.dart` and `setlist_formatting.dart` reportedly format duration differently ("mm:ss" vs a words-based "42m 35s"); pick one canonical mm:ss format and apply it everywhere before wiring the new input, or the input and display will visibly disagree.
6. **Cache must store raw data, not locale-rendered strings** — the Hive cache stores API responses; if any code path caches a pre-formatted localized string instead of the raw value, switching language won't update what's shown from cache until the next online fetch. Render localized text at the provider/widget layer, never at the cache-write layer.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase A: Locale + i18n Infrastructure
**Rationale:** Every other i18n-touching phase depends on `LocaleController` existing and the ARB/gen-l10n pipeline being wired into `app.dart` and the Profile screen. Pitfalls #1 (test strings) and #2 (locale propagation) are architectural decisions, not per-screen fixes — cheapest to establish once, upfront.
**Delivers:** `LocaleController` (Hive-persisted, mirrors `ThemeController`), `lib/l10n/app_en.arb`/`app_ru.arb` + `l10n.yaml`, `MaterialApp` locale wiring, Profile screen Language section, a documented "watch locale" pattern for screens, and a centralized test-strings utility replacing raw `find.text('...')` literals.
**Addresses:** Language switcher, persistent language preference
**Avoids:** Pitfall #1 (hardcoded test strings), #2 (locale propagation to mounted tabs), #6 (cache storing rendered strings)

### Phase B: Duration mm:ss Input + Display
**Rationale:** Fully independent of i18n work (per FEATURES.md's dependency graph, duration input only requires a formatter utility, not locale infrastructure) — safe to build in parallel with Phase A, or immediately after if sequencing serially. Isolating it also isolates its regression risk to the track create/edit forms.
**Delivers:** `DurationFormatter`/`parseMMSStoSeconds` utility (with thorough edge-case unit tests per Pitfall #3), updated `create_track_screen.dart`/`edit_track_screen.dart` duration fields, and format convergence across `track_formatting.dart`/`setlist_formatting.dart` per Pitfall #5.
**Uses:** Custom `TextInputFormatter` (STACK.md), existing `asMinutesSeconds` extension
**Implements:** mm:ss ↔ `durationSeconds` conversion boundary (ARCHITECTURE.md)

### Phase C: String Extraction & Screen Localization
**Rationale:** The highest-volume, highest-regression-risk work (20+ screens' hardcoded strings) — sequenced after Phase A's infrastructure and test-string centralization are proven, so this phase can move mechanically screen-by-screen without re-deriving the pattern each time.
**Delivers:** All hardcoded UI strings replaced with `AppLocalizations.of(context)!.key` lookups across every screen/dialog, Russian translations for the full string set.
**Addresses:** "All UI strings localized EN/RU" (FEATURES.md table stakes)

### Phase D: API Error Localization
**Rationale:** Depends on Phase A's ARB/locale infrastructure but is otherwise small and isolated to `ApiException` handling — safe to sequence last since it touches error paths, not happy-path UI, and is lower-risk to get wrong.
**Delivers:** Error-code-to-localized-string mapping, wired into existing `ApiException` catch blocks across screens, with confirmed raw-text fallback for unmapped codes.
**Addresses:** "Known API error codes map to localized messages" (FEATURES.md table stakes)

### Phase Ordering Rationale

- Locale infrastructure (Phase A) must exist before any screen can be localized (Phase C) or error codes mapped (Phase D) — hard dependency.
- Duration input (Phase B) has zero dependency on locale infrastructure per FEATURES.md's dependency graph, so it can run in parallel with Phase A if the roadmap allows, or serially without blocking either feature on the other.
- String extraction (Phase C) is sequenced after infrastructure specifically so the "watch locale" rule and test-string centralization (Pitfalls #1, #2) are already-proven patterns being applied, not being invented mid-sweep across 20+ files.
- Error localization (Phase D) is last because it's the smallest, most isolated surface (catch blocks only) and benefits from the ARB pipeline already existing.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase C (String Extraction):** Real per-screen scope is unknown until every hardcoded string is enumerated — recommend a screen-by-screen audit at plan time to size the work accurately, since 401 existing tests widely assert on this same text (Pitfall #1).
- **Phase A (Locale Infrastructure):** Confirm exactly how the existing `ThemeController`/Profile-screen pattern persists to Hive (vs. `flutter_secure_storage`, which ARCHITECTURE.md assumed but STACK.md and PROJECT.md indicate is Hive) before writing `LocaleController` — the two research docs disagree slightly on storage layer and this should be resolved by reading the actual `ThemeController` implementation, not assumed.

Phases with standard patterns (skip research-phase):
- **Phase B (Duration Input):** Well-understood `TextInputFormatter` pattern with a concrete parser/formatter implementation already sketched in STACK.md.
- **Phase D (Error Localization):** Small, mechanical mapping-table pattern with a clear existing `ApiException` integration point.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Flutter/Dart tooling only, zero new third-party dependencies, verified against current package versions |
| Features | HIGH | Clear table-stakes/differentiator/anti-feature split, directly cross-checked against the user's own milestone scoping answers |
| Architecture | HIGH | Mirrors an existing, proven in-app pattern (`ThemeController`) rather than introducing new architecture |
| Pitfalls | HIGH | Grounded in this specific codebase's known characteristics (401 tests, IndexedStack tabs, two divergent duration formats) |

**Overall confidence:** HIGH

### Gaps to Address

- **Storage layer for `LocaleController` (Hive vs. `flutter_secure_storage`):** ARCHITECTURE.md's sketch persists locale via `flutter_secure_storage`; STACK.md and this summary assume Hive (matching `ThemeController`'s actual persistence layer per PROJECT.md). Resolve by reading `lib/theme/theme_controller.dart` directly at plan time and copying its exact persistence mechanism — don't re-derive.
- **"SettingsScreen" vs. Profile screen naming:** ARCHITECTURE.md and STACK.md both refer to a "SettingsScreen" for the language picker; the actual codebase has no separate settings screen — the theme toggle lives in `lib/features/profile/profile_screen.dart`. Treat all "SettingsScreen" references in STACK.md/ARCHITECTURE.md as meaning the Profile screen.
- **Scope of the string-extraction sweep (Phase C):** Not sized here — needs a concrete inventory of hardcoded strings across all screens/dialogs during phase planning, per the Research Flag above.
- **Whether Russian plural forms are required in v1.2:** FEATURES.md treats this as P2/defer, but if any P1 string involves a count (e.g. "N tracks", "N members" — which already exists in the shipped BAND-10 member-count display), a decision is needed on whether English-style pluralization is acceptable in Russian for this milestone or must be grammatically correct from day one.

## Sources

### Primary (HIGH confidence)
- [Flutter Internationalization Documentation](https://docs.flutter.dev/accessibility-and-localization/internationalization)
- [intl package on pub.dev](https://pub.dev/packages/intl) — 0.19.0+, null-safe, ARB support
- [ARB (App Resource Bundle) Specification](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- Codebase precedent: `ThemeController`, existing `asMinutesSeconds` duration extension, `ApiException` model

### Secondary (MEDIUM confidence)
- [CLDR Plural Rules](http://cldr.unicode.org/index/cldr-spec/plural-rules) — Russian pluralization reference, not yet applied to this codebase's specific strings

### Tertiary (LOW confidence)
- Competitor feature comparisons (Bandcamp Mobile, SetList.co) in FEATURES.md — general market observation, not verified against current app versions

---
*Research completed: 2026-08-25*
*Ready for roadmap: yes*
