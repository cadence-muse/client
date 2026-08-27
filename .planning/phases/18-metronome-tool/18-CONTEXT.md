# Phase 18: Metronome Tool - Context

**Gathered:** 2026-08-27
**Status:** Ready for planning

<domain>
## Phase Boundary

A metronome tool: audio tick synced to a visual pulse in 4/4 time (accented first beat), tempo adjustable via a large round drag-to-set selector plus ±1/±5 quick-adjust buttons, defaulting to 120 BPM. Reachable from a new "Tools" section on the Homepage, and from a track's detail screen (prefilled with that track's tempo, when the track has one).

</domain>

<decisions>
## Implementation Decisions

### Audio tick source
- **D-01:** Use `audioplayers` for tick playback — has an explicit low-latency player mode built for rapid short-sound retriggering, which fits a metronome's repeated-tick use case better than `just_audio`. New dependency; not currently in `pubspec.yaml`. — **Reversibility:** costly — **rationale:** swapping audio packages later means re-plumbing every play-tick call site and re-testing timing/latency behavior on both platforms.
- **D-02:** User will supply the tick sound asset files themselves (not Claude-sourced or synthesized). Until provided, Claude ships with placeholder tones (e.g. simple generated/stock click sounds) at a documented, stable asset path so the user can drop in real files later without any code changes.
- **D-03:** Beat 1 (accent) and beats 2-4 use **different sound files** (distinct pitch), not just a volume difference — two tick assets needed total (accent + regular).
- **D-04:** When tempo changes while playing, the new interval takes effect **immediately on the next tick** — no waiting for the current bar to finish.

### Tempo selector interaction
- **D-05:** The large round tempo selector is a **drag/rotate dial** — the user drags a finger around the circle's circumference like an analog dial to change BPM. Needs custom gesture math (angle → BPM) and a `CustomPainter`; no existing drag/dial pattern in the codebase to reuse — this is greenfield UI. — **Reversibility:** costly — **rationale:** replacing the interaction model later (e.g. to vertical-drag or tap-only) means rewriting the gesture handling and likely the visual layout around it.
- **D-06:** BPM range: **40–300**.
- **D-07:** The BPM number (and the audible tick interval, if playing) updates **live while dragging**, not only on gesture release.
- **D-08:** The metronome does **not** auto-start on screen open — it opens paused/silent; the user taps an explicit play control to start ticking.

### Visual pulse & accent design
- **D-09:** The beat pulse is shown via a **separate row of 4 beat-indicator dots** below the dial (not the dial itself flashing) — each dot lights up in sequence as its beat plays, showing "where in the bar" the user is.
- **D-10:** Beat 1's dot is visually distinct from beats 2-4 dots in **both color and size** (larger + accent color) — matches the audio accent (distinct pitch) with an equally strong visual accent.

### No-tempo track fallback
- **D-11:** If a track has **no tempo set** (`tempo` is null), the "open metronome" entry point on that track's detail screen is **not shown** at all — no button, no fallback-to-120 prefill. The metronome is only reachable from a track's detail screen when that track has a tempo value. (The Homepage "Tools" entry always defaults to 120 BPM regardless — this rule only affects the track-detail entry point.)

### Claude's Discretion
- Exact drag-to-BPM angle mapping / sensitivity curve for the dial gesture.
- Dial visual styling (colors, size, ring thickness) within the app's existing theme.
- Placeholder tick sound choice (until user supplies real files) — any short, unobtrusive click/blip is acceptable.
- Placement/label of the play/pause control relative to the dial.
- Exact asset path/filenames for the tick sound files (document clearly so the user knows where to drop replacements).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — METR-01 through METR-04 under the metronome section
- `.planning/ROADMAP.md` §"Phase 18: Metronome Tool" — goal and 4 success criteria

### API contract
- `lib/api/publicapi.yml` — track schema `tempo` field (lines ~932, ~963, ~984) — nullable int, BPM. No API changes needed this phase; metronome is a local/offline-capable tool reading an already-fetched track's `tempo`.

No external specs beyond the above — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/home/home_screen.dart` — existing Homepage layout (welcome card + "Quick Actions" `Wrap` of `ElevatedButton.icon`s at lines ~120-155). The new "Tools" section should follow this same header + button-row pattern for visual consistency, added as a new section below Quick Actions.
- `lib/features/tracks/track_detail_screen.dart:79,104-107` — `tempo` is already read (`track['tempo'] as int?`) and conditionally displayed (`if (tempo != null)`). The same null-check gates whether the metronome entry point appears (D-11).
- `lib/features/tracks/track_detail_screen.dart:34-53` — `AppBar.actions` pattern for an `IconButton` (used for Edit) — a natural spot to add a metronome-launch action, conditional on `tempo != null`.

### Established Patterns
- No existing `CustomPainter`, drag-gesture, or round-dial widget anywhere in `lib/` — the tempo selector (D-05) is new UI infrastructure for this app, not a reuse of an existing pattern.
- No audio-playback package currently in `pubspec.yaml` — `audioplayers` (D-01) will be a new dependency.
- Riverpod (`flutter_riverpod`) is the app's state management convention — a metronome playback provider (BPM, playing/paused, current beat) should follow the existing provider patterns in `lib/providers/`.

### Integration Points
- Homepage: new "Tools" section/button in `home_screen.dart`, navigating to the metronome screen with a default BPM of 120.
- Track detail: new conditional `AppBar` action (or similar) in `track_detail_screen.dart`, navigating to the metronome screen prefilled with `track['tempo']`, shown only when `tempo != null` (D-11).
- `pubspec.yaml` needs `audioplayers` added, plus an `assets:` entry for the tick sound files once the metronome screen and its asset path are built.

</code_context>

<specifics>
## Specific Ideas

No specific dial visual mockup was requested — user confirmed drag-to-rotate as the interaction model and left exact styling to Claude's discretion. User will supply the actual tick sound files post-implementation; Claude ships placeholders in the meantime (D-02).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. No scope-creep suggestions arose.

</deferred>

---

*Phase: 18-Metronome Tool*
*Context gathered: 2026-08-27*
