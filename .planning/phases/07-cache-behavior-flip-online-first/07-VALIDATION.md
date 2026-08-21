---
phase: 07
slug: cache-behavior-flip-online-first
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-21
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) + Riverpod's ProviderContainer for provider testing |
| **Config file** | none — flutter_test needs no explicit config |
| **Quick run command** | `flutter test test/providers/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/providers/<changed_provider>_test.dart`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 0 | OFFL-07 | — | Online-first fetch on screen open | unit | `flutter test test/providers/bands_provider_test.dart` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 0 | OFFL-07 | — | Tab switch triggers refetch (5 tab screens) | integration | `flutter test test/features/` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 0 | OFFL-08 | — | Offline shows last-fetched cache data | unit | `flutter test test/providers/bands_provider_test.dart` | ❌ W0 | ⬜ pending |
| 07-01-04 | 01 | 0 | OFFL-08 | — | Offline with no cache shows dedicated empty state | unit | `flutter test test/providers/bands_provider_test.dart` | ❌ W0 | ⬜ pending |
| 07-01-05 | 01 | 0 | OFFL-08 | — | SyncStatusBadge removed from all 10 call-sites | smoke | `flutter analyze` + visual inspection | ✅ (by removal) | ⬜ pending |
| 07-01-06 | 01 | 0 | OFFL-08 | — | Offline banner text updated to "Showing cached data — may be out of date" | unit | `flutter test test/widgets/offline_banner_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/providers/bands_provider_test.dart` — online-first fetch, offline fallback, tab-switch refetch, offline-no-cache state
- [ ] `test/providers/tracks_provider_test.dart` — same 4 cases, applied to track list/detail (2 variants)
- [ ] `test/providers/setlists_provider_test.dart` — same 4 cases, applied to setlists list/detail (2 variants)
- [ ] `test/providers/profile_provider_test.dart` — same 4 cases for profile (no tab-switch needed; read-mostly)
- [ ] `test/providers/homepage_provider_test.dart` — same 4 cases for homepage
- [ ] `test/widgets/offline_banner_test.dart` — banner text verification, visibility based on `isOnlineProvider`
- [ ] `test/features/bands_screen_test.dart` — verify tab-switch listener is wired
- [ ] `test/features/tracks_screen_test.dart` — same tab-switch listener check
- [ ] `test/features/setlists_screen_test.dart` — same
- [ ] `test/features/profile_screen_test.dart` — same (no tab-switch refetch needed per D-02, verify no regressions)
- [ ] `test/features/home_screen_test.dart` — same
- [ ] Framework install: none needed — flutter_test built-in, Riverpod's ProviderContainer already in pubspec.lock

*4 test cases × 10 providers = 40 unit tests total; batch into shared test template across providers.*

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
