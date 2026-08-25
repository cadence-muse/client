# Phase 11: Duration mm:ss Input + Display - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-25
**Phase:** 11-Duration mm:ss Input + Display
**Areas discussed:** Canonical display format, Auto-format typing mechanics, Validation feedback UX, Empty/optional duration handling

---

## Canonical display format

| Option | Description | Selected |
|--------|-------------|----------|
| Same mm:ss, unbounded minutes | Reuses track's existing `asMinutesSeconds` extension as-is for setlist totals too. No special-casing for large values. Matches DUR-03's literal wording and the REQUIREMENTS.md exclusion of HH:mm:ss. | ✓ |
| You decide | Claude picks based on what's simplest and most consistent with existing code. | |

**User's choice:** Same mm:ss, unbounded minutes (recommended)
**Notes:** REQUIREMENTS.md's DUR-03 already mandated one mm:ss format app-wide, replacing the setlist's words format — this question mainly confirmed the setlist-aggregate edge case (totals over 60 minutes) stays plain mm:ss rather than switching format at a threshold.

---

## Auto-format typing mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| Right-to-left digit shift (stopwatch-style) | Digits fill from the right: '2'→'0:02', '230'→'2:30', '2305'→'23:05'. Standard pattern for timer/stopwatch inputs. | ✓ |
| Type minutes then colon then seconds literally | User types manually with colon insertion; may not satisfy DUR-04's "no manual colon entry" requirement. | |
| You decide | Claude picks the standard right-to-left shift pattern. | |

**User's choice:** Right-to-left digit shift (stopwatch-style)

| Option | Description | Selected |
|--------|-------------|----------|
| Cap at 99:59 | Reasonable ceiling for a single track; prevents fat-finger entry. | ✓ |
| No cap, any minute value accepted | Only seconds (0-59) validated; minutes unbounded. | |
| You decide | Claude picks a sensible default. | |

**User's choice:** Cap at 99:59 (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Delete last digit, reformat | '2:30' + backspace → '0:23'. Matches stopwatch-input convention. | ✓ |
| Clear whole field on any backspace | Simpler but jarring — loses all progress on one correction. | |

**User's choice:** Delete last digit, reformat (recommended)
**Notes:** All three sub-decisions in this area went with the recommended option.

---

## Validation feedback UX

| Option | Description | Selected |
|--------|-------------|----------|
| Inline error text below field, on submit | Matches existing form pattern (WR-02 comment in create/edit track screens). Error shows only on submit attempt with an incomplete field. | ✓ |
| Inline error text, live as you type | Shows error immediately after each keystroke — may flash errors mid-entry. | |
| You decide | Claude picks based on existing form validation patterns. | |

**User's choice:** Inline error text below field, on submit (recommended)
**Notes:** Framed around the fact that the auto-formatter (D-02) already prevents most malformed states by construction — the remaining case is an incomplete entry left at submit time.

---

## Empty/optional duration handling

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — blank stays valid/optional | No behavior change from today. Auto-formatter only activates once the user types a digit; untouched/cleared field submits as null. | ✓ |
| You decide | Claude keeps current optional behavior as-is. | |

**User's choice:** Yes — blank stays valid/optional (recommended)

---

## Claude's Discretion

None — all four areas reached explicit decisions from the user.

## Deferred Ideas

None — discussion stayed within phase scope.
