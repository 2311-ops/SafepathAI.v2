# Phase 2: Real-Time Location, History & Privacy - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 2-Real-Time Location, History & Privacy
**Areas discussed:** Live tracking mechanism, Shared map & history UX, Privacy Center controls, Permission priming & battery transparency

---

## Live Tracking Mechanism — Background scope

| Option | Description | Selected |
|--------|-------------|----------|
| Foreground-only for MVP | Location updates while app is open/active; background/killed-app tracking deferred | ✓ |
| Full background tracking now | Wire up flutter_foreground_task + geolocator background stream immediately | |

**User's choice:** Foreground-only for MVP.

---

## Live Tracking Mechanism — Update delivery

| Option | Description | Selected |
|--------|-------------|----------|
| SignalR push | Backend broadcasts location updates over a SignalR hub as they arrive | ✓ |
| REST polling | Mobile clients periodically GET latest locations | |

**User's choice:** SignalR push.

---

## Live Tracking Mechanism — Presence logic

| Option | Description | Selected |
|--------|-------------|----------|
| Simple timeout heuristic | Server marks offline if no ping within a fixed window | |
| Explicit heartbeat + SignalR connection state | Track SignalR connection open/close as a separate presence signal alongside location pings | ✓ |

**User's choice:** Explicit heartbeat + SignalR connection state (more accurate, adds a second state machine).

---

## Shared Map & History UX — Stale visual

| Option | Description | Selected |
|--------|-------------|----------|
| Faded pin + accuracy circle | Pin opacity reduces with staleness; translucent accuracy-radius circle | ✓ |
| Badge/label only | Full-opacity pin with text badge ("Last seen 12 min ago") | |

**User's choice:** Faded pin + accuracy circle.

---

## Shared Map & History UX — Stop definition

| Option | Description | Selected |
|--------|-------------|----------|
| Dwell-time threshold | Stay within small radius longer than a threshold (e.g. 100m/5min) | ✓ |
| Defer precise definition to planning | Let planner propose thresholds | |

**User's choice:** Dwell-time threshold (exact values deferred to Claude's discretion at planning time — see CONTEXT.md D-05).

---

## Shared Map & History UX — Route visualization

| Option | Description | Selected |
|--------|-------------|----------|
| Polyline on map + separate stats list | Day's path as a line on the map, plus scrollable stats/timeline below | ✓ |
| Timeline list only | Chronological list only, no map polyline | |

**User's choice:** Polyline on map + separate stats list.

---

## Privacy Center — Toggle granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Per-data-type + per-recipient matrix | Toggle each data type independently per family member, reusing FAM-04 | ✓ |
| Per-data-type only (whole family) | One set of toggles applying to the whole circle | |

**User's choice:** Per-data-type + per-recipient matrix.

---

## Privacy Center — Temporary sharing

| Option | Description | Selected |
|--------|-------------|----------|
| Duration picker (1h/4h/8h/custom) | User picks duration; timer auto-flips sharing off | ✓ |
| Defer exact duration options to planning | No strong preference | |

**User's choice:** Duration picker (exact presets deferred to Claude's discretion — see CONTEXT.md D-08).

---

## Privacy Center — Data export

| Option | Description | Selected |
|--------|-------------|----------|
| JSON download of own location history | Simple downloadable JSON, no multi-format pipeline | ✓ |
| Defer format/scope to planning | No strong preference | |

**User's choice:** JSON download of own location history.

---

## Permission Priming & Battery Transparency — Priming content

| Option | Description | Selected |
|--------|-------------|----------|
| Value-first framing | Explains safety benefit (family visibility, SOS enablement) | ✓ |
| Minimal/neutral framing | Short neutral technical explanation | |

**User's choice:** Value-first framing.

---

## Permission Priming & Battery Transparency — Battery detail

| Option | Description | Selected |
|--------|-------------|----------|
| Plain-language estimate + tips | Text explaining minimal impact of foreground-only tracking, plus tips | ✓ |
| Defer to planning | No strong opinion on wording/detail | |

**User's choice:** Plain-language estimate + tips.

---

## Claude's Discretion

- Exact dwell-time/radius thresholds for "stop" detection.
- Exact duration presets for temporary sharing.
- SignalR hub naming/shape and reconnection-handling details.

## Deferred Ideas

- Full background/killed-app location tracking (flutter_foreground_task) — deferred past MVP.
- Live battery-usage graphs/detailed analytics — deferred in favor of plain-language messaging.
- Full GDPR-style multi-format/multi-scope data export — deferred in favor of simple JSON export.
