---
status: testing
phase: 03-tracks
source: [03-VERIFICATION.md]
started: 2026-08-16T15:30:00Z
updated: 2026-08-16T15:30:00Z
---

## Current Test

number: 1
name: Server honors explicit null as "clear this field" on track update
expected: |
  Against the real backend, edit a track that has Duration=200 and Notes set, clear both fields, save, then navigate away and back (and force-refresh the global Tracks tab). Duration shows "—" and Notes is gone — the server honored the explicit JSON null as "clear this field", not as "no change".
awaiting: user response

## Tests

### 1. Server honors explicit null as "clear this field" on track update
expected: Duration shows "—" and Notes is gone — the server honored the explicit JSON `null` as "clear this field", not as "no change".
result: [pending]

### 2. Decide on NF-01 — silent key wipe on unrecognized musical key values
expected: |
  Team decision — currently, with a track whose key is a value outside the 24-entry musicalKeys list (e.g. "F#m(maj7)"), opening Edit, changing only the title, and saving silently wipes the key to null. Options: (a) accept (only this client writes keys today, so unreachable in practice), (b) append the unrecognized value as an extra dropdown item so it round-trips, (c) omit `key` from the PUT when the incoming value was unrecognized.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
