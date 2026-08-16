---
status: complete
phase: 03-tracks
source: [03-VERIFICATION.md]
started: 2026-08-16T15:30:00Z
updated: 2026-08-16T13:08:44Z
---

## Current Test

[testing complete]

## Tests

### 1. Server honors explicit null as "clear this field" on track update
expected: Duration shows "—" and Notes is gone — the server honored the explicit JSON `null` as "clear this field", not as "no change".
result: pass

### 2. Decide on NF-01 — silent key wipe on unrecognized musical key values
expected: |
  Team decision — currently, with a track whose key is a value outside the 24-entry musicalKeys list (e.g. "F#m(maj7)"), opening Edit, changing only the title, and saving silently wipes the key to null. Options: (a) accept (only this client writes keys today, so unreachable in practice), (b) append the unrecognized value as an extra dropdown item so it round-trips, (c) omit `key` from the PUT when the incoming value was unrecognized.
result: pass
decision: "Option (a) accepted — user confirmed backend strictly validates/enforces key format, so unrecognized values are unreachable in practice."

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
