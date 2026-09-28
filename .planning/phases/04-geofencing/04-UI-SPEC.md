---
phase: 4
slug: geofencing
status: draft
shadcn_initialized: false
preset: none
created: 2026-08-10
---

# Phase 4 — UI Design Contract

> Visual and interaction contract for Guardian-managed safe zones, routine geofence alerts, and seven-day zone activity. This contract extends the shipped Flutter design system; it must not change the SOS fast path or import a map SDK outside `VectorMap`.

---

## Scope and Interaction Principles

- Safe-zone management is **Guardian-only**. A Guardian reaches it from a 48px `Safe zones` (`Icons.fence_outlined`) action in the Live Map header/overlay with the Semantics label **Manage safe zones**; it is a pushed route, not a fifth bottom-navigation destination. Keep the existing Map / Activity / SOS / Insights / Privacy shell unchanged.
- Add a 48px `Notifications` (`Icons.notifications_none`) action beside the existing Live Map actions with the Semantics label **View notifications**. It opens the routine in-app notification feed; it must never force-navigate a user as an SOS alert does.
- Members do not create, edit, or delete zones. They receive a zone's enter/exit alert only when its Guardian-controlled **Also notify {member name}** switch is enabled.
- Use `VectorMap`, `VectorMapController`, `MapCircle`, and `OverlayMarker` only. No Phase 4 screen may import `maplibre_gl` or any other map SDK directly. Zone geometry is a metre-accurate circle, with a north-up, non-rotating map consistent with the Live Map.
- Routine geofence UI and delivery use normal navigation, quiet hours, teal/safe/amber semantics, and ordinary notification priority. They must not share SOS screen chrome, SOS-red styling, AlertHub routing, foreground-force-navigation behavior, or SOS timing.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none — Flutter/Dart mobile app; shadcn does not apply |
| Preset | not applicable |
| Component library | Flutter Material 3 via the existing `ThemeData`; reuse `SafePathCard`, `PrimaryButton`, `ToggleRow`, `TimelineNode`, and existing modal-sheet/dialog patterns |
| Icon library | Flutter Material `Icons.*`; use rounded outlined icons for inactive actions and filled icons only for selected/confirmed state |
| Font | Manrope for UI text; JetBrains Mono for captions, filter labels, timestamps, and status badges, via existing `AppTypography` |
| Existing tokens | Reuse `AppColors`, `AppSpacing`, and `AppTypography`; create no new palette, font, or spacing token for this phase |

---

## Information Architecture and Screens

### 1. Safe zones list

- Route title: **Safe zones**. Intro copy: **“Manage the places that matter to your family.”**
- Guardian list cards use `SafePathCard` with: category icon in a 44px `primaryTintBg` tile, zone name, assigned member name/avatar, radius, and a compact enabled/needs-permission status badge. The whole card opens zone details; a dedicated trailing 48px `Activity` icon opens that zone's activity directly and has the Semantics label **View activity for {zone name}**.
- The zone name and category-icon tile form each card's visual anchor at the leading edge; member, radius, and state are supporting metadata beneath or beside that anchor.
- Add control: a 52px full-width `PrimaryButton` at the bottom of the list labelled **Add safe zone**. It remains reachable above the raised SOS navigation area.
- No bottom-nav item, floating action button, or always-visible map control is added for zones.
- Empty state: outlined `fence` icon at 44px, then the copy in the Copywriting Contract and the **Add safe zone** CTA.
- Loading state: render three non-interactive white card skeletons using the list's actual icon/text/radius geometry; do not replace the whole screen with a spinner after initial navigation.

### 2. Create and edit safe zone flow

Creation is a focused, scrollable route titled **Add safe zone**. Edit uses the same route titled **Edit safe zone**, prefilled with the existing zone. The route is map-first and has these ordered sections:

1. **Position on map.** The upper map panel is at least 280px high. Show a draggable center pin and a teal `MapCircle` (`#2E7D7B`, 15% fill, 80% outline, 2px outline) whose radius updates continuously. Place a labelled 48px **Use current location** action over/below the map; it recentres the pin only after the existing location permission has been granted. It must not trigger a new OS permission prompt.
2. **Zone type and name.** Offer mutually exclusive chips: Home, School, University, Workplace, and Custom. A name field is always visible: selecting a standard type prefills that name, while Custom starts empty. The Guardian may replace any prefilled name. The field label is `ZONE NAME` and the maximum visible name is two lines in summary surfaces; full text is retained in the edit field.
3. **Assigned member.** A required `Family member` selector shows avatar, display name, and role. If no eligible member is available, disable progression and show the documented actionable error.
4. **Radius.** Provide preset chips **100 m**, **250 m**, **500 m**, and **1 km**, plus a labelled slider from **100 m to 2 km** in 25 m increments. The currently selected value is displayed in a 16px/600 text label and changes the map circle live. The slider is not the only means of setting a value: preset chips stay available to screen-reader and motor-impaired users.
5. **Sensitivity.** Use a three-choice segmented control with no raw GPS thresholds: **Reliable** (default; “Wait for a clearer, sustained crossing”), **Balanced** (“Recommended for most places”), and **Responsive** (“Confirm sooner near the boundary”). Every option also has an icon and visible label. This is a per-zone setting; changing it never suggests that alerts are instantaneous or exact at the boundary.
6. **Notifications.** Render active Guardians as named avatar rows with checkboxes; all active Guardians are selected initially and the Guardian may change the list. Require at least one selected Guardian before activation. Below it, render **Also notify {assigned member}** as an off-by-default switch with the subtitle **“Let them know when they enter or leave this zone.”**

The fixed bottom CTA is **Review zone** (52px, primary-navy fill). It is disabled until zone name, assigned member, radius, and at least one Guardian recipient are valid. Validation uses the existing amber field/border treatment and places text immediately below the relevant field; never use SOS red.

### 3. Confirmation preview and activation

- **Review safe zone** is a separate confirmation route, not an inline toast. It shows a non-editable map circle and center pin, then one summary card containing zone name/type, center (resolved address when available; otherwise latitude/longitude), radius, assigned member, sensitivity, selected Guardian recipients, and the member-notification setting.
- Each summary group has a destination-specific 48px text/icon action—**Edit location**, **Edit details**, **Edit radius**, **Edit sensitivity**, or **Edit notifications**—returning to the appropriate creation section without discarding entered values.
- Primary CTA: **Save safe zone**. On success, return to the Safe zones list, show a safe-green snackbar **“Safe zone active”**, and insert the new enabled card without a full-screen reload.
- If the OS requires geofence/background-location authorization, show a plain-language rationale only after the Guardian presses **Save safe zone**, then open the system prompt. Do not ask when the map first opens or when **Use current location** is tapped. If denied, save the zone in a visible **Needs location permission** inactive state with a 48px **Open Settings** action; do not present it as active or promise notifications.

### 4. Zone detail and activity

- Zone detail begins with the same circle/map preview and summary card, then exposes **Edit zone**, **View activity**, and a confirmed **Delete zone** action. Place Delete zone below the non-destructive actions; it is an ink text/icon action, never SOS red.
- **Zone activity** is a full route with a filter icon/button labelled **Filter activity**. Default filter: selected zone, all assigned members, all transition types, last seven days.
- The filter opens a modal bottom sheet with Family member, Zone, Transition (`All`, `Entered`, `Left`), and date-range controls. Date selection is clamped to the retained seven-day window and the sheet states this before confirmation. Apply label: **Show activity**.
- Activity is newest-first and grouped by local calendar day (`Today`, `Yesterday`, otherwise the full local date). A matched visit is one `TimelineNode`-style row: member avatar/name, zone, clear direction words and icons, full local entry and exit timestamps, and `Visit duration {duration}`. Example: **“Maya entered Home · 10 Aug 2026, 08:20”**, **“Left · 10 Aug 2026, 16:05”**, **“Visit duration 7h 45m”**.
- An unmatched transition remains a single row, e.g. **“Maya entered Home · 10 Aug 2026, 08:20”** and **“Visit in progress”**. Do not invent a duration or imply an exit occurred.
- Long activity lists scroll beneath a sticky filter summary. Names truncate after two lines with ellipsis in cards; the Semantics label and detail screen expose the complete name and timestamp.

### 5. Routine notification feed and push

- The in-app feed title is **Notifications**. A confirmed transition adds a durable normal-priority feed row even if push delivery fails. A row shows the assigned member avatar, a directional icon plus explicit text, and full local timestamp: **“{name} entered {zone}”** or **“{name} left {zone}”**. A 48px row tap opens that zone's filtered activity.
- The matching push title uses the same exact pattern; body: **“{full local date and time}”**. Tapping it opens the same activity route. These notifications respect quiet hours; do not show a misleading “delivered” status in the feed.
- Feed rows use a teal unread dot plus visible `New` text until opened. Read/unread state is supplemental only; transition direction is always communicated by its icon and text.

---

## Spacing Scale

Use the existing locked 4pt-based scale; no Phase 4 additions.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon-to-label and status-dot gaps |
| sm | 8px | Chip groups, compact card rows, timeline metadata, and card internal row gaps |
| md | 16px | Default control separation, card padding, and filter-group spacing |
| lg | 24px | Screen gutter, section starts, map-to-form separation |
| xl | 32px | Major separation before destructive controls or empty-state CTA |

Exceptions:

- All icon-only targets, map controls, checkboxes, switches, and row actions are at least 44×44px; Live Map actions and map-position controls are 48×48px.
- Existing primary/outlined actions retain their 52px minimum height and 16px radius.
- The map panel is at least 280px high; it may expand on larger devices but must not shrink below that height to make room for controls.

---

## Typography

Phase 4 introduces no typography token. To keep the new surfaces deliberately restrained, use exactly these existing roles:

| Role | Size | Weight | Line Height | Use |
|------|------|--------|-------------|-----|
| Caption / filter / status | 12px | 600 | 1.3 | JetBrains Mono labels, filter summaries, status badges, timestamps |
| Body / control | 16px | 600 | 1.4 | Zone names in cards, form controls, activity descriptions, CTAs |
| Screen heading | 30px | 800 | 1.2 | Safe zones, Add safe zone, Review safe zone, Zone activity headings |

Use Manrope for Body and Heading, JetBrains Mono for Caption. System text scaling remains enabled; card/row layouts must grow vertically rather than clipping text.

---

## Color

This phase reuses the shipped palette and its SOS-red reservation.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `AppColors.appBg` / `#F4F8FA` | Screen backgrounds and map-adjacent page space |
| Secondary (30%) | `AppColors.surface` / `#FFFFFF` | Cards, form fields, filter sheet, notification rows, map control backgrounds |
| Accent (10%) | `AppColors.primaryTeal` / `#2E7D7B` | Selected category/sensitivity controls, active toggles and checkbox states, focused input borders, map-circle outline/fill, primary outlined action text/border, unread dot |
| Safe semantic | `AppColors.safe` / `#2F9E6B` with `safeBg` | Active/saved confirmation and safe-green snackbar only |
| Caution semantic | `AppColors.caution` / `#C98A2B` with caution background/border | Validation, permission-needed state, unavailable/offline error states |
| Destructive action | `AppColors.ink` / `#14283A` | Confirmed Delete zone action only; keeps routine destructive UI distinct from emergencies |

Accent is reserved for the explicitly listed controls above; it is not a generic decoration color. `AppColors.sosRed` and `sosRedDeep` are prohibited throughout Phase 4, including failed saves, disabled zones, permission errors, ordinary push, and Delete zone.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | **Save safe zone** |
| Entry CTA | **Add safe zone** |
| Review CTA | **Review zone** |
| Current-location action | **Use current location** |
| No-zones heading | **No safe zones yet** |
| No-zones body | **Add a place to be notified when a family member enters or leaves it.** |
| No-activity heading | **No zone activity yet** |
| No-activity body | **Confirmed arrivals and departures from the last 7 days will appear here.** |
| No-notifications heading | **You're all caught up** |
| No-notifications body | **New safe-zone alerts will appear here.** |
| Load error | **Couldn't load safe zones. Check your connection and try again.** Action: **Try again** |
| Save error | **We couldn't save this safe zone. Your changes are still here — try again.** |
| Permission-needed state | **Location permission needed** — **Allow location access in Settings to activate alerts for this zone.** Action: **Open Settings** |
| No eligible member | **Add a family member before creating a safe zone.** |
| No Guardian recipient | **Select at least one Guardian to receive alerts.** |
| Delete confirmation | Title: **Delete {zone name}?** Body: **This stops future enter and leave alerts for this zone. Existing activity remains available for up to 7 days.** Actions: **Keep safe zone** / **Delete zone** |
| Routine push/feed title | **{member name} entered {zone name}** or **{member name} left {zone name}** |

---

## Accessibility, Feedback, and Motion

- Every state has text plus icon plus color. Entry/exit use `login`/`logout`-style directional icons alongside the words **entered** and **left**; never rely on arrow direction, teal, or green alone.
- The movable map pin has the Semantics label **“Safe-zone center. Drag to change location.”** Provide a labelled **Move pin** alternative that reveals four 48px directional nudge controls for users unable to drag the map. The slider, presets, and selected radius expose their current value through Semantics.
- Announce meaningful changes once through `SemanticsService.announce`: selected member, radius, sensitivity, saved state, and permission-needed state. Do not announce every slider tick while it is being dragged.
- Use `CircularProgressIndicator` only for a deliberate submit/in-place refresh. Disable the submitting CTA, retain the entered preview, and replace its label with **Saving…**. No full-screen flash or map rebuild occurs per slider drag or preview edit.
- Selected chips and segmented controls animate background/border changes over 180ms using the existing shell timing. With `MediaQuery.disableAnimations`, they swap instantly. Do not add pulse, repeating animation, or haptic effects for routine geofence alerts.
- Use localized absolute timestamps in visible activity/feed rows and in assistive labels; a relative day heading alone is insufficient for the required exact timestamp.

---

## UI Considerations

Applicable state considerations resolved: 32 covered, 5 backstop, 0 unresolved.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| empty | Safe zones list; create/edit form; review/detail; zone activity; notification feed | ✅ covered | Use the three documented empty-state copy pairs for collections. A new form opens with no member chosen, default Reliable sensitivity, the minimum valid radius, and Review disabled. Review/detail never renders an empty summary: missing zone data shows the load-error state with **Try again** and Back. |
| loading | Safe zones list; create/edit map and submit; review/detail; zone activity; notification feed | ✅ covered | Lists use geometry-matched skeletons. The map uses a fixed-height neutral surface until ready so the form does not jump. Review/detail preserves its shell while loading. Submits retain entered data, disable the CTA, and show **Saving…**; in-place refresh uses a compact progress indicator. |
| error | Safe zones list; create/edit form and map; review/detail; zone activity; notification feed | ✅ covered | Show the documented actionable load/save copy with **Try again**, preserve unsaved form values, and use amber—not SOS red. If map tiles fail, keep address/coordinate and radius controls usable with a labelled map-unavailable message. Feed/activity failures preserve any already-loaded rows. |
| populated | Safe zones list; create/edit map; review/detail; zone activity; notification feed | ✅ covered | Zone cards expose the anchored zone name/category plus member, radius, and state; the form displays the pin/circle and current selections; review/detail shows every required summary field; activity groups paired visits newest-first; the feed uses one readable routine-alert row per transition. |
| partial | Safe zones list; create/edit form; zone activity; notification feed | ✅ covered | Permission-denied zones remain visible as inactive cards. Incomplete forms retain valid fields and show errors only beside invalid fields. An unresolved address falls back to coordinates; unmatched activity shows **Visit in progress** without a fabricated duration. Feed history remains present when push delivery fails and never claims delivery. |
| overflow | Safe zones list; create/edit form; review/detail; zone activity/filter; notification feed | ✅ covered | Screens and lists scroll vertically through the safe area; recipient and filter collections scroll without covering their fixed action; summary groups reflow vertically; no grid compression or horizontal clipping is allowed. |
| zero-one-many | Safe zones list; zone activity; notification feed | ✅ covered | Zero uses the documented empty states; one item remains a full-width card/row with singular wording; many items use the same vertical rhythm and scroll without changing card structure. |
| long-text | Safe zones list | 🧪 backstop | Zone/member names cap at two visible lines with ellipsis while Semantics and detail expose full values; verify at the largest supported system text size. |
| long-text | Create/edit form and map controls | 🧪 backstop | Field values, recipient rows, chips, segmented choices, validation, and map actions wrap or grow vertically without overlap; verify with long localized strings and maximum text scale. |
| long-text | Review/detail | 🧪 backstop | Summary values and destination-specific edit labels reflow without obscuring the map or actions; verify with long names, coordinates, and maximum text scale. |
| long-text | Zone activity | 🧪 backstop | Names may ellipsize to two lines in rows, but full timestamps and meaning remain accessible; verify long names, localized dates, and maximum text scale in widget/golden tests. |
| long-text | Notification feed | 🧪 backstop | Alert titles wrap without hiding transition direction or timestamp and expose complete Semantics; verify long member/zone names and maximum text scale. |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| n/a — Flutter project, no shadcn/component registry | none | not applicable — no third-party UI block is permitted by this contract |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS (destination-specific summary actions applied)
- [x] Dimension 2 Visuals: PASS (list anchor and icon-action Semantics specified)
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** verified by `gsd-ui-checker`; post-verification state probe resolved with 32 explicit truths and 5 held-out backstops.
