---
phase: 6
slug: foundation-info-settings-polish
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-20
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in via Flutter SDK) + Riverpod testing utilities |
| **Config file** | none — flutter test auto-discovers test/ directory |
| **Quick run command** | `flutter test test/features/profile/ test/features/bands/ test/features/tracks/ test/features/setlists/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/profile/ test/features/bands/ test/features/tracks/ test/features/setlists/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | USER-03 | V5/V8 | Current password non-empty validated client-side; server verifies | unit | `flutter test test/features/profile/change_password_form_test.dart` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | USER-03 | V5 | New password min 8 chars, confirm match | unit | `flutter test test/features/profile/change_password_form_test.dart` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | USER-03 | V9 | Success shows SnackBar; wrong current password shows clear error, no internal detail leaked | widget | `flutter test test/features/profile/change_password_screen_test.dart` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | BAND-10 | — | Member count and Owner/Member role displayed per band | widget | `flutter test test/features/bands/bands_screen_test.dart` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 1 | TRACK-07 | — | Key/duration/notes icons shown when present, omitted when null | widget | `flutter test test/features/tracks/track_list_screen_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-01 | 04 | 1 | SETL-11 | — | Location/duration icons shown when present, omitted when null | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/profile/change_password_form_test.dart` — unit tests for form validation (current/new/confirm password checks)
- [ ] `test/features/profile/change_password_screen_test.dart` — widget tests for screen (success flow, error handling, API call)
- [ ] `test/features/bands/bands_screen_test.dart` — update existing test to verify member count and role badge display
- [ ] `test/features/tracks/track_list_screen_test.dart` — add icon display tests (key present, key absent)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — add icon display tests (location present, location absent)
- [ ] `test/helpers/mock_public_api.dart` — if not present, add mock `changePassword()` method for testing

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
