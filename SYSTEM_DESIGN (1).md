# Handoff: SafePath AI — Family Safety & Location Intelligence App

## Overview
SafePath AI is a cross-platform **Flutter** app (Android + iOS) for family safety and real-time location intelligence. It combines live location tracking, geofencing, an emergency SOS system, AI-powered behavioral analytics, and a health & wellness module. Positioning is **privacy-first and explainable-AI** — every alert, score, or prediction is shown with a plain-language reason.

This handoff covers the **design system** plus **36 high-fidelity screens** across 8 feature sets, including the three highest-stakes connected flows (onboarding→family setup, SOS trigger→resolution, Walk-Me-Home start→arrival/escalation).

## About the Design Files
The files in this bundle are **design references created in HTML/CSS** — prototypes showing the intended look, layout, and behavior. **They are not production code to copy.** Flutter does not consume HTML.

The task is to **recreate these designs in the Flutter codebase** using its established patterns: Material 3 on Android, Cupertino-adaptive on iOS, `ThemeData`/`ColorScheme` for tokens, and OS-level dynamic font scaling for accessibility. Treat the HTML as a precise visual spec — translate each frame into Flutter widgets, wiring the tokens below into your theme.

Icons in the mockups use **Material Symbols Rounded** — map these directly to Flutter's `Icons.*` (Material) or `CupertinoIcons.*` where a closer platform match exists.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, and interactions are specified. Recreate the UI faithfully using Flutter widgets and the design tokens listed here. Where a value below and the HTML disagree, this README wins.

---

## Design Tokens

### Color
| Token | Hex | Use |
|---|---|---|
| Deep Teal | `#0C3A3F` | Primary dark surfaces, SOS panel bg, dark cards, ink accents |
| Deep Teal (darker) | `#0A2D31` / `#0B262A` | Gradient ends, phone bezel |
| Primary | `#15807C` | Primary buttons, active nav, links, selected states |
| Primary tint bg | `#E3EFEE` | Info chips, selected-card fill |
| Accent Mint | `#5FD0C5` | Accent on dark surfaces, logo highlight |
| Safe (green) | `#2F9E6B` | Safe status, success, "on time" |
| Safe deep | `#1E6E4B` / `#23875A` | Safe text, arrival gradient |
| Safe bg | `#EAF5EF` | Safe card fill; border `#CDE9DA` |
| Caution (amber) | `#C98A2B` | Routine warnings: low battery, geofence, inactivity |
| Caution text | `#8A6118` / `#A57A2E` | Amber body text |
| Caution bg | `#FBF3E3` | Amber card fill; border `#EFDFBF` |
| **SOS Red** | `#DE3B40` | **RESERVED — emergency/SOS only.** Never for routine warnings. |
| SOS Red deep | `#C42A30` / `#8E1D22` | Pressed SOS, gradients |
| SOS Red bg | `#FBE9EA` | SOS-context surfaces; border `#F3CFD0` |
| App BG | `#ECF0EF` | Default screen background |
| Surface | `#FFFFFF` | Cards, sheets, inputs |
| Ink | `#15302E` | Primary text |
| Text secondary | `#5E726F` | Body/subtitles |
| Text muted | `#8A9893` | Captions, timestamps |
| Hairline | `#E4EAE8` / `#F0F3F2` | Borders, dividers |
| Toggle off track | `#DDE5E3` | Switch off state |
| Extra member colors | `#6E66C9` (violet), `#C95E8F` (pink) | Member avatars beyond core |

**Critical rule:** Red (`#DE3B40`) is reserved exclusively for SOS/emergency states. Routine warnings (low battery, geofence, inactivity) use Caution amber `#C98A2B`. Do not dilute red anywhere else.

### Typography
- **Primary family:** Manrope (weights 400/500/600/700/800). Google Fonts — use the `google_fonts` package (`GoogleFonts.manrope`).
- **Mono family:** JetBrains Mono (400/500/600) — used for labels, codes, timestamps (`GoogleFonts.jetBrainsMono`).
- Scale (as rendered at phone size; map to Flutter `TextTheme`):
  - Display / headline: 800, ~26–38px, letter-spacing −0.02em
  - Title: 700, ~17–22px, letter-spacing −0.01em
  - Body: 600, ~14–16px
  - Body secondary: 500, ~12–13px, color `#5E726F`
  - Caption / mono label: 600 mono, 11–12px, letter-spacing 0.04–0.08em, uppercase, color `#8A9893`

### Spacing (4pt base)
`4 · 8 · 12 · 16 · 24 · 32`. Screen horizontal padding is typically 22–28px. Card padding 14–22px.

### Radius
- Inputs / small cards: 14px
- Cards / list containers: 16–18px
- Large cards / score panels: 20px
- Bottom sheets: 28px top corners
- Phone frame inner screen: 44px
- Pills / chips: 20px or full (999px)
- Toggles: 16px track, 22px knob

### Shadows
- Card: `0 1px 3px rgba(12,58,63,.1)` to `0 6px 16px rgba(12,58,63,.1)`
- Elevated sheet: `0 -10px 30px rgba(12,58,63,.12)`
- SOS button: `0 10px 22px rgba(222,59,64,.45)`
- Floating pin: `0 6px 14px rgba(12,58,63,.3)`

### Motion
- SOS pulse ring: expanding box-shadow, ~1.6–2.4s ease-out infinite
- Map ping: scale 0.5→2.4 + fade, ~2.4–2.6s infinite
- Live-dot blink: opacity 1→0.3, ~1s
- SOS arm: circular progress fills over **3000ms** (press-and-hold), stroke transitions mint→red past ~60%

---

## The SOS Button (sacred — read carefully)
- **Always visible** on primary tabs, centered in the bottom nav, raised (`margin-top:-40px`), 64px circle, red `#DE3B40`, 4px white border, `SOS` label 800/15px white.
- **Arming = press-and-hold for 3 seconds.** A circular progress ring around the button fills over 3s; releasing before completion cancels with nothing sent. This prevents accidental triggers while never slowing a real emergency.
- On the Home screen mock it is interactive (see `SafePath AI.dc.html` logic class `Component`): pointer-down starts a `requestAnimationFrame` loop computing `hold = elapsed/3000`; ring `stroke-dashoffset = C*(1-hold)` with `C = 2π·46`; at `hold>=1` it arms and shows a toast. Recreate in Flutter with a `GestureDetector` (`onTapDown`/`onTapUp`/`onTapCancel`) driving an `AnimationController(duration: 3s)` and a `CircularProgressIndicator`/`CustomPaint` ring.

---

## Feature Sets & Screens

Screens are laid out on a canvas grouped into 8 feature sets. Each phone frame is 390×844 (logical), inner content padded ~22–28px horizontally, with a faux status bar (9:41 + signal/wifi/battery) at top.

### 01 — Onboarding → Family Setup (hero flow)
1. **Welcome** — Deep-teal gradient, logo, tagline "Family safety that stays calm — and explains every alert." Trust chips (Private / Real-time / Explainable). Primary "Create your circle" (mint `#5FD0C5`), secondary "I already have an account."
2. **Register** — Full name / email (focused state: teal border + 4px focus ring) / password fields; agree-to-terms with "never sells location data"; Continue button.
3. **Role selection** — Step 1/3 progress bar. Three radio cards: Guardian/Parent (selected, teal border + shadow), Member/Teen, Elderly care. Each has icon tile, title, subtitle.
4. **Create circle** — Step 2/3. Circle avatar (`diversity_3`), member color dots, name input "The Rivera Family", privacy reassurance chip.
5. **Invite member** — QR code block + share code `SP-4K9X` (expires 24h), Copy link / Share buttons, Pending list (Jordan, amber PENDING badge).
6. **Accept / reject (receiver)** — Overlapping avatars, "Maya invited you", a "what you'll share" breakdown (Live location=you control, Wellness=off by default, SOS=always two-way), "you'll always see who viewed you", Accept & join / Decline.
7. **Manage permissions** — Member header (Jordan, ACTIVE badge), mutual-sharing note, toggles (share live location ON, view history ON, SOS responder ON, wellness OFF), destructive "Remove from circle" in red.

### 02 — SOS Trigger → Resolution + Silent/Duress (hero flow)
1. **Home / Live Map** — Full-bleed stylized map with member pins (M teal w/ ping, J amber, G violet), "Good morning / The Rivera Family" header, notification bell w/ red dot, "Everyone's safe" green banner, member status chips, bottom nav (Map/Activity/[SOS]/Insights/Privacy). **Interactive press-and-hold SOS.** Armed state shows a red pulsing toast "SOS armed — alert sending / Tap to cancel."
2. **Arming** — Red radial-gradient takeover, large ring at partial fill, center white SOS disc "sending in 1s…", "Release anywhere to cancel. Nothing has been sent yet.", Cancel button.
3. **Alert sent** — Red header w/ pulsing sos icon, "Streaming your live location" live badge, responder list (Maya=Calling now, Dad=Delivered/seen, Emergency services=ready), live location pin card, "Call 911" (ink button), "Hold to cancel alert".
4. **Responder status detail** — "Alert active · 0:42 elapsed" red strip, per-responder cards with channel + status + timing, "Add a responder", "Message all responders".
5. **Silent/Duress setup** — Deep-teal explainer card, decoy PIN entry (4 boxes), "when triggered" toggles (Fully silent ON, Show decoy screen ON), "Enable duress mode".
6. **Decoy screen** — Disguised as a **weather app** (blue gradient, "Cedar Falls 72°", hourly forecast). SOS + live stream run silently in background; only tell is a dim status dot. (The dark caption on the mock is a design annotation, not UI.)

### 03 — Walk-Me-Home (hero flow)
1. **Start** — Map + bottom sheet: destination card (Home, 0.7mi, 8min), quick chips (Dorm/Work/+New), "who's watching" avatars (Maya, Dad, +add), "Start walk".
2. **In progress** — Route line (solid walked + dashed remaining), walking pin w/ ping, "Maya & Dad are watching" strip, big live ETA countdown `8:24`, progress bar, "Call" + "I'm safe" (green) buttons.
3. **Arrival confirmed** — Green gradient, pulsing check, "You made it home", watcher-notified chips (done_all), "Done".
4. **Late → escalation** — Amber screen (`running_with_errors`), "Running late?", AI explanation ("ETA passed 4 min ago, paused off usual route. Not an emergency yet."), 2:00 countdown ring "Auto-alerting your circle", "I'm OK — extend 15 min" (green) / "Send help now" (red).

### 04 — AI Insights & Safety Dashboard
1. **Safety dashboard** — Circular score 92/100 (green ring) "Calm & safe", "why this score" green chips (usual routes/on schedule/batteries OK), "needs a look" anomaly card (amber), ETA card, bottom nav w/ Insights active.
2. **Anomaly detail** — Map w/ usual (dashed) vs actual (amber) route, bottom sheet: "Unusual route home", amber "why flagged" explanation, usual/new ETA + battery stats, "Message Jordan" / "Looks fine".
3. **ETA prediction** — Deep-teal hero "3:42 PM ±4 min · 87% confidence", "what the prediction uses" list (pace/conditions/schedule), notify-on-arrival toggle.
4. **Activity summary** — Day/Week/Month segmented control, stat tiles (places/distance/time away), "time away by day" bar chart (Thursday highlighted teal), top places list.
5. **Location heatmap** — Map w/ radial heat blooms + legend (Less→More: mint→green→amber→red), bottom sheet with per-place % bars (Home 62% red, School 26% teal).

### 05 — Notifications, Visibility & Privacy
1. **Notifications center** — Filter chips (All/SOS/Zones/Battery), grouped Today/Yesterday feed. Left-border color codes severity: red=SOS, amber=caution, plain=info. Each item: icon, title, plain-language body, timestamp.
2. **Visibility ledger** ("Who's viewed you") — Mutual-visibility explainer, "Today · 4 views" list of viewers w/ context ("Opened family map", "During your emergency alert" w/ SOS tag), "Pause my sharing".
3. **Privacy center** — Time-boxed sharing card (deep teal, "Sharing for 1 hour", auto-stop progress), "what you share" toggles (live location/history ON, wellness OFF), "Who can see me · 3 people", "Your data" (Export / Delete=red).

### 06 — Location History & Geofencing
1. **History timeline** — Date nav, vertical timeline of place stays + transit segments (walk/bus icons), live "currently walking home" node.
2. **Route + stats** — Map route line, bottom sheet stat tiles (distance/transit/stops), segment list.
3. **Geofence manage** ("Places & zones") — Mini map w/ colored zone circles, add button, zone list (Home/School/Workplace) w/ radius, who's-inside, enable toggle.
4. **Zone activity log** — Notify on enter/exit toggles, "this week" enter/left events per member w/ timing.

### 07 — Health & Wellness · Family Care
1. **Health dashboard** — Deep-teal health score 84 "Good" w/ explanation, stat tiles (steps/kcal/distance), weekly activity bars, sleep + resting HR tiles, bottom nav w/ Health active.
2. **Weekly report** — Date range, avg stat comparison w/ ▲▼ deltas, steps-per-day chart, AI insight callout, share.
3. **Family health overview** — Per-member wellness cards w/ score + status (Grandpa flagged amber "low activity"), "elderly-care alert" section.
4. **Elderly-care abnormal pattern** — Amber screen, "Unusual routine — Grandpa", AI "why we're flagging" (no movement since 9:00, usually active by 7:30), last movement/location/battery rows, "Call Grandpa" (green) / Send check-in / Mark OK.
5. **Family overview dashboard** — Summary tiles (avg safety/in circle/to check), per-member safety bars, combined activity line chart (2 series).

### 08 — Settings
1. **Settings** — Profile card (Maya, Guardian), Circle group (Roles & permissions, Emergency contacts=3, Silent/duress=On), Preferences group (Notifications, Privacy & sharing, Connected devices=2, Text size=Large).
2. **Connected devices** — Device cards (Apple Watch synced/76%, Fitbit 1h ago/54%, Add device), "data these devices share" toggles (Heart rate / Sleep / Steps).

---

## Interactions & Behavior
- **Navigation:** bottom tab bar (Map / Activity / SOS / Insights / Privacy) persists on primary screens; SOS is the raised center item on every tab. Sub-screens use back-arrow headers.
- **SOS arm:** press-and-hold 3s (see SOS section). Release early = cancel, nothing sent.
- **Walk-Me-Home:** live countdown; on overrun → escalation screen with a 2-min auto-escalate countdown the user can extend or convert to SOS.
- **Duress:** entering decoy PIN silently fires SOS + live stream while showing the weather decoy — no sound, vibration, or banner.
- **Toggles:** iOS-style switches; ON = teal `#15807C` (or mint on dark), OFF = `#DDE5E3`.
- **Explainability:** every anomaly/score/prediction/alert pairs its number with a short plain-language reason. Preserve this everywhere — never show a bare score.
- **Progress/streaming indicators:** blinking live dots + pulse rings on active-alert and live-tracking states.

## State Management
Suggested (map to your chosen approach — Riverpod/Bloc/Provider):
- `authState` (unauthenticated → registering → role-selected → in-circle)
- `circle` (members[], roles, permissions per member)
- `sosState` (idle → arming{progress 0–1} → armed → sent{responders[], elapsed} → resolved)
- `duressEnabled`, `decoyPin`
- `walkSession` (destination, watchers[], etaSeconds, status: active|arrived|late-escalating{countdown})
- `geofences[]` (name, radius, notifyEnter/Exit, occupants[])
- `insights` (safetyScore + reasons[], anomalies[], etaPredictions[])
- `privacy` (sharingToggles, timeBoxedShare{until}, visibilityLedger[])
- `health` (self metrics, familyWellness[], elderlyAlerts[])
- `connectedDevices[]`, `notificationPrefs`, `textScale`

Data fetching: live location stream (websocket/location plugin), geofence transitions (OS geofencing APIs), health data (HealthKit / Health Connect via a plugin), push notifications for all alert types.

## Assets
- **Logo:** an inline-SVG mark — a shield (protection) enclosing a winding path leading to a location pin, teal-on-deep-teal. Reproduce as a Flutter widget/`SvgPicture` or asset; see the two logo sites in `SafePath AI.dc.html` for exact geometry.
- **Icons:** Material Symbols Rounded throughout → map to `Icons.*` / `CupertinoIcons.*`.
- No photographic/raster assets are required by the design. (Three ChatGPT-generated images exist in the project from ideation but are NOT used in the final design.)

## Files
- `SafePath AI.dc.html` — the authored source (design system board + all 36 screens + the interactive SOS logic class). **Primary reference.**
- `SafePath AI - Standalone.html` — self-contained offline bundle of the same, convenient for viewing without any setup.

> Note: the `.dc.html` file is a "Design Component" format with a `<helmet>` head and inline-styled markup. Read it as HTML/CSS — the styling is all inline, and the only scripting is the SOS press-and-hold controller near the bottom.
