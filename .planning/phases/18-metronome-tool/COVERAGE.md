# Phase 18 — API Coverage Decision Checkpoint

**Gate:** ai-integration "Full API Coverage by Default" checkpoint.

## Declaration

No external API integration: `audioplayers` is a local Flutter audio-playback package (no
network calls, no auth, no remote service) — not the kind of external API/SDK integration
this gate targets.

## Reasoning

Phase 18 adds exactly one new dependency, `audioplayers` (pub.dev, per 18-RESEARCH.md's
"Package Legitimacy Audit" — approved, 8-year-old package, 2M+/week downloads). Its entire
surface used by this phase is local, on-device audio playback:

- `AudioPlayer()` construction and `setPlayerMode(PlayerMode.lowLatency)` — local player
  configuration, no network handshake.
- `setSource(AssetSource(...))` — loads a bundled asset (`assets/audio/*.wav`) shipped in
  the app binary, not fetched from a remote endpoint.
- `resume()` / `play()` / `pause()` / `dispose()` — local playback transport controls.

None of these calls cross a trust boundary (no HTTP request, no credential, no
backend/SaaS response to validate or degrade against). The "capability coverage matrix"
this gate exists to produce (INTEGRATE/OPT-OUT per capability) is designed for services
with a remote surface where partial adoption is a real risk (e.g. shipping a payments SDK
but only wiring `charge()`, silently skipping `refund()`). `audioplayers` has no such
remote capability surface to under-integrate — every capability the phase needs (tick
playback, low-latency mode, graceful load-failure handling) is already covered by
18-RESEARCH.md's Architecture Patterns section and the PLAN.md tasks derived from it.

**Capabilities used this phase** (for completeness, not as an INTEGRATE/OPT-OUT matrix
since the gate does not apply): `AudioPlayer()`, `setPlayerMode(PlayerMode.lowLatency)`,
`setSource(AssetSource)`, `resume()`, `dispose()`. Capabilities intentionally not used:
`setVolume()` (no volume control in scope per CONTEXT.md/UI-SPEC — Claude's Discretion did
not raise it, and REQUIREMENTS.md doesn't request it), streaming/URL sources (asset-only,
no network audio), completion/position callbacks (the metronome's own `Timer`/`Stopwatch`
loop is the timing source of truth per 18-RESEARCH.md's Pitfall 1 — audioplayers'
`onPlayerComplete` is not needed to drive beat cadence).

---

*Written: 2026-08-27 by gsd-planner, Phase 18 planning.*
