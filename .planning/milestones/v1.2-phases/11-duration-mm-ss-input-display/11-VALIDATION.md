---
phase: 11
slug: duration-mm-ss-input-display
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in, no new dependency) |
| **Config file** | `test/widget_test.dart` (existing test structure) |
| **Quick run command** | `flutter test test/features/tracks/ test/features/setlists/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds (401+ tests) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/tracks/ test/features/setlists/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 0 | DUR-04 | — | N/A | unit | `flutter test test/widgets/duration_input_formatter_test.dart` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 0 | DUR-02 | — | Rejects negative/≥60s/malformed input | unit | `flutter test test/utils/duration_parser_test.dart` | ❌ W0 | ⬜ pending |
| 11-01-03 | 01 | 1 | DUR-01 | — | N/A | integration | `flutter test test/features/tracks/create_track_screen_test.dart` | ❌ W0 | ⬜ pending |
| 11-01-04 | 01 | 1 | DUR-01 | — | N/A | integration | `flutter test test/features/tracks/edit_track_screen_test.dart` | ❌ W0 | ⬜ pending |
| 11-01-05 | 01 | 1 | DUR-03 | — | N/A | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart` | ❌ W0 | ⬜ pending |
| 11-01-06 | 01 | 1 | DUR-03 | — | N/A | widget | `flutter test test/features/tracks/track_list_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/utils/duration_parser_test.dart` — stubs for DUR-02 (`""`, `":"`, `"0:0"`, `"5:60"`, `"abc:def"`, `"-1:00"`, `"999:59"`, paste scenarios)
- [ ] `test/widgets/duration_input_formatter_test.dart` — stubs for DUR-04 (keystroke simulation: `"2"` → `"0:02"`, `"230"` → `"2:30"`, backspace, paste)
- [ ] `test/features/tracks/create_track_screen_test.dart` — stubs for DUR-01
- [ ] `test/features/tracks/edit_track_screen_test.dart` — stubs for DUR-01 (edit flow)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — stubs for DUR-03 (verify mm:ss, not "Xm Ys")
- [ ] `test/features/tracks/track_list_screen_test.dart` — regression stub for DUR-03 (track display unaffected)
- [ ] Audit existing tests under `test/features/tracks/` for assertions on the old "Duration (seconds)" label or raw-seconds input; update to match new mm:ss field

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Auto-format feedback while typing feels responsive, no cursor jump | DUR-04 | Visual/UX judgment not captured by widget test assertions | Run app, type "230" into duration field, confirm it renders "2:30" with cursor in a sane position |
| Paste operation into duration field | DUR-02, DUR-04 | Clipboard interaction not reliably simulated in flutter_test | Copy "3:45" and "999" externally, paste into duration field, confirm correct handling |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
