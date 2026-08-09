# Phase 4: Geofencing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-10
**Phase:** 4-Geofencing
**Areas discussed:** Zone creation, Alert sensitivity, Alert recipients and delivery, Zone activity history

---

## Zone creation

### Zone center

| Option | Description | Selected |
|--------|-------------|----------|
| Map-first | Place or move a pin on the map, with a current-location shortcut | ✓ |
| Search-first | Search for an address or place, then refine it | |
| Both equally | Give search and direct map placement equal prominence | |

**User's choice:** Map-first.
**Notes:** Include a movable pin and **Use current location**.

### Radius control

| Option | Description | Selected |
|--------|-------------|----------|
| Presets | Select only from common radius values | |
| Continuous slider | Adjust the radius freely | |
| Both | Combine quick presets and fine slider adjustment | ✓ |

**User's choice:** Both.
**Notes:** Exact presets and bounds remain implementation discretion.

### Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed categories | Use Home, School, University, or Workplace only | |
| Custom names | Use free-form names only | |
| Both | Standard categories plus custom names | ✓ |

**User's choice:** Both.
**Notes:** Preserve the required standard categories while allowing personalization.

### Save confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Preview | Confirm circle, center, radius, member, and notifications before saving | ✓ |
| Save directly | Activate without a review step | |

**User's choice:** Yes, show the preview.
**Notes:** All configuration details must be visible before activation.

---

## Alert sensitivity

### Boundary behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Faster alerts | Trigger promptly at the reported boundary crossing | |
| Reliable alerts | Wait longer to suppress GPS-drift false transitions | ✓ |

**User's choice:** Wait longer.
**Notes:** Reliability is preferred over immediacy.

### Dwell confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Continuous dwell | Require uninterrupted inside/outside presence and reset after crossing back | ✓ |
| Accumulated readings | Count qualifying readings without a full reset | |

**User's choice:** Continuous dwell with reset.
**Notes:** A boundary recross restarts confirmation.

### GPS uncertainty

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore uncertain crossing | Wait while the accuracy range overlaps the boundary | ✓ |
| Treat point as exact | Evaluate only the reported coordinate | |

**User's choice:** Ignore uncertain crossings.
**Notes:** A transition needs a clearly inside or outside reading.

### Sensitivity ownership

| Option | Description | Selected |
|--------|-------------|----------|
| Automatic | SafePath uses one managed sensitivity policy | |
| Guardian-adjustable | Configure sensitivity independently for each zone | ✓ |

**User's choice:** Adjustable by the Guardian.
**Notes:** Technical mappings remain implementation discretion.

---

## Alert recipients and delivery

### Guardian recipients

| Option | Description | Selected |
|--------|-------------|----------|
| Every Guardian | Notify all Guardians in the family | |
| Assigned Guardians | Notify only pre-associated Guardians | |
| Configurable list | Select recipients for each zone | ✓ |

**User's choice:** Configurable recipient list.
**Notes:** Configuration is per zone.

### Member self-notification

| Option | Description | Selected |
|--------|-------------|----------|
| Per-zone switch | Guardian chooses whether the tracked member is notified | ✓ |
| Never | Notify Guardians only | |

**User's choice:** Yes, controlled per zone.
**Notes:** The Guardian owns the setting.

### Delivery surfaces

| Option | Description | Selected |
|--------|-------------|----------|
| Push only | Deliver confirmed events only through push | |
| In-app only | Show confirmed events only inside the app | |
| Both and durable | Use push and in-app feed, retaining history despite push failure | ✓ |

**User's choice:** Must appear on both.
**Notes:** Push failure must not remove or prevent the activity record.

### Priority and quiet hours

| Option | Description | Selected |
|--------|-------------|----------|
| Routine | Normal priority and quiet-hours aware; SOS remains unaffected | ✓ |
| SOS-like | Use the same urgency behavior as SOS | |

**User's choice:** Routine behavior.
**Notes:** SOS remains high-priority and isolated.

---

## Zone activity history

### Entry content

| Option | Description | Selected |
|--------|-------------|----------|
| Detailed | Member, zone, transition, exact timestamp, and visit duration | ✓ |
| Reduced | A smaller event summary | |

**User's choice:** Detailed entries.
**Notes:** Duration is available once an exit completes the visit.

### Ordering and grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Paired visits | Newest-first, grouped by day, pairing entry and exit | ✓ |
| Independent events | Show each transition separately in chronological order | |

**User's choice:** Paired visits.
**Notes:** Pair matching transitions when possible.

### Filters

| Option | Description | Selected |
|--------|-------------|----------|
| Full filters | Member, zone, transition type, and date range | ✓ |
| No filters | Show the unfiltered activity stream | |

**User's choice:** Full filters.
**Notes:** All four filters are required.

### Retention

| Option | Description | Selected |
|--------|-------------|----------|
| Seven days | Automatically delete history after seven days | ✓ |

**User's choice:** Seven days.
**Notes:** Retention is fixed for this phase.

## the agent's Discretion

- Exact radius presets, slider limits, dwell/hysteresis values, and sensitivity-level mappings.
- Native package and platform-specific lifecycle details, after current policy verification.
- Empty-state copy and presentation details within established design patterns.

## Deferred Ideas

- Keep the existing `FamilyController` cold-start todo outside Phase 4.
