---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-08-28T06:06:25.350Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 03 | deviation | lib/providers/tracks_provider.dart |  | TrackListData._fetchAndCache() unconditionally persists fetched data to cache even when a slower in-flight background refresh's state update is discarded by the WR-02 version guard, so a local removeFromList()/updateFields() mutation's cache write can be overwritten by a stale background fetch's cache write shortly after (in-memory state stays correct; only the persisted cache can go stale). Pre-existing pattern shared with bands_provider.dart, not introduced by this plan — out of scope to fix here. | open |  | 2026-08-16T08:20:18.640Z |  |
| 2 | quick-260828-c98 | unrun-verify | test/features/auth/login_screen_test.dart |  | Task 3 human-check: force a live 401, confirm toast + nav to login; confirm manual Profile logout shows no toast -- not run, no device/emulator available | open |  | 2026-08-28T06:06:25.350Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "03",
    "file": "lib/providers/tracks_provider.dart",
    "line": null,
    "description": "TrackListData._fetchAndCache() unconditionally persists fetched data to cache even when a slower in-flight background refresh's state update is discarded by the WR-02 version guard, so a local removeFromList()/updateFields() mutation's cache write can be overwritten by a stale background fetch's cache write shortly after (in-memory state stays correct; only the persisted cache can go stale). Pre-existing pattern shared with bands_provider.dart, not introduced by this plan — out of scope to fix here.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T08:20:18.640Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "quick-260828-c98",
    "file": "test/features/auth/login_screen_test.dart",
    "line": null,
    "description": "Task 3 human-check: force a live 401, confirm toast + nav to login; confirm manual Profile logout shows no toast -- not run, no device/emulator available",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-28T06:06:25.350Z",
    "resolved_at": null
  }
]
````
