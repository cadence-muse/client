---
phase: 02
slug: bands
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-15
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) + riverpod testing utilities |
| **Config file** | analysis_options.yaml (already configured from Phase 1) |
| **Quick run command** | `flutter test test/providers/bands_provider_test.dart -k "cache-hit"` |
| **Full suite command** | `flutter test test/` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/providers/`
- **After every plan wave:** Run `flutter test test/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | BAND-01 | — | List bands from cache-first provider | unit | `flutter test test/providers/bands_provider_test.dart -k "cache-hit"` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 0 | BAND-02 | — | POST /api/band succeeds → navigate to detail | unit + integration | `flutter test test/providers/bands_provider_test.dart -k "create"` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 0 | BAND-03 | — | GET /api/band/{bandId} cache-first load | unit | `flutter test test/providers/band_detail_provider_test.dart -k "cache-hit"` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 0 | BAND-04 | — | PUT /api/band/{bandId} updates detail + invalidates cache | unit | `flutter test test/providers/band_detail_provider_test.dart -k "update"` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 0 | BAND-05 | T-1 | DELETE /api/band/{bandId} owner-only + list refresh | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "delete"` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 0 | BAND-06 | — | POST /api/band/join succeeds → navigate to detail | unit | `flutter test test/providers/bands_provider_test.dart -k "join"` | ❌ W0 | ⬜ pending |
| 02-01-07 | 01 | 0 | BAND-07 | — | inviteCode visible + Clipboard.setData works | widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "copy-invite"` | ❌ W0 | ⬜ pending |
| 02-01-08 | 01 | 0 | BAND-08 | T-1 | DELETE /api/band/{bandId}/remove-member/{userId} (self) + owner-gated | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "leave"` | ❌ W0 | ⬜ pending |
| 02-01-09 | 01 | 0 | BAND-09 | T-1 | DELETE /api/band/{bandId}/remove-member/{userId} (other) owner-only | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "remove-member"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/providers/bands_provider_test.dart` — covers BAND-01 (list cache-first), BAND-02 (create), BAND-06 (join)
- [ ] `test/providers/band_detail_provider_test.dart` — covers BAND-03 (detail cache-first), BAND-04 (update)
- [ ] `test/features/bands/band_detail_screen_test.dart` — covers BAND-05/BAND-08/BAND-09 (ownership gating, delete/leave/remove dialogs)
- [ ] `test/features/bands/bands_screen_test.dart` — covers BAND-01 (list display), FAB interaction, navigation
- [ ] `test/features/bands/create_band_screen_test.dart` — covers BAND-02 (form validation, submission)
- [ ] `test/features/bands/join_band_dialog_test.dart` — covers BAND-06 (invite code input, validation)
- [ ] `lib/api/public_api.dart` — BandsApi methods (testable with MockClient pattern)

*(Existing test infrastructure from Phase 1 covers ProviderContainer setup, CacheService test double, MockClient patterns. New tests follow the same patterns.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner-gating UI hides "Delete band"/"Remove member" for non-owners | BAND-05, BAND-09 | Requires visual confirmation that actions are hidden (not just disabled) across both owner and non-owner sessions | Log in as owner and non-owner; verify Delete/Remove actions appear only for owner |
| Type-to-confirm delete flow | BAND-05 | Destructive-action UX (typing exact band name) is best validated by a human interacting with the dialog | Trigger delete, verify confirm button stays disabled until exact name typed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
