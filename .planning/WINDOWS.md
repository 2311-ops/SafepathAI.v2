---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 0
total_count: 3
last_updated: 2026-08-14T00:05:43.212Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 04 | unrun-verify | backend/tests/SafePath.Api.IntegrationTests/GeofenceTracerEndpointTests.cs |  | Focused integration test blocked by unconfigured SixLabors ImageSharp license. | open |  | 2026-08-11T15:45:03.127Z |  |
| 2 | 04 | unrun-verify | backend/tests/SafePath.Application.Tests/Geofencing/GeofenceTracerTests.cs |  | Focused application test blocked by unconfigured SixLabors ImageSharp license. | open |  | 2026-08-11T15:45:03.484Z |  |
| 3 | 04 | unrun-verify | backend/tests/SafePath.Api.IntegrationTests/GeofencesControllerTests.cs |  | Focused integration suite was blocked by an existing SafePath.Api output-DLL lock. | open |  | 2026-08-14T00:05:43.212Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "04",
    "file": "backend/tests/SafePath.Api.IntegrationTests/GeofenceTracerEndpointTests.cs",
    "line": null,
    "description": "Focused integration test blocked by unconfigured SixLabors ImageSharp license.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T15:45:03.127Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "04",
    "file": "backend/tests/SafePath.Application.Tests/Geofencing/GeofenceTracerTests.cs",
    "line": null,
    "description": "Focused application test blocked by unconfigured SixLabors ImageSharp license.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T15:45:03.484Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "04",
    "file": "backend/tests/SafePath.Api.IntegrationTests/GeofencesControllerTests.cs",
    "line": null,
    "description": "Focused integration suite was blocked by an existing SafePath.Api output-DLL lock.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-14T00:05:43.212Z",
    "resolved_at": null
  }
]
````
