# Phase 9: Homepage Quick Actions - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can jump straight from the Homepage into creating a band, song, or setlist without extra navigation. HOME-01 (Add band → direct to band-creation screen), HOME-02 (Add song / Add setlist → band-picker dialog first, then to the chosen band's create screen). No new capabilities beyond these three quick actions and the picker they share — this is additive UI on the existing Home screen, reusing existing create screens (`CreateBandScreen`, `CreateTrackScreen`, `CreateSetlistScreen`) and the existing bands-list data provider. Not a redesign of `bands_screen.dart`'s own Create/Join FAB.

</domain>

<decisions>
## Implementation Decisions

### Home screen layout

- **D-01:** Home screen is restructured: welcome text (`Welcome, $username`) moves into a rounded-rectangle card at the top of the screen — sized/styled to leave room for a future user avatar in the greeting (not built this phase, just don't crowd it out). Below the card, a "Quick Actions" section header, then the 3 quick-action buttons.
- **D-02:** The 3 quick actions render as a **button row** (not a FAB+bottom-sheet menu, not AppBar icons) — each button shows an **icon + label** (e.g. `+ Add band`), consistent with the app's existing text+icon button style.
- **D-03:** This layout applies uniformly to **both** the zero-bands and populated states — it replaces the current zero-bands-only "No bands yet... Create Band" block entirely (`home_screen.dart`'s existing `bandsCount == 0` branch). One layout, not two.
- **D-04:** `bands_screen.dart`'s existing FAB + `_showCreateJoinMenu` bottom sheet (Create band / Join band) is **untouched** — Home's quick actions are an additional, independent entry point to the same `CreateBandScreen`, not a replacement.

### Band-picker (Add song / Add setlist)

- **D-05:** Picker UI is a **bottom sheet** with one `ListTile` per band, showing **band name only** (no member count/role badge) — matches the visual weight of `bands_screen.dart`'s existing `_showCreateJoinMenu` bottom sheet.
- **D-06:** Picker's band list is backed by the **existing `bandsListDataProvider`** (same provider `bands_screen.dart` watches) — no separate fetch call, no new provider. Works offline the same way the rest of the app does post-Phase-7: serves cache, relies on the existing global offline banner for staleness — no picker-specific offline handling needed.
- **D-07:** The picker **always shows**, even when the user has exactly 1 band — no auto-skip-to-create-screen shortcut for the single-band case. Consistent behavior regardless of band count.
- **D-08:** Dismissing the bottom sheet without picking a band (tap outside / back) just closes it — no error, no snackbar, user stays on Home. Standard Flutter bottom-sheet dismiss behavior, nothing custom to build.

### Zero-band handling

- **D-09:** "Add song" and "Add setlist" are **disabled** (not hidden, not tappable-with-a-message) whenever `bandsCount == 0` — only "Add band" is enabled in that state. This is a plain disabled-button state, no explanatory dialog/snackbar needed since the disabled visual state itself communicates it.
- **D-10:** All 3 buttons **always render** regardless of band count — nothing is conditionally hidden from the layout; only the enabled/disabled state of Add song/Add setlist changes with `bandsCount`.

### Navigation

- **D-11:** "Add band" → `Navigator.push` directly to `CreateBandScreen` (no picker, matches `bands_screen.dart`'s existing push pattern). "Add song" / "Add setlist" → open the band-picker bottom sheet; on selection, `Navigator.push` to `CreateTrackScreen(bandId: ...)` / `CreateSetlistScreen(bandId: ...)`. All three are direct `MaterialPageRoute` pushes, same as `bands_screen.dart`'s existing navigation — no intermediate confirmation step.
- **D-12:** No new refresh wiring needed on Home for after a successful create. `homepageDataProvider` already invalidates on every Home tab-switch (Phase 7 D-01, `selectedTabIndexProvider` listener in `home_screen.dart`) — since the create screens navigate to a detail screen (not back to Home directly), the user re-entering the Home tab later gets a naturally fresh `bandsCount` for free. Nothing to build for this.

### Claude's Discretion

- Exact Material icons for the 3 quick-action buttons (Add band / Add song / Add setlist) — no icon mandated beyond "icon + label," pick semantically clear standard Material icons (e.g. `Icons.group_add`, `Icons.music_note`, `Icons.playlist_add`).
- Rounded-rectangle welcome-card styling specifics (corner radius, padding, elevation/color) — leave room for a future avatar widget in the greeting row, but exact visual treatment is Claude's call, consistent with the app's existing Material theme.
- Exact button widget type for the quick-action row (`ElevatedButton.icon`, `OutlinedButton.icon`, `FilledButton.icon`, etc.) and how 3 buttons lay out on narrow screens (wrap vs. equal-width row vs. `Wrap` widget) — mechanical widget choice, no design decision attached beyond D-02's "icon + label" requirement.
- Exact bottom-sheet builder structure for the band-picker (matching `bands_screen.dart`'s `_showCreateJoinMenu` shape) — mechanical, no design decision attached beyond D-05.

</decisions>

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml` — no schema changes needed this phase; homepage summary (`GET /api/homepage` → `bandsCount`) and existing Create Band/Track/Setlist endpoints are used as-is.

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — HOME-01, HOME-02 (full acceptance text)
- `.planning/ROADMAP.md` §"Phase 9: Homepage Quick Actions" — success criteria (3 criteria: Add band lands directly on band-creation; Add song shows band-picker then lands on that band's create-track screen; Add setlist shows band-picker then lands on that band's create-setlist screen), depends-on Phase 6 (reuses Bands list data for the picker), independent of Phases 7-8
- `.planning/PROJECT.md` — v1.1 milestone goal; Key Decisions table documents the online-first cache model (Phase 7) that `bandsListDataProvider`/`homepageDataProvider` already follow, and the local-patch/invalidate conventions from Phase 8 (not directly needed here since this phase adds no new mutations beyond existing create flows)
- `.planning/STATE.md` — confirms Phase 9 is independent/low-touch, sequenced after foundational phases per research recommendation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/home/home_screen.dart` (full file) — current Home screen; `_buildContent` is where the welcome-card + quick-actions restructure (D-01/D-03) lands; `homepageDataProvider` and its existing tab-switch-refresh listener (`selectedTabIndexProvider`) stay as-is.
- `lib/features/bands/bands_screen.dart`'s `_showCreateJoinMenu` (bottom-sheet builder with `ListTile`s, `showModalBottomSheet<void>`) — direct template for the new band-picker bottom sheet (D-05) and for the quick-action button row's general "additive entry point" posture (D-04).
- `lib/features/bands/join_band_dialog.dart` — pattern reference for a dialog/sheet triggering `Navigator.push` to a downstream screen only after the sheet/dialog closes (its `_JoinOutcome`-then-push-outside-the-dialog structure), relevant to how the band-picker should hand off to `CreateTrackScreen`/`CreateSetlistScreen` after `Navigator.pop` returns a selected bandId.
- `lib/features/bands/create_band_screen.dart`, `lib/features/tracks/create_track_screen.dart` (`required this.bandId`), `lib/features/setlists/create_setlist_screen.dart` (`required this.bandId`) — existing create screens, used unmodified; only `bandId` needs to be threaded from the picker.
- `lib/providers/bands_provider.dart` (`bandsListDataProvider`) — existing online-first cached band list provider, reused as-is for the picker's data source (D-06); no new provider needed.

### Established Patterns
- Tab screens re-fetch via a `ref.listen<int>(selectedTabIndexProvider, ...)` block that invalidates their data provider on tab re-entry (Phase 7 D-01) — already present in `home_screen.dart`, unaffected by this phase's changes (D-12).
- `AsyncValue.when()` + `_buildError`/offline-no-cache-view branches are the established loading/error shape across all tab screens — `home_screen.dart`'s existing `homeAsync.when(...)` structure is reused, only its `data:` branch content changes (D-01/D-03).
- List/detail navigation everywhere in the app uses `Navigator.of(context).push(MaterialPageRoute(builder: (_) => XScreen(...)))` — no named routes, no go_router — the quick actions and post-picker navigation follow this exact shape (D-11).

### Integration Points
- `lib/features/home/home_screen.dart` — primary file changed; new button-row widget + band-picker bottom-sheet trigger, both added here.
- New band-picker bottom sheet likely lives alongside `home_screen.dart` (e.g. a private widget/function in the same file, or a small new `lib/features/home/band_picker_sheet.dart` if kept separate) — mirrors how `join_band_dialog.dart` is its own file next to `bands_screen.dart`; planner's call on file split.
- No new provider, no new API method, no `publicapi.yml` changes — this phase only adds UI wiring on top of existing screens/providers.

</code_context>

<specifics>
## Specific Ideas

- Welcome text goes into "a rounded rectangle" card — user's own words — specifically to leave room for a future user avatar in the greeting (not built this phase, just accounted for in the layout).
- Quick actions section gets an explicit "Quick Actions" header between the welcome card and the button row.
- Icon + label style for buttons: "the copy icon and rotate icon" style consistency isn't relevant here (that was Phase 8), but the same general principle — icon plus visible text, not icon-only — carries over from this phase's own D-02 answer.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The searchable setlist track picker is already scoped to Phase 10 per ROADMAP.md, not this phase. The future user-avatar-in-greeting idea was noted as a layout constraint (D-01) but is not being built this phase — no dedicated future phase exists for it yet since it wasn't raised as a concrete ask, just a "leave room for" note.)

</deferred>

---

*Phase: 9-Homepage Quick Actions*
*Context gathered: 2026-08-22*
