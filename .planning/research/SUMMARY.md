# Project Research Summary: Cadence v1.3 Quality of Life

**Project:** Cadence Flutter Mobile App  
**Domain:** Mobile music practice tool (metronome feature)  
**Researched:** 2026-08-27  
**Confidence:** HIGH

## Executive Summary

The metronome feature for Cadence v1.3 is a purely client-side, session-scoped tool with zero backend dependencies and zero blocking dependencies on other v1.3 items (WR-01 fix, API sync, song→track rename, date picker). The critical technical decision is **audio timing precision**: Timer.periodic alone drifts 100–1000ms and is unsuitable for a musical tool. The recommended approach is **flutter_gapless_loop** with its built-in MetronomePlayer (sample-accurate on native audio engines: AVAudioEngine on iOS, AudioTrack on Android), wrapped in Riverpod providers following existing state-management patterns.

The feature presents three categories of risk: (1) audio timing validation under real load (requires device testing), (2) battery drain from wakelock mismanagement (requires lifecycle-aware acquire/release), and (3) post-rename artifact staleness (pre/post-build audits required). The suggested build order places metronome as a build-last feature due to zero dependencies, allowing it to stabilize other items first.

## Key Findings

### Recommended Stack

Flutter_gapless_loop is the recommended audio engine for the metronome. It includes a built-in MetronomePlayer with sample-accurate timing, native low-latency support (2ms I/O buffer on iOS, 48kHz sample rate on Android), configurable time signatures (4/4 included), and a beat stream for UI synchronization. This eliminates Timer.periodic drift, requires no additional audio-player dependency, and is purpose-built for music production apps. State management leverages existing Riverpod patterns (2.6.1, already in codebase).

**Core technologies:**
- **flutter_gapless_loop 0.0.12+**: Sample-accurate metronome with beat stream for UI sync — no Timer.periodic drift, native audio engine support, designed for music production
- **Riverpod 2.6.1 (@riverpod Notifier, not AsyncNotifier)**: State management for tempo, isPlaying, currentBeat — session-scoped, zero persistence needed
- **audioplayers**: Audio asset playback for click/accent sounds — standard cross-platform choice, graceful silent fallback if unavailable
- **Dart 3.12.2+**: Already required; no version bump
- **Flutter SDK (stable)**: Requires Flutter 3.0+; all modern versions supported

### Expected Features

**Must have (table stakes):**
- Play / Pause control — essential interaction; two-state toggle
- Audio click/tick sound — core function; ~16ms tolerance required
- Visual beat pulse — sync with audio; animated indicator on each beat
- Tempo display (BPM) — show current state; update in real-time
- Tempo selector (circular dial) — primary UI; one-handed use during practice
- Quick-adjust buttons (±1, ±5 BPM) — fine-tuning without dial hunting
- Default tempo (120 BPM) — standard practice tempo
- 4/4 time signature with beat-1 accent — musical context; two distinct sounds
- Two entry points — Tools section (default 120 BPM) + track detail (prefilled with track tempo)

**Should have (competitive differentiators, defer to v2+):**
- Tap tempo — intuitive; medium complexity; deferred
- Background audio — keep metronome active when app backgrounded; requires iOS/Android lifecycle hooks; deferred
- Vibration feedback — deaf musicians or high-volume venues; medium complexity; deferred
- Custom time signatures (3/4, 6/8, etc.) — explicitly out of scope for v1; defer with "4/4 only" documented constraint

### Architecture Approach

The metronome integrates as a self-contained feature with zero architectural changes to existing code. It follows the established Riverpod + lib/features/ pattern: MetronomeScreen (lib/features/metronome/) watches metronomeStateProvider, which supplies tempo/isPlaying/currentBeat state; a metronomeTimerProvider wraps a reactive Stream that fires on each beat; a metronomeServiceProvider encapsulates audio playback. Two entry points (MaterialPageRoute.push() from home_screen.dart and track_detail_screen.dart) pass optional tempo parameter without named routes. No backend calls, no caching, no API extensions required. Build-last ordering is safe—zero blocking dependencies on WR-01, API sync, rename, or date picker.

**Major components:**
1. **MetronomeScreen** (lib/features/metronome/metronome_screen.dart) — UI layer; ConsumerStatefulWidget watching state provider; renders tempo display, beat indicator, adjustment buttons, play/pause FAB
2. **metronomeStateProvider** (lib/providers/metronome_provider.dart) — Riverpod @riverpod Notifier; state shape {tempo: int, isPlaying: bool, currentBeat: int}; no AsyncNotifier (zero async/persistence)
3. **metronomeTimerProvider** — Reactive Stream that fires once per beat, watches isPlaying and tempo, auto-recreates interval when state changes
4. **MetronomeService** (lib/services/metronome_service.dart) — Audio wrapper; playTick() / playAccent() methods; silent fallback if audio unavailable

### Critical Pitfalls

1. **Timer.periodic Drift** — Timer.periodic does not guarantee callback intervals; ±10–20ms variance compounds rapidly (2–4% drift at 120 BPM). After 20–30 seconds, users perceive tempo as "off." Prevention: use flutter_gapless_loop's MetronomePlayer (hardware-backed timing) for audio; reserve Timer.periodic for state updates only; test on real device under load; plan 3–5 hours for audio library spike if high-precision timing uncertain.

2. **Stale Generated Artifacts After Rename** — After renaming lib/features/songs/ to lib/features/tracks/, old .g.dart (Riverpod) and .arb files persist; build_runner only generates new files, doesn't delete old ones. Tests pass (they import new class) but dead code bloats binary; IDE autocomplete may find old class, causing runtime provider-lookup failures. Prevention: pre-rename artifact inventory (find all .g.dart, .arb files), rename in controlled order (Dart file → class → part statement → ARB → l10n.yaml), post-build audit (grep for stale names), force clean with --delete-conflicting-outputs; allocate 1 hour for cleanup and verification.

3. **Test Assertions Break on POST→GET API Migration** — Existing tests assert on HTTP method: `expect(request.method, equals('POST'))`. After ListUserTracks/ListUserSetlists migrate from POST+JSON to GET+query-params, mocks still expect POST and pass locally, but real app fails on server (400/415). Prevention: inventory test files mocking affected endpoints, update mock setup to .get(), validate query-param encoding in assertions, test both endpoints in single changelist, add integration tests against real API, test edge cases (spaces, &, ?, Unicode); allocate 2–3 hours for test updates.

## Implications for Roadmap

Based on research, v1.3 suggests a linear build order with metronome as a build-last feature (zero dependencies allow other items to stabilize first):

### Phase 1: WR-01 Copy Invite Code
**Rationale:** Smallest scope; unblocks testing infrastructure  
**Delivers:** Copy-to-clipboard interaction on band screens  
**Avoids:** No pitfalls; straightforward UI enhancement

### Phase 2: API Sync - POST→GET Migration (ListUserTracks, ListUserSetlists)
**Rationale:** Foundation for search/filtering; must precede query-param encoding work  
**Delivers:** GET endpoints with queryParameters support  
**Implements:** Uri builder pattern (STACK finding: correct encoding essential)  

**Research flag:** Phase needs `/gsd-plan-phase --research-phase 2` to validate API response shape changes and query encoding edge cases

### Phase 3: Song→Track Rename Sweep
**Rationale:** Prepare data model for metronome tempo prefilling (track needs tempo field)  
**Delivers:** Consistent Track/TrackListData naming; template strings in ARB; Riverpod provider renames  
**Implements:** Architecture pattern: feature directory + provider naming conventions  

**Research flag:** Phase needs dedicated sub-task: "Clean build_runner artifacts" with --delete-conflicting-outputs flag; verify no old class imports remain

### Phase 4: Date Picker Enhancement
**Rationale:** UI polish for track metadata; completes data-layer foundation  
**Delivers:** Improved date selection UX  

### Phase 5: Metronome Feature
**Rationale:** Build last (zero dependencies); lets other items stabilize; audio timing research completed in Phase 2 informs this phase  
**Delivers:** Full metronome tool: play/pause, tempo selector, beat indicator, two entry points (Tools + track prefill), audio + visual feedback  
**Uses:** flutter_gapless_loop (STACK.md recommendation), Riverpod Notifier pattern (existing), MaterialPageRoute for navigation (existing)  
**Implements:** Session-scoped state; stream-based timer lifecycle; MetronomeService audio wrapper  

**Research flag:** Phase does NOT need research-phase (metronome patterns well-documented, no API calls, STACK/FEATURES/ARCHITECTURE all HIGH confidence).

### Phase Ordering Rationale

1. **Dependency chain:** WR-01 (trivial) → API sync (foundation for search) → rename (data model consistency) → date picker (UI) → metronome (new feature on stable foundation)
2. **Risk isolation:** Rename artifacts (Phase 3) resolved before Phase 5 starts
3. **Testing:** By Phase 5, 453 tests are proven stable on POST→GET API and renamed notifiers; metronome tests add to proven foundation
4. **Build-last strategy:** Metronome has zero blocking deps on other phases; placing it last ensures other critical fixes land first

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | flutter_gapless_loop MetronomePlayer is purpose-built, well-documented, active maintenance; AVAudioEngine/AudioTrack integration proven in production apps |
| Features | **HIGH** | Table stakes derived from established metronome UX; differentiators aligned with common feature requests |
| Architecture | **HIGH** | Zero backend changes; Riverpod patterns mirror existing auth/theme providers; stream-based timer proven pattern |
| Pitfalls | **MEDIUM-HIGH** | Timer.periodic drift well-documented; rename-artifact risk based on Cadence's 453-test suite structure; POST→GET test breakage specific to this migration |

**Overall confidence:** HIGH for metronome core (audio timing, UI, state management).

### Gaps to Address

- **Track tempo field existence**: Verify publicapi.yml includes tempo/BPM field on Track object; if missing, API extension required before Phase 5
- **Audio asset bundling**: Confirm asset sourcing for metronome_accent.wav and metronome_tick.wav
- **iOS silent mode handling**: Validate AVAudioSession routing on physical iOS device
- **Battery profiling**: Wakelock + audio drain over 30-minute session on real devices during Phase 5 testing

## Sources

### Primary (HIGH confidence)
- STACK.md — flutter_gapless_loop technical comparison, native audio engine specs
- FEATURES.md — User expectations survey, feature dependencies, MVP ordering
- ARCHITECTURE.md — Riverpod pattern integration, build-order analysis, zero-dependency rationale
- PITFALLS.md — Timer.periodic drift research, rename-artifact risk, API migration test breakage

---

*Research completed: 2026-08-27*  
*Ready for roadmap: YES*
