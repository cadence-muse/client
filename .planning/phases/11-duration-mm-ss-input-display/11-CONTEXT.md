# Phase 11: Duration mm:ss Input + Display - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Users enter and view track duration as mm:ss everywhere in the app. Create/edit track forms auto-format the duration field as the user types and validate it; every screen that displays a duration (track or setlist, list or detail view) uses one consistent mm:ss format. `durationSeconds` on the wire is unchanged — conversion happens only at the input/display boundary. Independent of the i18n phases (12-14); no dependency either direction.

</domain>

<decisions>
## Implementation Decisions

### Canonical display format
- **D-01:** Unify on mm:ss with unbounded minutes (track's existing `asMinutesSeconds` extension in `lib/features/tracks/track_formatting.dart`) across every screen, including setlist totals (e.g. a 72-minute setlist shows `72:15`, not `1:12:15` or `72m 15s`). Setlist's words-based `"42m 35s"` format (`asMinutesAndSeconds` in `lib/features/setlists/setlist_formatting.dart`) is retired. No special-casing for totals over 60 minutes — plain mm:ss handles it since only the seconds component is bounded to 0-59. — **Reversibility:** costly — touches every screen that renders a track or setlist duration (list rows, detail views); reverting means re-diverging the two formats again.

### Auto-format typing mechanics
- **D-02:** Right-to-left stopwatch-style digit shift as the user types, via a custom `TextInputFormatter` (no external package) — e.g. `"2"` → `0:02`, `"230"` → `2:30`, `"2305"` → `23:05`.
- **D-03:** Cap the field at `99:59` maximum.
- **D-04:** Backspace deletes the last shifted digit and reformats (e.g. `2:30` + backspace → `0:23`) — it does not clear the whole field.

### Validation feedback UX
- **D-05:** Inline error text below the field, shown on submit attempt — not live per-keystroke. Matches the existing create/edit track form validation pattern (see WR-02 comments in `create_track_screen.dart`/`edit_track_screen.dart`). The auto-formatter (D-02) prevents most malformed states by construction; the remaining rejectable case is an incomplete entry left at submit time.

### Empty/optional duration handling
- **D-06:** Blank field stays valid/optional and submits as `null` `durationSeconds` — no behavior change from today's `int.tryParse(...)` optional handling. The auto-formatter only activates once the user types a digit.

### Claude's Discretion
None — all four areas reached explicit decisions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — DUR-01 through DUR-04 (source requirements for this phase); Out of Scope table excludes HH:mm:ss format (no tracks exceed 1hr) and confirms mm:ss is sufficient
- `.planning/ROADMAP.md` §"Phase 11: Duration mm:ss Input + Display" — goal, success criteria, "Depends on: Nothing"

### Research
- `.planning/research/SUMMARY.md` §"Phase B: Duration mm:ss Input + Display" — recommended approach, `DurationFormatter`/`parseMMSStoSeconds` naming, convergence note
- `.planning/research/PITFALLS.md` §Pitfall 5 ("Duration Input Parsing Accepts Invalid Formats"), §Pitfall 9 ("Duration Display vs. Duration Input Format Mismatch") — concrete edge cases to test (`"5:60"`, `"-1:30"`, `":"`, paste `"60"`) and the format-convergence rationale behind D-01

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/tracks/track_formatting.dart`'s `DurationFormatting.asMinutesSeconds` extension — becomes the single canonical display format (D-01); reused as-is, no changes needed to its logic
- `lib/features/tracks/create_track_screen.dart` / `edit_track_screen.dart` — existing `_durationController` (`TextEditingController`) and WR-02 validation-comment pattern to extend, not replace

### Established Patterns
- Optional-field pattern: `durationSeconds: int.tryParse(_durationController.text.trim())` — null on empty/unparseable, already matches D-06
- Update screens must always send all editable fields on submit (not conditional), per PROJECT.md Key Decisions — applies to `edit_track_screen.dart`'s duration field too

### Integration Points
- `lib/features/setlists/setlist_formatting.dart` — `asMinutesAndSeconds` and `tracksAndDuration` need to be updated/removed per D-01; `tracksAndDuration` is reused unmodified elsewhere (per its own doc comment) so callers need checking
- Duration is read/written in: `create_track_screen.dart`, `edit_track_screen.dart`, `track_list_screen.dart`, `track_detail_screen.dart`, `tracks_screen.dart`, `setlist_list_screen.dart`, `setlist_detail_screen.dart`, `setlists_screen.dart`, `add_setlist_tracks_dialog.dart`, `setlists_provider.dart`, `lib/api/public_api.dart`

</code_context>

<specifics>
## Specific Ideas

No specific UI mockups or copy requested — user deferred to recommended options throughout (stopwatch-style shift, 99:59 cap, submit-time inline validation, unchanged optional behavior).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-Duration mm:ss Input + Display*
*Context gathered: 2026-08-25*
