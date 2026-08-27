# Phase 18: Metronome Tool - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-27
**Phase:** 18-Metronome Tool
**Areas discussed:** Audio tick source, Tempo selector interaction, Visual pulse & accent design, No-tempo track fallback

---

## Audio tick source

| Option | Description | Selected |
|--------|-------------|----------|
| audioplayers | Explicit low-latency player mode for rapid short-sound retriggering | ✓ |
| just_audio | More feature-rich, heavier, not optimized for rapid retriggering | |

**User's choice:** audioplayers
**Notes:** None.

| Option | Description | Selected |
|--------|-------------|----------|
| Claude sources a simple click/woodblock asset | Free/CC0 percussion click bundled as asset | |
| I'll provide the sound file(s) | User supplies asset files; Claude wires them in | ✓ |
| Synthesize a tone at runtime | Generate a sine/square blip in-code | |

**User's choice:** I'll provide the sound file(s)
**Notes:** Follow-up question asked: what happens if planning/execution starts before files are supplied.

| Option | Description | Selected |
|--------|-------------|----------|
| Claude uses placeholder tones, swap later | Ship with placeholder click now; user drops in real files at documented path later | ✓ |
| Block on asset files before planning | Pause phase work until user provides both sound files | |

**User's choice:** Claude uses placeholder tones, swap later

| Option | Description | Selected |
|--------|-------------|----------|
| Same sound, louder volume | One tick asset, beat 1 plays louder | |
| Different pitch/sound file | Two tick assets (high tone beat 1, low tone beats 2-4) | ✓ |

**User's choice:** Different pitch/sound file

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately, next tick | New interval applies on the very next scheduled tick | ✓ |
| At the start of the next bar | Current bar finishes at old tempo, new tempo starts on beat 1 | |

**User's choice:** Immediately, next tick

---

## Tempo selector interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Drag/rotate around the circle | Finger drags around dial circumference like an analog dial | ✓ |
| Vertical drag (slider-in-a-circle) | Drag up/down anywhere on the circle | |
| Tap-only, display + separate steppers | Circle is a static display; all adjustment via ±1/±5 buttons | |

**User's choice:** Drag/rotate around the circle

| Option | Description | Selected |
|--------|-------------|----------|
| 40–240 BPM | Standard full metronome range | |
| 30–300 BPM | Wider safety margin | |
| You decide | Leave bounds to Claude | |

**User's choice:** Free text — "40 - 300 BPM" (custom range combining both suggested bounds)

| Option | Description | Selected |
|--------|-------------|----------|
| Live while dragging | BPM number and ticking update continuously during drag | ✓ |
| Only on release | Number fixed during drag, updates on finger lift | |

**User's choice:** Live while dragging

| Option | Description | Selected |
|--------|-------------|----------|
| Wait for explicit play tap | Screen opens paused/silent | ✓ |
| Auto-start on open | Ticking begins immediately on screen open | |

**User's choice:** Wait for explicit play tap

---

## Visual pulse & accent design

| Option | Description | Selected |
|--------|-------------|----------|
| The dial itself flashes/scales | The round tempo selector changes color/scale on each beat | |
| Separate row of 4 beat dots below the dial | Dedicated row of 4 indicator dots lights up in sequence | ✓ |

**User's choice:** Separate row of 4 beat dots below the dial

| Option | Description | Selected |
|--------|-------------|----------|
| Different color | Beat 1 pulses in accent color, beats 2-4 in neutral color | |
| Different size/scale | Beat 1 pulses bigger, same color throughout | |
| Both color and size | Beat 1 is both distinct color and larger | ✓ |

**User's choice:** Both color and size

---

## No-tempo track fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Default to 120 BPM | Same default as Homepage entry point | |
| Default to last-used BPM | Prefill with last BPM set in any session | |

**User's choice:** Free text — "if track has no tempo, don't show open metronome button" (rejected both prefill options; chose to hide the entry point instead)

| Option | Description | Selected |
|--------|-------------|----------|
| No indication — just shows the default BPM | Screen looks identical regardless of fallback | |
| Small hint text | e.g. "No tempo set for this track — showing default" | |

**User's choice:** Free text — "no metronome if no bpm" (superseded by the prior answer — entry point hidden entirely, so this question became moot)

---

## Claude's Discretion

- Exact drag-to-BPM angle mapping / sensitivity curve for the dial gesture.
- Dial visual styling (colors, size, ring thickness) within the app's existing theme.
- Placeholder tick sound choice (until user supplies real files).
- Placement/label of the play/pause control relative to the dial.
- Exact asset path/filenames for the tick sound files.

## Deferred Ideas

None — discussion stayed within phase scope.
