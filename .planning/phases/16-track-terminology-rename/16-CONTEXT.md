# Phase 16: Track Terminology Rename - Context

**Gathered:** 2026-08-27
**Status:** Ready for planning

<domain>
## Phase Boundary

RENAME-01: eliminate the last remaining "song" references so the app is fully "track"-named. Codebase scout during discussion found most of the rename **already done** in prior phases: the bottom-nav tab (`navTracks`), the `TracksScreen` class, and the file `tracks_screen.dart` are all already track-named. No `SongsScreen` class exists anywhere.

**What's actually left (client-code only, this phase):**
1. `lib/features/songs/` directory still holds `tracks_screen.dart` (the file itself is correctly named — only the parent directory is stale) — must be merged into the already-existing `lib/features/tracks/` directory (which holds the per-band track CRUD screens), with the import in `lib/navigation/root_scaffold.dart` updated to match.
2. One stale ARB key: `homeAddSongButton` (EN "Add Song" / RU "Добавить песню") — the homepage quick-action button for adding a track.
3. Doc/inline comments in `lib/features/home/home_screen.dart` and `lib/features/home/band_picker_sheet.dart` that say "Add Song" — internal references per REQUIREMENTS.md's "no user-facing or internal 'song' references" wording.
4. Test files that reference the old `songs/` import path or the old ARB getter, plus ~35 fixture-data occurrences of "Song One"/"My Song"/"Cached Song" etc. used as arbitrary sample track-title text.

**Explicitly NOT in this phase's scope:** `lib/api/publicapi.yml`'s dangling, unused `Songs` tag (see D-04) — deferred to Phase 17 (API Contract Sync), which owns all `publicapi.yml` changes.

No new capabilities. No behavior changes — this is a pure rename/cleanup sweep.

</domain>

<decisions>
## Implementation Decisions

### Directory Consolidation
- **D-01:** Move `lib/features/songs/tracks_screen.dart` into `lib/features/tracks/`, delete the now-empty `songs/` directory, and update the single import site (`lib/navigation/root_scaffold.dart:8`). The file itself (`TracksScreen` class) is already correctly named — this is a pure directory merge, no class/file rename needed. — **Reversibility:** reversible — a directory move + one import update, trivially undoable.

### ARB Key Rename
- **D-02:** Rename `homeAddSongButton` → `homeAddTrackButton`, matching the sibling key naming pattern (`homeAddBandButton`, `homeAddSetlistButton`). New values: EN "Add Track", RU "Добавить трек" (matches the "трек" terminology already used everywhere else in the app, e.g. `trackCount`, `commonAddTracks`). Update the single usage site (`lib/features/home/home_screen.dart:145`, `l10n.homeAddSongButton` → `l10n.homeAddTrackButton`) and regenerate localization artifacts (`flutter gen-l10n`) so `lib/generated/app_localizations*.dart` picks up the new getter with no stale `homeAddSongButton` remaining.

### Comment Sweep
- **D-03:** Update the "Add Song" references in code comments (`lib/features/home/home_screen.dart:66,128`, `lib/features/home/band_picker_sheet.dart:9`) to "Add Track" — these are internal references and REQUIREMENTS.md's RENAME-01 wording covers "internal" references, not just user-facing strings.

### publicapi.yml Songs Tag — Deferred
- **D-04:** The dangling `Songs` tag in `lib/api/publicapi.yml`'s top-level `tags:` list (declared at line 10, referenced by zero operations — a dead leftover) is explicitly **out of scope for Phase 16**. User's call: `publicapi.yml` changes belong to Phase 17 (API Contract Sync), keeping Phase 16 strictly client-code-only. Do not touch this file in Phase 16.

### Test Fixture Data
- **D-05:** Rename the ~35 occurrences of arbitrary sample track-title text ("Song One", "Song Two", "My Song", "Cached Song", "Song Three") across `test/providers/setlists_provider_test.dart`, `test/features/setlists/setlist_detail_screen_test.dart`, `test/features/tracks/track_list_screen_test.dart`, `test/features/tracks/confirm_delete_track_dialog_test.dart`, `test/features/tracks/create_track_screen_test.dart`, `test/features/tracks/track_detail_screen_test.dart`, and `test/cache/cache_service_test.dart` to their "Track"-equivalent text (e.g. "Track One", "My Track", "Cached Track"). Pure find-replace on string literal test data, no behavior change — chosen over leaving them for consistency and to avoid stale "song" hits surviving a grep of an otherwise fully-renamed codebase.
- **D-06:** Test files that reference actual renamed identifiers must be updated as a forced consequence of D-01/D-02 (not a separate judgment call): `test/features/tracks/tracks_screen_test.dart:6`'s import (`package:cadence/features/songs/tracks_screen.dart` → `package:cadence/features/tracks/tracks_screen.dart`), `test/regression/offline_trust_regression_test.dart:34`'s path string literal (`'lib/features/songs/tracks_screen.dart'` → `'lib/features/tracks/tracks_screen.dart'`), and `test/features/home/home_screen_test.dart`'s five `tester.strings.homeAddSongButton` call sites (→ `homeAddTrackButton`) plus its local variable/description text ("Add Song" → "Add Track").

### Claude's Discretion
- Exact mechanics of the `lib/features/songs/` → `lib/features/tracks/` git move (e.g. whether to use `git mv` vs delete+recreate) — either is fine as long as the file content and class are unchanged.
- Whether `flutter gen-l10n` is run as a discrete task step or bundled with the ARB edit — executor's call.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — RENAME-01 definition ("No user-facing or internal 'song' references remain").
- `.planning/ROADMAP.md` §"Phase 16" — 4 success criteria (nav/screen text, no `songs/` dir or `Song`-prefixed class, no ARB "song" content, clean test suite with no stale `.g.dart` artifacts).

### API Contract (do not touch this phase)
- `lib/api/publicapi.yml` — line 10 has the dangling `Songs` tag. Confirmed via grep that no `tags: [ ... ]` operation entry references it (only `Users` and `Bands` tags are actually used). Leave untouched per D-04; Phase 17 owns this file.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/tracks/` already exists with the per-band track CRUD screens (`track_list_screen.dart`, `track_detail_screen.dart`, `create_track_screen.dart`, `confirm_delete_track_dialog.dart`, `track_formatting.dart`) — the merge target for D-01, already correctly named, no restructuring needed there.

### Established Patterns
- ARB sibling-key naming: `homeAddBandButton` / `homeAddSetlistButton` — `homeAddTrackButton` (D-02) follows this exactly.
- RU terminology: "трек" is the established Russian word for "track" throughout the ARB files (`trackCount`, `navTracks` = "Треки", `commonAddTracks` = "Добавить треки", `commonEnterTrackTitle`) — D-02's "Добавить трек" matches.

### Integration Points
- `lib/navigation/root_scaffold.dart:8` — sole import of `../features/songs/tracks_screen.dart`, must be updated for D-01.
- `lib/features/home/home_screen.dart:145` — sole call site of `l10n.homeAddSongButton`, must be updated for D-02.
- `lib/generated/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` — regenerated by `flutter gen-l10n`, not hand-edited; will pick up D-02's rename automatically once the ARB source files change.

</code_context>

<specifics>
## Specific Ideas

No UI mockups or external references — this is a mechanical rename/cleanup phase. Exact wording for the renamed ARB key is locked in D-02.

</specifics>

<deferred>
## Deferred Ideas

- `lib/api/publicapi.yml`'s dangling `Songs` tag — explicitly deferred to Phase 17 (API Contract Sync) per D-04, not dropped.

None else — discussion stayed within phase scope.

</deferred>

---

*Phase: 16-Track Terminology Rename*
*Context gathered: 2026-08-27*
