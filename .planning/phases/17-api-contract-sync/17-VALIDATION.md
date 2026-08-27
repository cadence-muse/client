---
phase: 17
slug: api-contract-sync
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-27
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | analysis_options.yaml (Flutter lints) |
| **Quick run command** | `flutter test test/features/auth/login_screen_test.dart -v` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 minutes |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/auth/login_screen_test.dart test/api/public_api_test.dart -v`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 300 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 0 | API-01 | — | N/A | widget | `flutter test test/features/tracks/track_list_screen_test.dart -k "search" -v` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 0 | API-01 | — | N/A | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart -k "search" -v` | ❌ W0 | ⬜ pending |
| 17-01-03 | 01 | 0 | API-01 | — | N/A | unit | `flutter test test/api/public_api_test.dart -k "listUserTracks" -v` | ✅ | ⬜ pending |
| 17-01-04 | 01 | 0 | API-01 | — | N/A | unit | `flutter test test/api/public_api_test.dart -k "listUserSetlists" -v` | ✅ | ⬜ pending |
| 17-01-05 | 01 | 0 | API-01 | — | N/A | widget | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart -k "search" -v` | ✅ | ⬜ pending |
| 17-01-06 | 01 | 0 | API-02 | — | N/A | unit | `flutter test test/features/auth/login_screen_test.dart -k "password" -v` | ✅ | ⬜ pending |
| 17-01-07 | 01 | 0 | API-02 | — | N/A | unit | `flutter test test/features/auth/login_screen_test.dart -k "signup" -v` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/tracks/track_list_screen_test.dart` — widget tests for search TextField, debounce, online-gating (API-01, Tracks tab)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — widget tests for search TextField, debounce, online-gating (API-01, Setlists tab)
- [ ] `test/api/public_api_test.dart` — update mocks for `listUserTracks`/`listUserSetlists` to expect GET instead of POST (API-01 request shape)
- [ ] `test/features/auth/login_screen_test.dart` — add case: login mode password validator accepts <8 chars but rejects empty (API-02 mode-specific validation)

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
