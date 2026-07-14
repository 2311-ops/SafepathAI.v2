# Roadmap: SafePath AI

## Overview

SafePath AI is built core-value-first: prove that SOS always works before any AI or signature
feature exists to complicate it. The journey starts with a backend + auth + family-circle walking
skeleton (Phase 1), then stands up real-time location tracking with privacy controls (Phase 2) —
the minimum data plumbing SOS needs. Phase 3 proves the non-negotiable Core Value end-to-end: a
structurally isolated SOS fast path that bypasses every other pipeline. Geofencing (Phase 4) and
explainable AI analytics + dashboards (Phase 5) layer smart, degrade-gracefully behavior on top of
the now-solid core. Phase 6 delivers the five signature safety differentiators (Walk-Me-Home,
Silent/Duress, Mutual Visibility Ledger, Predictive Geofencing, Cross-Modal detection), each
riding existing infrastructure rather than a shared new pipeline. Phase 7 adds the optional
Health & Wellness module last, since nothing but Cross-Modal detection depends on it and that
dependency is satisfied with seeded/synthetic data.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Backend & Auth Foundation** - Auth, roles, and family circles on a Clean Architecture backend + Supabase, with the app's design system wired into Flutter.
- [ ] **Phase 2: Real-Time Location, History & Privacy** - Family members see live and historical location on a shared map, with full privacy controls over what's shared. (17/17 plans complete; re-verification 2026-07-14 scored 20/21 must-haves — 1 pending human device confirmation of the UAT-72 header-avatar fix, see 02-UAT.md test 73)
- [ ] **Phase 3: SOS Fast Path (Core Value)** - One tap (or covert trigger) reliably alerts guardians with live location within seconds, bypassing every routine and AI pipeline.
- [ ] **Phase 4: Geofencing** - Safe zones trigger reliable enter/exit alerts without GPS-drift false positives.
- [ ] **Phase 5: AI Analytics & Family Dashboard** - Explainable anomaly detection, ETA prediction, safety scoring, and family dashboards.
- [ ] **Phase 6: Signature Safety Features** - Walk-Me-Home, Silent/Duress SOS, Mutual Visibility Ledger, Predictive Geofencing, and Cross-Modal detection.
- [ ] **Phase 7: Health & Wellness Module** - Optional health tracking with a family/elderly-care overview.

## Phase Details

### Phase 1: Backend & Auth Foundation

**Goal**: Users can securely create an account and set up their family circle with defined roles, on infrastructure that everything else builds on.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, FAM-01, FAM-02, FAM-03, FAM-04, FAM-05, DESIGN-01
**Success Criteria** (what must be TRUE):

  1. User can register with email/password, log in via JWT (access + refresh), and stay logged in across sessions (AUTH-01, AUTH-02)
  2. User can log out and reset a forgotten password via a one-time expiring emailed link (AUTH-03, AUTH-04)
  3. User is assigned a role (Guardian, Member, Caregiver, or org-level e.g. School Admin) during setup (AUTH-05)
  4. Guardian can create a family circle, invite a member by email, have them accept/reject, manage per-member permissions, and remove a member (FAM-01, FAM-02, FAM-03, FAM-04, FAM-05)
  5. Login, registration, and family-circle screens match the SafePath design system (colors, type, spacing, motion) via a shared Flutter `ThemeData`/`ColorScheme` (DESIGN-01)
  6. User can sign in with Google via Supabase's native OAuth from Welcome/Login/Register, alongside existing email/password auth (AUTH-06)

**Plans**: 14/14 plans executed and reviewed (01-11..01-14 added from cross-AI review - 01-REVIEWS.md)

- [x] 01-01-PLAN.md
- [x] 01-02-PLAN.md
- [x] 01-03-PLAN.md
- [x] 01-04-PLAN.md (superseded — zero code needed, see SUMMARY)
- [x] 01-05-PLAN.md
- [x] 01-06-PLAN.md (superseded — satisfied via Supabase Auth, see SUMMARY)
- [x] 01-07-PLAN.md
- [x] 01-08-PLAN.md (partially superseded by 01-09 — browser OAuth flow replaced by native picker)
- [x] 01-09-PLAN.md
- [x] 01-10-PLAN.md (gap closure — GET /families/mine, found during Phase 1 manual UAT)
- [x] 01-11-PLAN.md - review: Supabase-owned-auth ADR + secrets/.env bootstrap + /me role-from-DB
- [x] 01-12-PLAN.md - review: single-family invariant (409) + Guardian invite-revoke
- [x] 01-13-PLAN.md - review: transfer-ownership + delete-family + FK/cascade migration + RLS decision
- [x] 01-14-PLAN.md - review: QR/deep-link invite redemption + distinct decline + amber/expired reset UX

**UI hint**: yes

### Phase 01.1: Animated Logo Splash Screen (INSERTED)

**Goal:** On cold launch the app shows a calm, on-brand animated SafePath logo splash exactly once, then hands off to the existing router destination (Home if authenticated, Welcome if not) — additive only, with zero changes to auth, session, or routing semantics.
**Requirements**: none (inserted decimal phase; no REQ-IDs mapped)
**Depends on:** Phase 1
**Plans:** 2/2 plans executed

Plans:
**Wave 1**

- [x] 01.1-01-PLAN.md — SplashScreen widget + splashAnimationCompleteProvider + additive /splash route & redirect gate

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01.1-02-PLAN.md — Deterministic splash/gate tests, full-suite regression pass, human visual sign-off

### Phase 2: Real-Time Location, History & Privacy

**Goal**: As a family member, I want to see my family's live and past location and control exactly what I share and with whom, so that we can stay connected safely without giving up privacy.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: LOC-01, LOC-02, LOC-03, LOC-04, LOC-05, HIST-01, HIST-02, HIST-03, NOTIF-01, PRIV-01, PRIV-02, PRIV-03, PRIV-04, PRIV-05, PROFILE-01, PROFILE-02, PROFILE-03, PROFILE-04, PROFILE-05, PROFILE-06, PROFILE-07
**Success Criteria** (what must be TRUE):

  1. User's live location updates on a shared family map, with each member's last-seen timestamp and online/offline status visible (LOC-01, LOC-02)
  2. User sees a stale-location indicator with accuracy radius, a battery-usage transparency screen, and an in-app permission-priming screen before the OS location prompt (LOC-03, LOC-04, LOC-05)
  3. User can view a family member's historical timeline, a route visualization of past travel, and travel statistics (distance, time away, stops) (HIST-01, HIST-02, HIST-03)
  4. User receives a low-battery alert for themselves or a family member (NOTIF-01)
  5. User can toggle sharing per data type/recipient, enable temporary auto-stopping location sharing, and export or delete their data from a Privacy Center — backed by end-to-end encrypted communication and a documented no-data-resale commitment (PRIV-01, PRIV-02, PRIV-03, PRIV-04, PRIV-05)
  6. User can upload, replace, and remove their profile picture and edit their display name; every visible family member appears on the live map as a custom marker showing their avatar (or a default avatar), name, online/offline status, and current location, updating in real time — visible only to members of the same Family Circle (PROFILE-01, PROFILE-02, PROFILE-03, PROFILE-04, PROFILE-05, PROFILE-06, PROFILE-07)

**Plans**: 17/17 plans complete
**Map SDK retrofit complete (2026-07-13)**: originally shipped on `google_maps_flutter`; project direction changed to OpenStreetMap and executed in `02-12-PLAN.md` (`live_map_screen.dart` + `route_stats_sheet.dart` now on `flutter_map`/`latlong2`, native Google-Maps-key wiring removed from Android/iOS). iOS build is source-verified only (no macOS/CI runner available here) — validate the actual Xcode compile before an iOS release build. Before production traffic, replace the raw `tile.openstreetmap.org` URL with a dedicated tile-hosting provider per OSM's tile usage policy (documented in `02-01-USER-SETUP.md`). See `.planning/phases/02-real-time-location-history-privacy/02-OSM-MIGRATION-IMPACT.md`.

Plans:

**Wave 1**

- [x] 02-01-PLAN.md — Real-time transport walking skeleton + signalr_netcore [SUS] spike (LOC-01/02, PRIV-01)

**Wave 2** *(blocked on Wave 1)*

- [x] 02-02-PLAN.md — Location persistence + live broadcast + dual-signal presence (LOC-01/02/03)

**Wave 3** *(blocked on Wave 2)*

- [x] 02-03-PLAN.md — Privacy sharing matrix + temporary sharing + broadcast/read double-gate (PRIV-02/03/01)
- [x] 02-06-PLAN.md — Mobile app shell + permission priming + battery screen + self-location Live Map (LOC-01/04/05)

**Wave 4** *(blocked on Wave 3)*

- [x] 02-04-PLAN.md — Location history + route polyline + travel stats (HIST-01/02/03)
- [x] 02-07-PLAN.md — Mobile family presence + staleness/accuracy + low-battery banner (LOC-02/03, NOTIF-01)

**Wave 5** *(blocked on Wave 4)*

- [x] 02-05-PLAN.md — Low-battery alert + data export/delete + no-data-resale policy (NOTIF-01, PRIV-04/05)
- [x] 02-08-PLAN.md — Mobile history timeline + route + stats screens (HIST-01/02/03)

**Wave 6** *(blocked on Wave 5)*

- [x] 02-09-PLAN.md — Mobile Privacy Center: sharing matrix + temporary sharing + export/delete + policy (PRIV-02/03/04/05)

**Wave 7** *(gaps-only LOC-05 and PRIV-03 closure)*

- [x] 02-10-PLAN.md - /home permission gate + LocationController streaming guard (LOC-05)
- [x] 02-11-PLAN.md - recipient-scoped temporary sharing + custom duration input (PRIV-03)

**Wave 8** *(additive OSM map-renderer retrofit — post-close, planned 2026-07-13)*

- [x] 02-12-PLAN.md — migrate map rendering from google_maps_flutter to flutter_map/OpenStreetMap (LOC-01/02/04, HIST-02)

**Wave 9** *(additive User Profile & Map Identity — post-close, planned 2026-07-13)*

- [x] 02-13-PLAN.md — backend: User profile fields + EF migration + Supabase Storage client + image validation/re-encode (PROFILE-01/02/03)

**Wave 10** *(blocked on Wave 9)*

- [x] 02-14-PLAN.md — backend: profile endpoints (display-name/upload/delete) + signed profileImageUrl on live-locations + ProfileUpdated SignalR event (PROFILE-01..07)

**Wave 11** *(blocked on Wave 10)*

- [x] 02-15-PLAN.md — mobile: profile data/controller + view/edit profile screen (upload/replace/remove + display name) (PROFILE-01/02/03/04/05)

**Wave 12** *(blocked on Wave 10 + Wave 11)*

- [x] 02-16-PLAN.md — mobile: live-map avatar markers + always-visible name labels + real-time ProfileUpdated rendering (PROFILE-06/07)

**Wave 13** *(gap closure — UAT test 72, planned 2026-07-14)*

- [x] 02-17-PLAN.md — mobile: wire Live Map header identity pin to selfPosition so the header avatar live-updates on profile-photo change (PROFILE-03/06)

**UI hint**: yes

### Phase 3: SOS Fast Path (Core Value)

**Goal**: The SOS system always works — a single tap or covert trigger reliably reaches guardians with live location within seconds, no matter what else is happening in the app.
**Mode:** mvp
**Depends on**: Phase 1, Phase 2
**Requirements**: SOS-01, SOS-02, SOS-03, SOS-04, SOS-05, SOS-06, NOTIF-03, DESIGN-02
**Success Criteria** (what must be TRUE):

  1. User can trigger SOS via the large, always-visible one-tap button (built exactly to spec: raised center of bottom nav, 64px circle, 3-second press-and-hold arming with a circular progress ring, release-to-cancel), immediately alerting guardians with live location and bypassing routine/AI processing (SOS-01, DESIGN-02)
  2. Guardian/emergency contact receives the SOS alert through multiple channels (push + SMS fallback) with server-side delivery-acknowledgment tracking, and a corresponding in-app SOS notification (SOS-02, NOTIF-03)
  3. If there's no network connectivity at trigger time, the app queues and retries delivery and shows the user a clear "not sent yet" state (SOS-03)
  4. Responders see the user's location streaming live for a fixed window after the SOS trigger (SOS-04)
  5. User can self-cancel a false alarm through a channel that runs in parallel to — and never delays — the guardian alert, and can also trigger SOS via an OS-level backup shortcut (side-button sequence, Accessibility shortcut, or lock-screen widget) (SOS-05, SOS-06)

**Plans**: TBD
**UI hint**: yes

### Phase 4: Geofencing

**Goal**: Guardians know when family members enter or leave defined safe zones, without false alarms from GPS drift.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: GEO-01, GEO-02, GEO-03, NOTIF-02
**Success Criteria** (what must be TRUE):

  1. Guardian can create a safe zone (Home, School, University, Workplace) with a defined radius (GEO-01)
  2. User/guardian receives enter/exit notifications for a safe zone, using native OS geofencing APIs with dwell-time/hysteresis so GPS drift doesn't cause false positives (GEO-02, NOTIF-02)
  3. User can view a zone activity log per geofence (GEO-03)

**Plans**: TBD
**UI hint**: yes
**Map dependency note**: Zone radius drawing/visualization uses the same map renderer as Phase 2 (OpenStreetMap via `flutter_map`, changed 2026-07-13 from Google Maps — see `.planning/phases/02-real-time-location-history-privacy/02-OSM-MIGRATION-IMPACT.md`). Geofence *detection* itself (`native_geofence`, native OS APIs) is unaffected by the map SDK choice.

### Phase 5: AI Analytics & Family Dashboard

**Goal**: Families get explainable AI insight into safety and activity, not just raw data.
**Mode:** mvp
**Depends on**: Phase 2, Phase 4
**Requirements**: AI-01, AI-02, AI-03, AI-04, AI-05, DASH-01, DASH-02, DASH-03, NOTIF-04, NOTIF-05
**Success Criteria** (what must be TRUE):

  1. System detects an unusual route, stop, or movement pattern and shows a plain-language explanation, using a per-user/family baseline with cold-start suppression so it doesn't fire on normal but varied routines (AI-01, AI-05)
  2. System predicts a user's arrival time with a confidence range and computes a single, explainable safety score per user (AI-02, AI-03)
  3. User sees a daily movement summary and weekly activity report, and receives an inactivity alert when warranted (AI-04, NOTIF-04)
  4. Push notifications for AI-driven alerts carry the plain-language explanation, not a bare alert (NOTIF-05)
  5. User sees a family overview dashboard (combined activity and safety metrics), activity charts for a selected family member, and a location heatmap of visited places (DASH-01, DASH-02, DASH-03)

**Plans**: TBD
**UI hint**: yes

### Phase 6: Signature Safety Features

**Goal**: SafePath's five signature safety differentiators work end-to-end, each degrading gracefully instead of failing silently.
**Mode:** mvp
**Depends on**: Phase 3, Phase 4, Phase 5
**Requirements**: WALK-01, WALK-02, WALK-03, DURESS-01, DURESS-02, DURESS-03, LEDGER-01, LEDGER-02, LEDGER-03, PGEO-01, PGEO-02, XMOD-01, XMOD-02, EXTRA-01
**Success Criteria** (what must be TRUE):

  1. User can start a Walk-Me-Home session to a chosen destination with a live ETA countdown; designated watchers are notified if the user doesn't arrive in the predicted window, and an unresolved overrun auto-escalates into the SOS pipeline after a grace period (WALK-01, WALK-02, WALK-03)
  2. User can configure a covert Silent/Duress trigger (decoy PIN or gesture) that fires the identical SOS alert pipeline behind a normal-looking decoy screen with no visible delay, sound, or vibration, with the secret stored in platform secure storage in a form never recoverable in a way that could endanger the user under coercion (DURESS-01, DURESS-02, DURESS-03)
  3. Every location view is logged (viewer, viewed user, timestamp, context); the viewed user can see who's viewed their location and when, and must give explicit consent before that access is re-shared or extended (LEDGER-01, LEDGER-02, LEDGER-03)
  4. System learns each user's typical arrival/departure pattern at a zone and raises a soft alert when behavior deviates from that baseline before any hard boundary is crossed, degrading gracefully (no false soft-alerts) during cold-start for a new user or zone (PGEO-01, PGEO-02)
  5. System correlates a sudden stop in movement with an abnormal health signal (real or seeded/synthetic where real events aren't available) to auto-escalate to SOS, and reuses that same pipeline to detect a phone-accelerometer crash/fall event without requiring a wearable (XMOD-01, XMOD-02, EXTRA-01)

**Plans**: TBD
**UI hint**: yes

### Phase 7: Health & Wellness Module

**Goal**: Families get an optional, privacy-respecting view into health and wellness, useful for elderly-care monitoring.
**Mode:** mvp
**Depends on**: Phase 1, Phase 2
**Requirements**: HEALTH-01, HEALTH-02, HEALTH-03
**Success Criteria** (what must be TRUE):

  1. User sees a daily/weekly health dashboard (steps, calories, distance) (HEALTH-01)
  2. User can connect a wearable (Apple Watch/Wear OS) via HealthKit/Health Connect, with narrowly-scoped permission requests made only at first use of each feature (HEALTH-02)
  3. Guardian/caregiver sees a family health overview with elderly-care abnormal-pattern alerts (e.g. prolonged inactivity) (HEALTH-03)

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Backend & Auth Foundation | 14/14 | Complete | 2026-07-10 |
| 2. Real-Time Location, History & Privacy | 17/17 | Complete   | 2026-07-14 |
| 3. SOS Fast Path (Core Value) | 0/TBD | Not started | - |
| 4. Geofencing | 0/TBD | Not started | - |
| 5. AI Analytics & Family Dashboard | 0/TBD | Not started | - |
| 6. Signature Safety Features | 0/TBD | Not started | - |
| 7. Health & Wellness Module | 0/TBD | Not started | - |

---
*Roadmap created: 2026-07-06*
*Granularity setting: standard — actual phase count (7) follows research's proposed 8-phase, core-value-first structure, with the SignalR real-time-layer phase folded into Phase 2 (Real-Time Location) since no v1 requirement uniquely required a standalone real-time-only phase; every other phase boundary from research is preserved.*
