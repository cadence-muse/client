---
phase: 12
slug: locale-i18n-infrastructure
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in Flutter testing) |
| **Config file** | test/providers/locale_provider_test.dart (new) |
| **Quick run command** | `flutter test test/providers/locale_provider_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/providers/locale_provider_test.dart` (or the widget test file for the task touched)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green, plus all 5 manual E2E tests below pass on at least one platform
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 0 | I18N-01 | — / — | N/A | unit | `flutter test test/providers/locale_provider_test.dart` | ❌ W0 | ⬜ pending |
| 12-01-02 | 01 | 0 | I18N-02 | — / — | N/A | manual E2E | (see Manual-Only Verifications) | ❌ W0 | ⬜ pending |
| 12-01-03 | 01 | 0 | I18N-03 | — / — | N/A | unit + manual E2E | `flutter test test/providers/locale_provider_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/providers/locale_provider_test.dart` — unit tests for `LocaleController.build()` default ('en'), `setLocale()` state update, SharedPreferences persistence round-trip
- [ ] `test/features/settings/settings_screen_test.dart` — widget tests for Language section `RadioListTile` rendering and `onChanged` callback wiring

*Some automated assertions on visible text are deferred to Phase 13, once `AppLocalizations` strings exist app-wide; Phase 12's Wave 0 tests still cover the provider/persistence logic directly.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Language switch applies live, no restart | I18N-02 | Requires visual confirmation of a live UI rebuild across a running app | Open Settings, tap "Русский", verify "Язык"/"Тема" section headers update immediately with no restart |
| Fresh install defaults to English | I18N-01 | Requires a clean device/emulator state, not reproducible in a unit test | Uninstall or clear app data, relaunch, open Settings, verify "English" is selected and text is English |
| Selection persists across full restart | I18N-03 | Requires killing and relaunching the OS process, outside flutter_test's scope | Select "Русский", fully close and reopen the app, verify it reopens in Russian |
| Language preference survives logout (D-04) | I18N-03 | Crosses auth + persistence boundaries; requires a real sign-out/sign-in cycle | Select "Русский", sign out, sign back in, verify the app is still in Russian |
| Background IndexedStack tab shows new language on next visit | I18N-02 | Requires navigating between live app tabs to observe stale-vs-fresh widget state | Switch language while on one tab, navigate to another, return, verify no stale pre-switch text remains |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
