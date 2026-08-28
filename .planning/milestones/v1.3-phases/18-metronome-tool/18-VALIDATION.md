---
phase: 18
slug: metronome-tool
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-27
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) + Riverpod testing utilities |
| **Config file** | none — Flutter uses no config file; tests run via `flutter test` |
| **Quick run command** | `flutter test test/features/metronome/ -j 1` |
| **Full suite command** | `flutter test --coverage` |
| **Estimated runtime** | ~10-15 seconds (quick) / full suite varies |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/metronome/ -j 1`
- **After every plan wave:** Run `flutter test --coverage`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | METR-01 | — | N/A | integration | `flutter test test/features/home/home_screen_test.dart -k 'metronome button'` | ❌ W0 | ⬜ pending |
| 18-01-02 | 01 | 1 | METR-02 | — | N/A | integration | `flutter test test/features/tracks/track_detail_screen_test.dart -k 'metronome entry'` | ❌ W0 | ⬜ pending |
| 18-02-01 | 02 | 2 | METR-03 | T-18-01 | BPM clamped [40,300]; audio load failures logged, not exposed to user | unit/widget | `flutter test test/features/metronome/metronome_state_test.dart::ticksPlayInSequence` | ❌ W0 | ⬜ pending |
| 18-02-02 | 02 | 2 | METR-04 | T-18-01 | Drag-calculated BPM validated before state update | widget | `flutter test test/features/metronome/metronome_dial_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/metronome/metronome_state_test.dart` — unit tests for beat scheduling, BPM changes, play/pause state transitions (stubs for METR-03)
- [ ] `test/features/metronome/metronome_dial_test.dart` — widget tests for drag gesture, angle-to-BPM mapping, visual updates (stubs for METR-04)
- [ ] `test/features/metronome/metronome_audio_service_test.dart` — mock `AudioPlayer`, verify `playTick()` calls correct player (accent vs regular)
- [ ] `test/features/home/home_screen_test.dart` — extend existing tests to verify "Tools" section is present and "Metronome" button navigates with BPM=120 (stubs for METR-01)
- [ ] `test/features/tracks/track_detail_screen_test.dart` — extend existing tests to verify metronome icon appears only when `track.tempo != null` (stubs for METR-02)
- [ ] `test/integration/metronome_e2e_test.dart` — end-to-end: open metronome from homepage, drag dial, press play, verify beat indicators cycle

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audio-visual sync perceptibility (tick sound audibly aligned with beat-dot pulse) | METR-03 | Perceptual timing quality (sub-frame audio/visual sync) cannot be asserted by widget tests; requires human ear/eye judgment on-device | Run the app on a physical device, start the metronome at 120 BPM, confirm tick sound and dot pulse feel simultaneous; repeat at 40 and 300 BPM |
| Low-latency audio retrigger quality on real hardware | METR-03 | `audioplayers` `PlayerMode.lowLatency` behavior varies by platform/device (10-50ms); simulators/emulators may not reflect real latency | Test on a physical Android and iOS device at high BPM (e.g., 250+) to confirm no audible tick dropout or overlap |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
