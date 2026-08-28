# Phase 16: Track Terminology Rename - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-27
**Phase:** 16-Track Terminology Rename
**Areas discussed:** ARB key + wording, publicapi.yml Songs tag, Test fixture data

---

## ARB key + wording

| Option | Description | Selected |
|--------|-------------|----------|
| homeAddTrackButton / "Add Track" | Matches sibling keys homeAddBandButton/homeAddSetlistButton naming pattern exactly. RU: "Добавить трек" (matches existing трек terminology used elsewhere in the app). | ✓ |
| Other wording | Type your own key name and/or EN/RU text. | |

**User's choice:** homeAddTrackButton / "Add Track"
**Notes:** None — straightforward pick, matches existing sibling-key convention.

---

## publicapi.yml Songs tag

| Option | Description | Selected |
|--------|-------------|----------|
| Remove it now | It's dead — no operation references it, so deleting is zero-risk and doesn't touch any actual contract shape. Closes the last "song" reference in the API file without waiting on Phase 17. | |
| Leave it for Phase 17 | Phase 17 (API Contract Sync) is the dedicated phase for publicapi.yml changes; defer even this trivial cleanup to keep Phase 16 strictly client-code-only. | ✓ |
| Leave it permanently | publicapi.yml mirrors the backend spec as source of truth — client shouldn't edit it at all, even for unused tags. | |

**User's choice:** Leave it for Phase 17
**Notes:** Keeps Phase 16 strictly client-code-only; publicapi.yml stays untouched this phase.

---

## Test fixture data

| Option | Description | Selected |
|--------|-------------|----------|
| Rename to "Track..." | Consistency — avoids future confusion/greps turning up stale "song" hits in a codebase that's supposed to be fully renamed. Pure find-replace, no behavior change. | ✓ |
| Leave as-is | They're arbitrary placeholder data, not literally in scope per ROADMAP's success criteria (nav label, songs/ dir, SongsScreen class, ARB keys). Skip to reduce diff size. | |

**User's choice:** Rename to "Track..."
**Notes:** Applies to ~35 occurrences across 6 test files (setlists_provider_test.dart, setlist_detail_screen_test.dart, track_list_screen_test.dart, confirm_delete_track_dialog_test.dart, create_track_screen_test.dart, track_detail_screen_test.dart, cache_service_test.dart).

---

## Claude's Discretion

- Exact mechanics of the `lib/features/songs/` → `lib/features/tracks/` git move (`git mv` vs delete+recreate).
- Whether `flutter gen-l10n` is run as a discrete task step or bundled with the ARB edit.

## Deferred Ideas

- `lib/api/publicapi.yml`'s dangling `Songs` tag — deferred to Phase 17 (API Contract Sync), not dropped.
