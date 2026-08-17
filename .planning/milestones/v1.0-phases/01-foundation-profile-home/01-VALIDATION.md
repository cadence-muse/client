---
phase: 01
slug: foundation-profile-home
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-15
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK) + `mockito` (for mocking) |
| **Config file** | `test/` directory; no separate config needed (Flutter default) |
| **Quick run command** | `flutter test test/providers/ && flutter test test/cache/` |
| **Full suite command** | `flutter test test/` |
| **Estimated runtime** | ~30-60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/providers/ && flutter test test/cache/`
- **After every plan wave:** Run `flutter test test/`
- **Before `/gsd-verify-work`:** Full suite must be green, plus manual UI test in offline mode
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | OFFL-06 | — | AuthSession provider returns AsyncData with token on restore | unit | `flutter test test/providers/auth_provider_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 0 | OFFL-06 | — | ThemeProvider watches theme state without ChangeNotifier | unit | `flutter test test/providers/theme_provider_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 0 | OFFL-01 | T-01-05 / T-01-06 | Profile/homepage data persists in and reads from Hive boxes | unit | `flutter test test/cache/cache_service_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | USER-01 | T-01-02 / T-01-03 | Profile data provider reads Hive cache, falls back to `GET /api/me` | unit | `flutter test test/providers/profile_provider_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 1 | USER-01 | — | Profile screen renders `UserProfile.username` via AsyncData.when | widget | `flutter test test/features/profile/profile_screen_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-06 | 01 | 1 | USER-02 | T-01-02 / T-01-03 | Homepage data provider reads Hive cache, falls back to `GET /api/homepage` | unit | `flutter test test/providers/homepage_provider_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-07 | 01 | 1 | USER-02 | — | Home screen renders `HomepageData.bandsCount` with pluralization | widget | `flutter test test/features/home/home_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/providers/auth_provider_test.dart` — covers OFFL-06 (auth restoration, signIn/signOut methods with TokenStorage mock)
- [ ] `test/providers/profile_provider_test.dart` — covers USER-01 + OFFL-01 (cache-first loading, network fetch on miss, Hive persistence)
- [ ] `test/providers/homepage_provider_test.dart` — covers USER-02 + OFFL-01 (cache-first loading, Hive persistence)
- [ ] `test/providers/theme_provider_test.dart` — covers OFFL-06 (theme state without ChangeNotifier)
- [ ] `test/features/profile/profile_screen_test.dart` — covers USER-01 (ConsumerWidget render with AsyncData.when, error/loading states, refresh button)
- [ ] `test/features/home/home_screen_test.dart` — covers USER-02 (welcome message, band count pluralization, no-bands empty state)
- [ ] `test/cache/cache_service_test.dart` — covers OFFL-01 (Hive box read/write, cache miss returns null, I/O errors caught)
- [ ] `test/conftest.dart` or shared fixtures — ProviderContainer setup, mock ApiClient, mock TokenStorage, mock Hive boxes for all provider tests
- [ ] Framework install: Already present via `flutter_test` SDK dependency; no additional setup needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Profile/homepage show last-fetched data with no connectivity | OFFL-01 | No automated network-off simulation in current test setup | Enable airplane mode on device/emulator after one successful fetch, reopen profile and home tabs, confirm cached data renders without error |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
