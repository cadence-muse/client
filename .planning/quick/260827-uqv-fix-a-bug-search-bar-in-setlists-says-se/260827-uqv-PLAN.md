---
type: quick
slug: 260827-uqv-fix-a-bug-search-bar-in-setlists-says-se
autonomous: true
files_modified:
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - lib/features/setlists/setlists_screen.dart
  - test/features/setlists/setlists_screen_test.dart
must_haves:
  truths:
    - "The Setlists tab search field's hint text describes searching by name, not by artist or title"
    - "The Tracks tab and Add-tracks-to-setlist dialog search hints are unchanged (they legitimately search by title/artist)"
  artifacts:
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
  key_links:
    - "setlists_screen.dart TextField.decoration.hintText -> new l10n key -> ARB source string"
---

<objective>
Fix a copy bug: the Setlists tab search bar shows "Search by title or artist" (via the shared
`addSetlistTracksSearchHint` l10n key), but setlists only have a `name` field — there is no
artist or title to search by. Give the Setlists tab its own hint key describing search-by-name,
while leaving the Tracks tab and the "Add tracks to setlist" dialog untouched since those
legitimately search by title/artist.

This is a known, previously-flagged issue (17-REVIEW.md WR-02, logged in STATE.md Blockers/Concerns).

Purpose: Copy accuracy — users should not be told a search searches fields that don't exist.
Output: New `setlistsTabSearchHint` l10n key ("Search by name" / ru equivalent), wired into
`setlists_screen.dart`'s search TextField; `addSetlistTracksSearchHint` remains used only by
`tracks_screen.dart` and `add_setlist_tracks_dialog.dart`.
</objective>

<execution_context>
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/workflows/execute-plan.md
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/templates/summary.md
</execution_context>

<context>
@/home/bulat.khafizov/projects/personal/cadence/client/.planning/STATE.md
@/home/bulat.khafizov/projects/personal/cadence/client/lib/features/setlists/setlists_screen.dart
@/home/bulat.khafizov/projects/personal/cadence/client/lib/l10n/app_en.arb
@/home/bulat.khafizov/projects/personal/cadence/client/lib/l10n/app_ru.arb
@/home/bulat.khafizov/projects/personal/cadence/client/test/features/setlists/setlists_screen_test.dart
@/home/bulat.khafizov/projects/personal/cadence/client/test/test_strings.dart

Existing bug location: `setlists_screen.dart` line ~124 sets
`hintText: l10n.addSetlistTracksSearchHint` on the Setlists tab's search `TextField`. That same
key is shared with `tracks_screen.dart:117` and `add_setlist_tracks_dialog.dart:194`, both of
which are correct (tracks have both a title and an artist field). Only the Setlists tab usage is
wrong, because `Setlist` (see `lib/api/models/setlist.dart` if present, or the setlist list item
shape returned by `listUserSetlists`) exposes only a `name` field, not title/artist.

The ARB source strings live in `lib/l10n/app_en.arb` (line 254 for the existing key) and
`lib/l10n/app_ru.arb` (line 254). Follow the existing naming convention for this screen's other
keys — `setlistsTabEmptyTitle` / `setlistsTabEmptyDescription` (both in `app_en.arb` around line
241-242) — for the new key name: `setlistsTabSearchHint`.

Generated l10n files (`lib/generated/app_localizations*.dart`) are produced by `flutter gen-l10n`
per `l10n.yaml` (`generate: true` in `pubspec.yaml`) — do not hand-edit the generated getters if
`flutter gen-l10n` is available in this environment; run the generator instead so the generated
files stay byte-for-byte consistent with the ARB source. `flutter` is at
`/home/bulat.khafizov/software/flutter/bin/flutter`.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add setlistsTabSearchHint l10n key and wire it into the Setlists tab search field</name>
  <files>lib/l10n/app_en.arb, lib/l10n/app_ru.arb, lib/generated/app_localizations.dart, lib/generated/app_localizations_en.dart, lib/generated/app_localizations_ru.dart, lib/features/setlists/setlists_screen.dart</files>
  <action>
    In `lib/l10n/app_en.arb`, add a new key `setlistsTabSearchHint` with value "Search by name",
    placed near the other `setlistsTab*` keys (`setlistsTabEmptyTitle`,
    `setlistsTabEmptyDescription`) for consistency, not next to `addSetlistTracksSearchHint`.
    In `lib/l10n/app_ru.arb`, add the matching key with a Russian translation meaning "Search by
    name" (e.g. "Поиск по названию" — follow the existing Russian phrasing style used for
    `setlistsTabEmptyTitle`/`setlistsTabEmptyDescription` in that file). Do not add an
    `@setlistsTabSearchHint` metadata block — the existing `addSetlistTracksSearchHint` key has
    none, so match that precedent.

    Regenerate the localization getters by running `flutter gen-l10n` (or `flutter pub get` if
    that also triggers generation in this Flutter version) from the project root so
    `lib/generated/app_localizations.dart`, `app_localizations_en.dart`, and
    `app_localizations_ru.dart` pick up the new `setlistsTabSearchHint` getter. If the generator
    is unavailable in this environment, hand-edit the three generated files to add the getter in
    the same pattern as the existing `addSetlistTracksSearchHint` getter (abstract declaration in
    `app_localizations.dart`, and concrete overrides in `app_localizations_en.dart`/
    `app_localizations_ru.dart`), keeping alphabetical/existing ordering consistent with
    surrounding getters.

    In `lib/features/setlists/setlists_screen.dart`, change the Setlists tab's search `TextField`
    `decoration.hintText` from `l10n.addSetlistTracksSearchHint` to `l10n.setlistsTabSearchHint`
    (around line 124). Do not touch `tracks_screen.dart` or `add_setlist_tracks_dialog.dart` —
    both still correctly search by title/artist and must keep using
    `l10n.addSetlistTracksSearchHint`.
  </action>
  <verify>
    <automated>cd /home/bulat.khafizov/projects/personal/cadence/client && grep -n "setlistsTabSearchHint" lib/l10n/app_en.arb lib/l10n/app_ru.arb lib/generated/app_localizations.dart lib/generated/app_localizations_en.dart lib/generated/app_localizations_ru.dart lib/features/setlists/setlists_screen.dart && grep -c "l10n.addSetlistTracksSearchHint" lib/features/setlists/setlists_screen.dart | grep -qx 0</automated>
    <human-check>Run the app, open the Setlists tab, and confirm the search field's placeholder now reads "Search by name" (not "Search by title or artist"); open the Tracks tab and the "Add tracks" dialog and confirm both still read "Search by title or artist".</human-check>
  </verify>
  <done>
    `setlistsTabSearchHint` exists in both ARB files and all three generated l10n files with an
    English value of "Search by name" (and a Russian translation). `setlists_screen.dart`'s
    search `TextField` hint uses `l10n.setlistsTabSearchHint` and no longer references
    `l10n.addSetlistTracksSearchHint`. `tracks_screen.dart` and `add_setlist_tracks_dialog.dart`
    are unchanged and still use `l10n.addSetlistTracksSearchHint`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update the Setlists screen test to assert the new hint and confirm no regressions</name>
  <files>test/features/setlists/setlists_screen_test.dart</files>
  <action>
    In `test/features/setlists/setlists_screen_test.dart` (around line 610), change
    `find.text(tester.strings.addSetlistTracksSearchHint)` to
    `find.text(tester.strings.setlistsTabSearchHint)` — this is the assertion that checks the
    Setlists tab search field's hint text is rendered above the setlist list. Leave every other
    assertion in the file untouched.

    Run the full test suite for the three affected screens/dialog to confirm the rename didn't
    break sibling coverage: `setlists_screen_test.dart` (uses the new key),
    `tracks_screen_test.dart` and `add_setlist_tracks_dialog_test.dart` (must still pass unchanged
    since they keep using `addSetlistTracksSearchHint`). Also run `flutter analyze` to catch any
    stale reference to the old key or unused-import fallout from the generated-file regeneration.
  </action>
  <verify>
    <automated>cd /home/bulat.khafizov/projects/personal/cadence/client && flutter test test/features/setlists/setlists_screen_test.dart test/features/tracks/tracks_screen_test.dart test/features/setlists/add_setlist_tracks_dialog_test.dart</automated>
  </verify>
  <done>
    All three test files pass. `setlists_screen_test.dart` asserts against
    `tester.strings.setlistsTabSearchHint`; `tracks_screen_test.dart` and
    `add_setlist_tracks_dialog_test.dart` still assert against
    `tester.strings.addSetlistTracksSearchHint` unchanged. `flutter analyze` reports no new
    issues introduced by this change.
  </done>
</task>

</tasks>

<verification>
1. `grep -rn "addSetlistTracksSearchHint" lib/features/setlists/setlists_screen.dart` returns
   nothing (the Setlists tab no longer uses the tracks/artist hint key).
2. `grep -rn "setlistsTabSearchHint" lib/` shows the new key present in both ARB files and all
   three generated l10n files, and consumed exactly once in `setlists_screen.dart`.
3. `flutter test test/features/setlists/ test/features/tracks/tracks_screen_test.dart` passes.
4. `flutter analyze` is clean (no new warnings/errors from this change).
</verification>

<success_criteria>
- Setlists tab search field hint text describes searching by name (not title/artist).
- Tracks tab and "Add tracks to setlist" dialog search hints are unchanged (still title/artist).
- New `setlistsTabSearchHint` l10n key exists in `app_en.arb`, `app_ru.arb`, and all three
  generated `app_localizations*.dart` files.
- Updated test assertion passes; sibling test files (`tracks_screen_test.dart`,
  `add_setlist_tracks_dialog_test.dart`) remain green.
- `flutter analyze` clean.
</success_criteria>

<output>
Create `.planning/quick/260827-uqv-fix-a-bug-search-bar-in-setlists-says-se/260827-uqv-SUMMARY.md`
when done, with `status: complete` in frontmatter.
</output>