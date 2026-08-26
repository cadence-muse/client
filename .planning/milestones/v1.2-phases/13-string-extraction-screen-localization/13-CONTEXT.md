# Phase 13: String Extraction & Screen Localization - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Every hardcoded UI string across the app's screens, dialogs, and always-visible shared surfaces — labels, buttons, dialogs, validation messages, and count-bearing strings — is replaced with localized EN/RU ARB lookups, with grammatically correct Russian pluralization (1 / 2-4 / 5+) for counts. This phase also builds the centralized test-strings utility that lets the existing widget test suite assert against localized copy instead of hardcoded English literals. It does NOT do API error localization (Phase 14) and does NOT touch Settings screen strings (already localized in Phase 12, which also built the ARB/gen-l10n pipeline and `LocaleController` this phase reuses as-is).

</domain>

<decisions>
## Implementation Decisions

### Shared string deduplication
- **D-01:** Strings that repeat verbatim or near-verbatim across multiple screens (e.g. "Retry", "Cancel", "Requires connection", "Please check your connection and try again.") get ONE shared ARB key reused everywhere, not per-screen duplicate keys. — **Reversibility:** costly — un-merging later means finding every call site of a shared key and re-splitting into screen-specific ones.
- **D-02:** Shared keys use a `common` prefix convention — `commonRetry`, `commonCancel`, `commonDelete`, `commonRequiresConnection`, etc. — signaling cross-screen reuse at a glance in the flat ARB file, consistent with the existing scoped-prefix style (`appBarSettingsTitle`, `sectionThemeTitle`) from Phase 12.
- **D-03:** Near-duplicate (not byte-identical) strings also merge into one shared key — e.g. the ~6 variations of "please check your connection" error copy across screens unify to one `commonConnectionError`-style key, even though this changes the exact wording shown on some screens today.
- **D-04:** Split by role: short action-word buttons (Delete, Cancel, Save, Create, Retry) use `commonX` shared keys; longer sentence-level copy (dialog confirmation bodies, empty-state descriptions) stays per-screen/per-dialog even when superficially similar, since it usually carries a variable subject (band name, track title, member name).

### Test-strings utility
- **D-05:** The test-strings utility wraps `AppLocalizations` directly (reads live off the pumped widget tree) rather than a handwritten constants file — single source of truth is the ARB file itself, zero drift risk if a string's ARB value changes.
- **D-06:** Access shape is an extension on `WidgetTester` — `tester.strings.commonRetry` — reading `AppLocalizations` off the currently pumped tree's context. Natural fit since every existing test already has a `WidgetTester` in scope.
- **D-07:** Migration scope is touched-file app-copy assertions only, not a full sweep of all 29 test files. As each screen/dialog is localized in this phase, its own test file's app-copy `find.text('English literal')` calls migrate to `tester.strings.X`. Test-fixture/data literals (band names, usernames, track titles like `'Wonderwall'`) are never migrated — they're test data, not UI copy, and stay hardcoded regardless of which file they're in.
- **D-08:** The test-strings utility also covers the two ICU plural methods (`tester.strings.memberCount(n)`, `tester.strings.trackCount(n)`) — one consistent API surface, no test ever calls `AppLocalizations.of(context)!` directly even for plural assertions.

### Plural-string consolidation
- **D-09:** Member count consolidates into one shared ICU-plural ARB method, `memberCount(count)`, with RU's 1/2-4/5+ forms. This replaces BOTH today's independent implementations: the `_membersLabel` helper in `bands_screen.dart:15` (which should be deleted) and the duplicate inline expression in `band_detail_screen.dart:127-128`.
- **D-10:** `band_detail_screen.dart`'s combined "Owner • N members" string splits into two separate pieces — a role-label ARB string ("Owner"/"Member") plus the shared `memberCount()` call — rather than one combined ARB message interpolating both together. Keeps the plural entry simple (no role × plural-form cross product to translate).
- **D-11:** The fixed-at-100 max-track messages (`add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `setlist_detail_screen.dart`) reuse the same `trackCount()` plural method used for the visible track-count display, for grammatically consistent RU even though only the 5+ form will ever render for a ceiling of 100.
- **D-12:** The `_maxSetlistTracks` constant — currently independently declared as `static const int` in all 3 of the files above — consolidates into one shared location (e.g. alongside `setlist_formatting.dart`) since those files are being touched for localization anyway. — **Reversibility:** reversible — a plain constant re-split, no external contract.

### Scope boundary: in-scope shared surfaces
- **D-13:** `lib/navigation/root_scaffold.dart`'s 5 `NavigationDestination` labels (Home, Bands, Tracks, Setlists, Profile) ARE in scope — always-visible bottom-nav text regardless of active tab, directly gating "no screen retains hardcoded English."
- **D-14:** `lib/widgets/offline_no_cache_view.dart` (consumed by ~6 list screens' offline empty-state: "No cached data" / "Connect to the internet to load this") IS in scope. Localizing this one shared widget covers all its consuming screens at once.
- **D-15:** `lib/widgets/offline_banner.dart` ("Showing cached data — may be out of date", mounted above the `IndexedStack` in `RootScaffold`, visible on every tab when offline with cached data) IS in scope.
- **D-16:** `lib/features/auth/login_screen.dart` (~4 strings: Username/Password labels, Sign up/Log in validator text) IS in scope, even though ROADMAP's enumerated success criteria name only Home/Songs/Tracks/Bands/Setlists/Profile. Rationale: Phase 12's D-04 means the language preference survives logout, so a Russian-speaking user landing back on the login screen after logout would otherwise see English text — a real gap in "no screen retains hardcoded English."

### Claude's Discretion
- Exact ARB key names beyond the `commonX` convention for shared strings and per-screen naming for the rest — follow the existing flat-namespace, scoped-prefix style from Phase 12's `app_en.arb`.
- Judgment calls on which near-duplicate strings are "close enough" to merge under D-03 without changing user-visible meaning.
- ICU plural ARB syntax details for `memberCount()`/`trackCount()` (placeholder typing, `@key` metadata blocks) — this is the first use of Flutter's `{count, plural, ...}` in this ARB pipeline; no existing precedent to follow, standard Flutter gen-l10n conventions apply.
- Any other `lib/widgets/` shared files not surfaced during discussion that turn out to have hardcoded strings visible from in-scope screens — apply the same "always-visible or widely-consumed shared surface → in scope" reasoning established by D-13 through D-16.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — I18N-04, I18N-06 (source requirements for this phase)
- `.planning/ROADMAP.md` §"Phase 13: String Extraction & Screen Localization" — goal, 4 success criteria, dependency on Phase 12

### Prior phase context
- `.planning/phases/12-locale-i18n-infrastructure/12-CONTEXT.md` — established `LocaleController` pattern, ARB/gen-l10n pipeline, native-name language labels (D-06 there), Settings screen as the proven live-switch reference implementation
- `.planning/PROJECT.md` §Key Decisions — Riverpod/`@riverpod` codegen pattern; "no service locators, dependency injection only" architectural constraint

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/settings/settings_screen.dart` — proven `AppLocalizations.of(context)!.keyName` access pattern from Phase 12; every new screen follows this exact shape
- `lib/l10n/app_en.arb` / `app_ru.arb` — existing flat key→string ARB files with `@@locale` metadata; currently 8 keys, all simple (no placeholders, no plurals) — this phase adds the first placeholder and plural entries
- `lib/generated/app_localizations.dart` — standard Flutter gen-l10n scaffold (abstract class + delegate), regenerates automatically from ARB via `flutter gen-l10n` / `build_runner`

### Established Patterns
- ARB files are a single flat namespace with scoped-prefix key names (`appBarSettingsTitle`, `sectionThemeTitle`) — no nested/grouped ARB structure
- `IndexedStack` in `lib/navigation/root_scaffold.dart:34` keeps 5 tab screens (Home, Bands, Tracks, Setlists, Profile) alive without disposal — each screen's `build()` runs once per app session unless the tab is re-selected to re-invalidate its data provider; all 5 must genuinely re-render with new locale strings after a switch since Flutter's `Localizations` InheritedWidget notifies mounted-but-inactive descendants (same mechanism already proven for `ThemeMode` in Phase 12)
- Screens NOT in the `IndexedStack` (pushed via `Navigator.push`, rebuild fresh each visit, no stale-locale risk): all `create_*`/`edit_*`/`*_detail_screen.dart` screens, all `*_dialog.dart` files, `change_password_screen.dart`, `login_screen.dart`

### Integration Points
- `test/locale_live_switch_test.dart:155-192` already has an "I18N-02 success criterion 5" test that switches to Russian and returns to the kept-alive Home tab, but only asserts on the ambient `Localizations.localeOf(...)` — not on Home's actual rendered text, since Home isn't localized yet. This test needs strengthening once Home is localized (now in scope per D-13-ish reasoning, though Home itself was already implied in-scope by ROADMAP).
- Count-bearing strings needing `memberCount()`: `lib/features/bands/bands_screen.dart:15` (`_membersLabel` helper, to be deleted per D-09), `lib/features/bands/band_detail_screen.dart:127-128` (inline duplicate, to be replaced per D-09/D-10)
- Count-bearing strings needing `trackCount()`: `lib/features/setlists/setlist_formatting.dart:5` (`pluralizeTracks`, reused by `tracksAndDuration`), plus the 3 max-track-ceiling messages in `add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `setlist_detail_screen.dart` (per D-11)
- `_maxSetlistTracks` constant currently duplicated at `add_setlist_tracks_dialog.dart:53`, `create_setlist_screen.dart:29`, `setlist_detail_screen.dart:38` — consolidate per D-12
- `setlist_detail_screen.dart:311`'s `'Tracks (${tracks.length})'` is a numeral-in-parens header, not natural-language plural text — likely just needs the number to stay interpolated, not routed through `trackCount()`; confirm during planning
- 30 files under `lib/features/` (excluding `settings/`) plus `lib/navigation/root_scaffold.dart`, `lib/widgets/offline_no_cache_view.dart`, and `lib/widgets/offline_banner.dart` carry hardcoded strings needing extraction — full per-file inventory available from the scouting pass, not duplicated here to keep this document focused on decisions

</code_context>

<specifics>
## Specific Ideas

No UI mockups or visual specifics requested. Discussion focused entirely on ARB key-naming/deduplication strategy, the shape of the new test-strings utility, consolidating existing duplicate pluralization logic, and confirming scope boundaries for shared surfaces (nav bar, offline widgets, auth) that sit outside the ROADMAP's literally-named screen list but are clearly part of "no screen retains hardcoded English."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. All 4 discussed areas were implementation-decision clarifications (HOW to localize what's already scoped), not new capabilities.

</deferred>

---

*Phase: 13-String Extraction & Screen Localization*
*Context gathered: 2026-08-25*
