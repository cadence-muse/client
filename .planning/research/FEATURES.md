# Feature Landscape: Metronome Tool for Cadence v1.3

**Domain:** Mobile music practice tool (tempo/rhythm reference)  
**Researched:** 2026-08-27  
**Research confidence:** HIGH

---

## Table Stakes

Features users expect from any functional metronome. Missing = tool feels broken or incomplete for musicians.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Play / Pause control** | Musicians need to start/stop the beat without fumbling settings | Low | Essential interaction; two-state toggle (playing ↔ stopped) |
| **Audio click/tick sound** | Core metronome function; must be audible during practice | Medium | Needs precise timing (~16ms tolerance); background audio permissions on iOS/Android |
| **Visual beat pulse** | Visual feedback helps in sync with audio; critical when audio muted/volume low | Low–Medium | Animated indicator (color change, icon flash, dial pulse) timed to each beat |
| **Tempo display (BPM)** | Users need to know what tempo they're at; shows current state clearly | Low | Numeric display or knob position; update in real-time as adjusted |
| **Tempo selector (dial/spinner)** | Core interaction: changing tempo quickly while practicing is non-negotiable | Medium | Big round dial (circular UI) as specified; alternative numeric input would break one-handed use in practice |
| **Quick-adjust buttons (±1, ±5 BPM)** | Fine-tuning tempo on the fly without hunting in a dial; standard on physical metronomes | Low | Pair of buttons: coarse (±5) and fine (±1) adjustments; cumulative on repeated taps |
| **Default tempo (120 BPM)** | Musicians expect metronome to start at common practice tempo, not 0 or random | Low | Hardcoded default on fresh open; persisted during session |
| **4/4 time signature with beat-1 accent** | Musical context: 4/4 is the default time for most popular music; beat 1 audibly different (louder/higher pitch) tells musicians where the measure is | Medium | Two distinct sounds: accent sound for beat 1, normal sound for beats 2–4 |
| **Entry from two contexts** | Musicians practice in two workflows: (1) general practice (tempo dial), (2) learning a specific track (use its tempo) | Low | Homepage "Tools" section (default 120 BPM) + track detail screen (prefilled with that track's tempo) |

---

## Differentiators

Features that set the tool apart. Not expected, but valued by power users or musical contexts; raise the product above a basic metronome.

| Feature | Value Proposition | Complexity | Notes | v1 Timing |
|---------|-------------------|-----------|-------|-----------|
| **Tap tempo** | Musicians naturally tap to find a tempo ("tap it out"); more intuitive than dialing | Medium | User taps a button repeatedly; app calculates average tap interval and sets BPM; requires gesture tracking and filtering jitter | v2+ (not mentioned in v1 spec) |
| **Background audio** | Keep metronome ticking while composing, texting, or using notes app on stage | Medium–High | Requires iOS background audio permissions; Android foreground service; manage lifecycle across phone lock/unlock | v2+ (stretch goal; v1 scope unclear) |
| **Vibration + audio feedback** | Deaf musicians or high-volume environments; feel the beat instead of hearing it | Low–Medium | Access vibration API; optionally mute audio and pulse haptics in sync | v2+ (nice-to-have) |
| **Custom accent patterns** | Beyond 4/4: 3/4 waltzes, 6/8 compound meter, jazz triplets, polyrhythms for advanced musicians | High | Extend time-signature UI; store per-tempo presets; add subdivision control | v2+ (explicitly out of scope v1: "4/4 only") |
| **Animated visual metaphors** | Swinging pendulum, bouncing ball, or flashing icon provides rhythmic visual anchor | Low–Medium | CSS animations or Canvas-drawn graphics timed to beats; reinforces visual pulse | v2+ (nice polish) |
| **Practice timer** | Musicians set "practice for 5 minutes" and metronome auto-stops; integrates with practice sessions | Low | Add start/stop timer UI; persist session duration; useful for focused practice blocks | v2+ (integrates with band-practice workflows later) |
| **Session history / tempo memory** | "Remember the last 5 tempos I used"; quick access to favorite practice tempos | Low | Store recent tempos (in-memory or SharedPreferences); list for one-tap restore | v2+ (nice-to-have) |
| **Tempo range presets** | Slow practice (60–90 BPM), medium (90–140), fast (140–180+); buttons to jump between ranges | Low | Quick access to musical practice contexts; reduces need to dial into each range | v2+ (power-user feature) |

---

## Anti-Features

Explicitly NOT to build in v1. These add scope creep or contradict the v1 constraints.

| Anti-Feature | Why Avoid | Recommendation |
|--------------|-----------|-----------------|
| **Multiple time signatures (3/4, 6/8, 2/4, etc.)** | v1 scope is 4/4 only, accented beat 1. Other time signatures require distinct accent patterns, UI complexity, and testing overhead. Punt to v2 with a dedicated "time signature picker." | Accept 4/4-only constraint. If musicians ask for 3/4, log as feature request; evaluate in v2 scope. |
| **Tap tempo** | Not mentioned in v1 spec. Adding it would delay the metronome feature and split testing focus with the dial/quick-adjust interaction. v1 dial + buttons are sufficient. | Defer to v2; establish tap-tempo as a v2 differentiator in the roadmap. |
| **Background audio / foreground service** | Requires iOS app-delegate lifecycle hooks and Android foreground-service declaration; v1 scope is foreground-only metronome (tool you use actively while on-screen). Avoid platform-specific audio permission handling in v1. | Document as a v2 constraint. If musicians ask for background play, explain it lands in v2 alongside other audio lifecycle work. |
| **Customizable sound files / drum kit selection** | Bundling multiple sounds or letting users upload audio files adds asset-storage and privacy complexity. v1 uses one built-in tick sound (hardcoded or asset-bundled). | Use a single, clear click sound (e.g., standard wooden block or electronic beep). If users want drum kits, defer to v2. |
| **Offline metronome logic** | Metronome is a simple UI tool; it works online or offline identically. Don't build special offline detection or fallback behavior — just play the beat. | No special logic; metronome works if app is running, regardless of connectivity. |
| **Acoustic calibration / tuning reference** | Out of scope for a tempo/rhythm tool. Cadence is a repertoire manager, not a tuner app. | Explicitly exclude from v1. If a tuning tool is needed later, it's a separate feature (and probably a separate entry point). |
| **External audio input / beat detection** | Analyzing incoming audio (e.g., "detect my band's tempo from phone mic") is a research project, not a v1 feature. | Punt completely. v1 is human-set tempo, not auto-detected. |

---

## Feature Dependencies

```
Tempo display ← Tempo selector
Tempo selector ← Quick-adjust buttons (±1, ±5)
Audio tick ← Audio permissions (iOS/Android)
Visual pulse ← Audio tick (timed in sync)
Beat-1 accent ← 4/4 time signature (requires two sound variants)
Entry from track detail ← Track.tempo data model (existing)
```

**Key dependency to verify:**
- Track data model includes a `tempo` or similar field (currently tracks have `durationSeconds`; check if tempo is stored or if this needs an API extension)
- If track.tempo doesn't exist: API change required before metronome can prefill from track screen

---

## MVP Recommendation

**Build in this order for v1.3:**

1. **Play / Pause button** — Core interaction; unblock testing of audio timing
2. **Audio tick sound** (4/4 with beat-1 accent) — Core loop; validate precision timing
3. **Tempo selector (big dial)** — Primary UI; test dial responsiveness
4. **Quick-adjust buttons (±1, ±5)** — Fine-tuning; test button feel
5. **Visual pulse** — Sync to audio; add visual feedback
6. **Tempo display (BPM)** — Show current state
7. **Two entry points** (Tools + track prefill) — Integrate with existing screens

**Defer to v2 or later:**
- Tap tempo
- Background audio
- Multiple time signatures
- Vibration feedback
- Custom sounds / drum kits
- Animations / visual polish
- Practice timer
- Tempo history

---

## Complexity Notes

### Audio Timing & Precision
- Metronome tick timing must be accurate to ~16ms or musicians will perceive drift (audio research consensus: delays >16ms are noticeable)
- Flutter packages (e.g., `metronome` pub.dev package, or `flutter_sound`) handle scheduling; use them rather than custom threading
- Background audio on iOS requires `AVAudioEngine` or system sound APIs + app-delegate lifecycle management (v2 concern)

### Platform-Specific Audio
- **Android:** Native Java/Kotlin threading or platform channel to manage precise timing; flutter_sound or metronome package abstracts this
- **iOS:** AVAudioEngine or system sound scheduling via ObjectiveC bridge; similarly abstracted by packages
- **Web:** Web Audio API; out of scope if web build excluded from v1.3

### UI Interaction (One-Handed Play)
- Big round dial must be thumb-reachable from bottom half of screen (typical phone usage during practice)
- Quick-adjust buttons placed near dial for rapid adjustments without breaking flow
- Avoid nested menus or settings that require two hands to navigate

### Integration with Track Data
- Metronome screen from track detail must read `track.tempo` (or similar field)
- Verify API contract in `publicapi.yml`: does Track object have a tempo/BPM field?
- If not, API extension required (coordinate with backend for v1.3 or earlier)

---

## Sources

- [The 10 Best Metronome Apps for iOS and Android (2026) - Musician Wave](https://www.musicianwave.com/best-metronome-apps-for-ios-and-android/) — Comprehensive survey of current metronome UX patterns and user expectations
- [metronome | Flutter package](https://pub.dev/packages/metronome) — Production-ready Flutter package for accurate cross-platform metronome audio
- [MyTempo - Metronome](https://itsallwidgets.com/mytempo-metronome) — Example Flutter metronome with custom timing and localization
- [GitHub - FMetronome](https://github.com/sicreative/FMetronome) — Open-source Flutter metronome implementation for iOS, Android, and macOS
- [Implementing audio beat matching and BPM detection with Flutter Sound](https://colinchflutter.github.io/2023-09-29/00-17-07-632545-implementing-audio-beat-matching-and-bpm-detection-with-flutter-sound/) — Flutter audio timing techniques
