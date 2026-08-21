---
phase: 08
slug: band-owner-tools
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-21
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in, used throughout project) |
| **Config file** | analysis_options.yaml (project root) |
| **Quick run command** | `flutter test tests/features/bands/ -k "owner"` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds (quick) / 3-5 minutes (full, 371/371 passing after Phase 07) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test tests/features/bands/ -k "owner" --coverage`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green (371/371) + manual invite-rotation + manual transfer-ownership sign-off
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-TBD | 01 | 1 | BAND-11 | V4 Access Control | Rotate button visible to owner only | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "rotate"` | ✅ (Phase 6 owner-gate tests exist) | ⬜ pending |
| 08-01-TBD | 01 | 1 | BAND-11 | V4 Access Control | New invite code shown immediately after rotate | widget | `flutter test tests/features/bands/confirm_rotate_invite_code_dialog_test.dart -k "success"` | ❌ W0 | ⬜ pending |
| 08-01-TBD | 01 | 1 | BAND-11 | V4 Access Control | Old invite code invalidated server-side | integration | Manual: join with old code after rotate | ❌ W0 | ⬜ pending |
| 08-02-TBD | 02 | 1 | BAND-12 | V4 Access Control | Transfer button visible to owner only | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "transfer"` | ✅ (Phase 6 owner-gate tests exist) | ⬜ pending |
| 08-02-TBD | 02 | 1 | BAND-12 | V4 Access Control | New owner sees owner controls after transfer | widget | `flutter test tests/features/bands/confirm_transfer_ownership_dialog_test.dart -k "success"` | ❌ W0 | ⬜ pending |
| 08-02-TBD | 02 | 1 | BAND-12 | V4 Access Control | Old owner sees member controls after transfer | widget | `flutter test tests/features/bands/confirm_transfer_ownership_dialog_test.dart -k "success"` | ❌ W0 | ⬜ pending |
| 08-02-TBD | 02 | 1 | BAND-12 | V4 Access Control | Non-owner never sees either control | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "non_owner"` | ✅ (Phase 6 existing) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*(Task IDs are placeholders — planner assigns final `{N}-{plan}-{task}` IDs; execute-phase reconciles against this map.)*

---

## Wave 0 Requirements

- [ ] `tests/features/bands/confirm_rotate_invite_code_dialog_test.dart` — covers BAND-11 success/error/offline scenarios
- [ ] `tests/features/bands/confirm_transfer_ownership_dialog_test.dart` — covers BAND-12 success/error/offline scenarios
- [ ] `tests/features/bands/band_detail_screen_test.dart` — extend Phase 6 owner-gate tests with new Rotate icon / "Make owner" menu item visibility
- Framework install: none needed — flutter_test already in `pubspec.yaml`, `analysis_options.yaml` already configured

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Old invite code rejected after rotation | BAND-11 | Requires a second device/session attempting to join with the stale code against the live API — no automated integration harness for cross-session join flow exists | 1) Rotate invite code as owner. 2) Attempt join with the previous code from another account. 3) Confirm join is rejected. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
