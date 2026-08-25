# Phase 12: Locale + i18n Infrastructure - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can switch the app's language between English and Russian from Profile settings; the switch applies live with no restart; the selection persists locally across restarts. This phase establishes the ARB/gen-l10n pipeline and the locale-propagation pattern (`LocaleController`) that Phases 13-14 build on — it does NOT do the full string-extraction sweep (Phase 13) or API error localization (Phase 14). No dependency on Phase 11 (duration input) either direction.

</domain>

<decisions>
## Implementation Decisions

### Language switcher placement
- **D-01:** Add the language switcher to the existing `lib/features/settings/settings_screen.dart`, alongside the existing Theme section — not a separate screen. One settings hub.
- **D-02:** Visually distinguish the two sections with a "Language" header + divider above the two RadioListTiles, matching the existing "Theme" header pattern already in that file.

### Persistence mechanism
- **D-03:** Add `shared_preferences` as a new dependency for the persisted language preference. Deliberately NOT `CacheService`/Hive (that's API read-cache, wiped by `CacheService.clearAll()` on logout/403) and NOT `flutter_secure_storage` (built for secrets, semantically wrong for a plain UI preference). — **Reversibility:** costly — reverting means migrating the persisted key to a different storage backend and handling the one-time read of the old value.
- **D-04:** The language preference survives logout/sign-out — it is a device preference, not account data. `AuthSession.signOut()` must NOT clear the SharedPreferences language key. This is a real behavior decision, not just "whatever SharedPreferences does by default" — call it out explicitly in the plan so signOut() isn't later "fixed" to clear all local state indiscriminately.
- **D-05 (confirmed, not re-decided):** No device-locale auto-detection on first launch — fresh install always defaults to hardcoded English. This is already locked in `.planning/REQUIREMENTS.md` Out of Scope table ("bilingual/traveling-band devices make auto-detect unreliable"); user asked about it mid-discussion and confirmed the existing decision stands rather than reopening it.

### Language label style
- **D-06:** Language options are labeled with native names — "English" and "Русский" — not translated to the current locale. These are static strings, not ARB entries (a language's name in its own script doesn't change based on which language is currently selected).

### Live-switch proof scope (ARB seed for this phase)
- **D-07:** Because the language option labels themselves are static native names (D-06) and won't visibly change on switch, this phase localizes the entire Settings screen to prove success criterion 2 (live update, no restart): AppBar title "Settings", "Theme" section header, "System"/"Light"/"Dark" radio labels, and the new "Language" section header — roughly 7 short ARB string entries. This is the full ARB/gen-l10n pipeline's first real content, proving the mechanism end-to-end before Phase 13's full sweep.

### Claude's Discretion
- Exact `LocaleController` implementation shape — mirror the existing `ThemeController` pattern (`@riverpod` class in `lib/providers/`, `ThemeMode`-style state, `setLocale()` notifier method) since that's the established, proven pattern in this codebase for exactly this kind of app-wide UI preference.
- How the `IndexedStack`-kept-alive-tab propagation (success criterion 5) is implemented — Flutter's `Localizations` InheritedWidget should notify all mounted-but-inactive tab descendants automatically when `MaterialApp.locale` changes, same as the existing `ThemeMode` propagation already proven to work across tabs. Research/planning should confirm this holds before treating it as free, but it is not a user-facing decision.
- l10n.yaml configuration details (arb-dir, template-arb-file, output-class naming, synthetic-package setting) — standard Flutter gen-l10n setup, no product-visible impact.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — I18N-01, I18N-02, I18N-03 (source requirements for this phase); Out of Scope table locks "no device-locale auto-detection" (D-05) and "no server-side language sync"
- `.planning/ROADMAP.md` §"Phase 12: Locale + i18n Infrastructure" — goal, 5 success criteria, "Depends on: Nothing new"

### Project context
- `.planning/PROJECT.md` §Key Decisions — established Riverpod/`@riverpod` codegen pattern; "no service locators, dependency injection only" architectural constraint applies to `LocaleController` too

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/providers/theme_provider.dart` — `ThemeController` (`@riverpod` class, `ThemeMode build()`, `setThemeMode()` notifier method) is the direct pattern template for the new `LocaleController`
- `lib/features/settings/settings_screen.dart` — existing `RadioGroup<ThemeMode>` + `RadioListTile` UI pattern to extend with a second `RadioGroup<Locale>` section, not replace
- `lib/app.dart` — `CadenceApp` already watches `themeControllerProvider` and feeds `MaterialApp.themeMode`; the same wiring shape (`ref.watch(localeControllerProvider)` → `MaterialApp.locale`) applies for locale

### Established Patterns
- Riverpod codegen (`@riverpod` classes, generated via `build_runner`) is the only state-management pattern in this codebase — no ChangeNotifier, no GetIt/service locator
- `AuthSession.signOut()` (`lib/providers/auth_provider.dart`) currently clears token (`TokenStorage.delete()`) and cache (`CacheService.clearAll()`) — D-04 requires this method NOT be extended to also clear the new language preference key

### Integration Points
- `lib/app.dart` — `MaterialApp` needs `localizationsDelegates`, `supportedLocales`, and `locale: ref.watch(localeControllerProvider)` added
- `lib/features/settings/settings_screen.dart` — gains the Language section (D-01, D-02) and becomes the first screen with any localized (ARB-backed) strings (D-07)
- `pubspec.yaml` — needs `flutter_localizations` (SDK), `intl`, and new `shared_preferences` (D-03) dependencies; needs `generate: true` under the `flutter:` key
- No `l10n.yaml` or `lib/l10n/` directory exists yet — this phase creates the ARB/gen-l10n pipeline from scratch, nothing to migrate

</code_context>

<specifics>
## Specific Ideas

No specific UI mockups requested. User engaged actively on persistence semantics (logout survival) and confirmed the existing English-default/no-auto-detect requirement rather than reopening it — otherwise deferred to recommended options throughout (Settings-screen placement, section-header pattern, SharedPreferences, native-name labels, whole-Settings-screen ARB seed).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The device-locale auto-detection question that came up was not new scope creep but a check against an already-locked REQUIREMENTS.md decision (see D-05) — confirmed, not deferred.

</deferred>

---

*Phase: 12-Locale + i18n Infrastructure*
*Context gathered: 2026-08-25*
