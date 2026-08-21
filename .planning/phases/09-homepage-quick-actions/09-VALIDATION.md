---
phase: 09
slug: homepage-quick-actions
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-22
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) + MockClient from http/testing.dart |
| **Config file** | None — standard Flutter project |
| **Quick run command** | `flutter test test/features/home/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/home/home_screen_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 0 | HOME-01/02 | — | N/A | widget test scaffold | `flutter test test/features/home/home_screen_test.dart` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-01 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testAddBandNavigation` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testAddSongOpensPickerWhenBandsExist` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testPickerNavigatesToCreateTrackScreen` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testAddSetlistOpensPickerWhenBandsExist` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testPickerNavigatesToCreateSetlistScreen` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-01/02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testAddSongSetlistDisabledWhenNoBands` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-01/02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testAddSongSetlistEnabledWhenBandsExist` | ❌ W0 | ⬜ pending |
| 09-0X-0X | TBD | TBD | HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart::testDismissPickerStaysOnHome` | ❌ W0 | ⬜ pending |

*Task IDs / plan / wave columns are placeholders — the planner fills exact IDs when it authors PLAN.md tasks; behavior/command mapping above is taken verbatim from RESEARCH.md's Phase Requirements → Test Map.*

---

## Wave 0 Requirements

- [ ] `test/features/home/home_screen_test.dart` — widget tests covering all 8 behaviors above (navigation, picker open/close, enabled/disabled states)
- [ ] Fixtures/mocks: `MockHomeDataProvider`, `MockBandsProvider` to simulate various states (zero bands, multiple bands, loading, error)
- [ ] Test harness: integration with existing test patterns from `test/providers/homepage_provider_test.dart` (ProviderContainer + MockClient)

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
