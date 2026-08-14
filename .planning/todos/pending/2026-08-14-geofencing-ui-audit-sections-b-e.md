---
created: 2026-08-14T12:40:50.000Z
title: Geofencing UI audit sections B-E — zone activity, detail, notifications, cross-cutting
area: ui
files:
  - mobile/lib/features/geofencing/presentation/zone_activity_screen.dart
  - mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
  - mobile/lib/features/geofencing/presentation/notifications_screen.dart
  - mobile/lib/shared_widgets/
---

## Problem

Captured from a design-system drift audit of Phase 4 (Geofencing) against the
hi-fi mockup (Feature Set 06 — Location History & Geofencing, screens
`03 · Zones · create / manage` and `04 · Zone activity log`). The audit's
section A (`safe_zones_screen.dart` — the most-drifted screen: missing map
header, generic pins instead of category tiles, read-only status chip instead
of a toggle, raw enum text, Material `Card()` shadows, duplicate add
affordances, wrong title) was closed by quick task `260814-kyg`. Sections
B through E below were identified but intentionally **not** implemented in
that task — this todo preserves them as individually addressable items so
deleting the original handoff doc (`GEOFENCING_UI_FIXES.md`) does not silently
discard the backlog.

**B2 (per-zone enter/exit notification toggles) is the one genuinely
functional gap below — everything else in B-E is presentation-only.** None of
this blocks Phase 5.

### B. `zone_activity_screen.dart` — second most drifted

| # | Mockup | Shipped |
|---|---|---|
| B1 | Header is zone-scoped: "School · activity" | Generic "Zone activity" |
| B2 | **Notify on enter / Notify on exit toggles pinned at top** | Absent from this screen |
| B3 | Rows: 34px member avatar circle with initial | No avatar |
| B4 | `Entered` in **safe green**, `Left` in **caution amber** | Uncolored text, direction conveyed only by `isTransit` on the timeline node |
| B5 | Subtitle carries schedule context: "Thu · on time (8:42 AM)" | Bare timestamp / "Visit in progress" |
| B6 | Filters via icon → sheet | Same (sheet exists) — plus a persistent `_FilterSummary` text row, which is an improvement, keep it |

B2 detail: in the mockup, the per-zone enter/exit notification switches live
*on the activity screen* where you're looking at that zone's history. In the
current build they only exist inside the create/edit draft flow
(`notifyAssignedMember` / `guardianRecipientIds`) and the global quiet-hours
screen. A guardian who wants to silence just "School exits" currently has to
re-enter the edit wizard.

Recommendation: add the two toggles to the top of `ZoneActivityScreen` when
it is zone-scoped (`filters.zoneId != null`), writing through to the same
zone-update endpoint the editor uses. Do B3/B4 at the same time — they're
small and they're what make the log scannable.

### C. `safe_zone_detail_screen.dart` — moderate drift

- **C1** Body is a vertical stack of five near-identical `_InfoRow` `Card`s
  ("Assigned member", "Type", "Radius", "Sensitivity", "Status"). The mockup
  groups related facts into a single bordered container with hairline
  dividers, like every other detail surface in the app (cf. Manage
  Permissions, Privacy Center). Five stacked shadowed cards reads as a debug
  dump.
- **C2** `zone.category.wireValue` and `zone.sensitivity.wireValue` are again
  printed directly. `sensitivity` has a perfectly good `.description`
  (`'Recommended for most places'`) that is never surfaced anywhere in the
  UI — show that instead of / alongside the bare enum name.
- **C3** "Delete zone" is a bare `TextButton` sitting at equal visual weight
  next to "Edit zone". Destructive actions in this design system are
  de-emphasised and colored (`sosRedDeep` text, per the documented "Remove
  from circle" exception) — not a peer button in a 50/50 row.
- **C4** Map is 240px and correct. Good — no action needed.

### D. `notifications_screen.dart` — closest to spec, small gaps

- **D1** No severity color-coding. The mockup's notification feed uses a
  left border to encode severity (red = SOS, amber = caution, plain = info).
  This screen is currently geofence-only so everything is info-level, but the
  mockup's Notifications Center is the *unified* feed — when SOS/battery/
  inactivity items land here in later phases, the row widget needs that
  affordance. Worth building the left-border slot now while it's cheap.
- **D2** Enter/exit icons are both `primaryTeal`. Mockup colors entered green
  / left amber (same as B4).
- **D3** `CircleAvatar` uses the theme default fill rather than the member's
  assigned color, so all members look identical in the feed. The family
  member color assignment already exists elsewhere in the app — reuse it.

### E. Cross-cutting

- **E1** Card treatment is inconsistent across the whole feature.
  `notifications_screen.dart` correctly uses
  `Material(color: surface, borderRadius: 16)`; `safe_zone_detail_screen.dart`
  uses raw `Card()` (section A's `safe_zones_screen.dart` was already fixed
  to the `Material`/hairline treatment by `260814-kyg`). Pick the `Material`
  pattern consistently — ideally extract a shared `AppCard` widget in
  `shared_widgets/` and use it everywhere, since this drift will keep
  recurring every phase otherwise.
- **E2** Screen gutter varies: 16px in the zones list (now fixed to
  `AppSpacing.md` by `260814-kyg`'s corrected screen), 24px in detail /
  activity / notifications. `AppSpacing.screenGutter` is 24 and documents
  itself as the phase default — confirm the zones list should also move to
  24 for full consistency, or record why 16 is deliberate there.
- **E3** No `SafeZoneCategory.university` styling distinction anywhere; it
  silently shares School's treatment (category tile color/icon already
  confirmed exhaustive by `260814-kyg`). Fine as a decision, just make it
  deliberate — record it or differentiate university's icon/color.

### Suggested order (from the original audit)

1. ~~Drop in the corrected `safe_zones_screen.dart` + wire `mapOverride` and
   `onToggle`~~ — done, `260814-kyg` (section A closed).
2. B3/B4 + D2/D3 — enter/exit color coding and member avatars (small, shared
   fix across two screens).
3. C1/C2/C3 — detail screen grouping and destructive-action treatment.
4. E1 — extract `AppCard` and retrofit, to stop the drift recurring.
5. B2 — per-zone enter/exit toggles (functional, needs an endpoint decision:
   likely the same zone-update endpoint the editor already uses).

## Solution

Not scoped yet — TBD. When picked up, plan as its own quick task or small
phase slice via `/gsd-plan-phase` / `/gsd-quick`, following the suggested
order above. Run `flutter analyze` + the full mobile test suite before/after
each item. B2 is the only item requiring backend awareness (confirm the
zone-update endpoint accepts partial `notifyAssignedMember` /
`guardianRecipientIds` updates without requiring a full draft resubmission).
