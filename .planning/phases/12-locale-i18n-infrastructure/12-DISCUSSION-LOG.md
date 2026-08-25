# Phase 12: Locale + i18n Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-25
**Phase:** 12-Locale + i18n Infrastructure
**Areas discussed:** Placement, Persistence mechanism, Language label style, Live-switch proof scope

---

## Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Existing Settings screen | Add a 'Language' section below/beside 'Theme' in `settings_screen.dart`, reusing its RadioListTile pattern. | ✓ |
| Separate Language screen | New screen linked from Profile, separate from Settings. | |

**User's choice:** Existing Settings screen.
**Notes:** Follow-up question on visual grouping — section header + divider (matching Theme's existing header) chosen over "you decide".

| Option | Description | Selected |
|--------|-------------|----------|
| Section header + divider | Same pattern as Theme's own header text — add a 'Language' header/divider above the two RadioListTiles. | ✓ |
| You decide | Claude picks based on what reads cleanest. | |

**User's choice:** Section header + divider.

---

## Persistence mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| SharedPreferences | New dep, standard Flutter approach for non-secret UI settings; separate from CacheService and flutter_secure_storage. | ✓ |
| New Hive box | Reuses existing dep, but must be excluded from `CacheService.clearAll()` on logout. | |
| flutter_secure_storage | Reuses existing dep, but built for secrets — semantically wrong for a UI preference. | |

**User's choice:** SharedPreferences.

**Follow-up:** Should the language preference survive logout?

| Option | Description | Selected |
|--------|-------------|----------|
| Survives logout | Language is a device preference, not account data — untouched by CacheService.clearAll()/signOut(). | ✓ |
| Resets to English on logout | Would require explicitly clearing the key inside signOut() — no stated requirement driving it. | |

**User's choice:** Survives logout.

**Follow-up (user-initiated):** "what about default language? can this be guessed from device/browser language?"

**Notes:** This was already decided at the requirements stage — REQUIREMENTS.md's Out of Scope table explicitly excludes device-locale auto-detection ("bilingual/traveling-band devices make auto-detect unreliable"), and Phase 12's own success criterion 3 requires fresh installs to default to English. Presented as a confirm-or-reopen choice rather than a fresh design question.

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmed, next area | Default stays hardcoded English, no device-locale detection, per REQUIREMENTS.md. | ✓ |
| Revisit this decision | Would mean amending REQUIREMENTS.md, not just this phase's context. | |

**User's choice:** Confirmed, next area.

---

## Language label style

| Option | Description | Selected |
|--------|-------------|----------|
| Native names | 'English' / 'Русский' — each language names itself, readable regardless of current locale. | ✓ |
| Translated to current locale | 'English'/'Russian' vs 'Английский'/'Русский' depending on active locale — needs its own ARB entries. | |

**User's choice:** Native names.

---

## Live-switch proof scope

| Option | Description | Selected |
|--------|-------------|----------|
| Localize the whole Settings screen | AppBar title, 'Theme' header, radio labels, 'Language' header — ~7 short strings, all visible where the switch lives. | ✓ |
| Localize just the section headers | Only 'Theme' and 'Language' headers get ARB entries — smallest footprint, less obvious proof. | |

**User's choice:** Localize the whole Settings screen.
**Notes:** Driven by the native-names decision above — since the language option labels themselves won't visibly change on switch, the rest of the Settings screen needs to carry the proof.

---

## Claude's Discretion

- `LocaleController` implementation shape — mirrors the existing `ThemeController` Riverpod pattern.
- `IndexedStack` stale-tab propagation mechanism — expected to work via Flutter's `Localizations` InheritedWidget, same as existing `ThemeMode` propagation; to be confirmed during research/planning, not a user-facing decision.
- `l10n.yaml` configuration details (arb-dir, output-class naming, etc.) — standard setup, no product-visible impact.

## Deferred Ideas

None — discussion stayed within phase scope.
