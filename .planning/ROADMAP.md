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

- [ ] **Phase 1: Backend & Auth Foundation** - Auth, roles, and family circles on a Clean Architecture backend + Supabase, with the app's design system wired into Flutter.
- [ ] **Phase 2: Real-Time Location, History & Privacy** - Family members see live and historical location on a shared map, with full privacy controls over what's shared.
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
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, FAM-01, FAM-02, FAM-03, FAM-04, FAM-05, DESIGN-01
**Success Criteria** (what must be TRUE):

  1. User can register with email/password, log in via JWT (access + refresh), and stay logged in across sessions (AUTH-01, AUTH-02)
  2. User can log out and reset a forgotten password via a one-time expiring emailed link (AUTH-03, AUTH-04)
  3. User is assigned a role (Guardian, Member, Caregiver, or org-level e.g. School Admin) during setup (AUTH-05)
  4. Guardian can create a family circle, invite a member by email, have them accept/reject, manage per-member permissions, and remove a member (FAM-01, FAM-02, FAM-03, FAM-04, FAM-05)
  5. Login, registration, and family-circle screens match the SafePath design system (colors, type, spacing, motion) via a shared Flutter `ThemeData`/`ColorScheme` (DESIGN-01)

**Plans**: 1/7 plans executed

- [ ] 01-01-PLAN.md
- [x] 01-02-PLAN.md
- [ ] 01-03-PLAN.md
- [ ] 01-04-PLAN.md
- [ ] 01-05-PLAN.md
- [ ] 01-06-PLAN.md
- [ ] 01-07-PLAN.md

**UI hint**: yes

### Phase 2: Real-Time Location, History & Privacy

**Goal**: Family members can see each other's live and past location, with full control over what's shared and with whom.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: LOC-01, LOC-02, LOC-03, LOC-04, LOC-05, HIST-01, HIST-02, HIST-03, NOTIF-01, PRIV-01, PRIV-02, PRIV-03, PRIV-04, PRIV-05
**Success Criteria** (what must be TRUE):

  1. User's live location updates on a shared family map, with each member's last-seen timestamp and online/offline status visible (LOC-01, LOC-02)
  2. User sees a stale-location indicator with accuracy radius, a battery-usage transparency screen, and an in-app permission-priming screen before the OS location prompt (LOC-03, LOC-04, LOC-05)
  3. User can view a family member's historical timeline, a route visualization of past travel, and travel statistics (distance, time away, stops) (HIST-01, HIST-02, HIST-03)
  4. User receives a low-battery alert for themselves or a family member (NOTIF-01)
  5. User can toggle sharing per data type/recipient, enable temporary auto-stopping location sharing, and export or delete their data from a Privacy Center — backed by end-to-end encrypted communication and a documented no-data-resale commitment (PRIV-01, PRIV-02, PRIV-03, PRIV-04, PRIV-05)

**Plans**: TBD
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
| 1. Backend & Auth Foundation | 1/7 | In Progress|  |
| 2. Real-Time Location, History & Privacy | 0/TBD | Not started | - |
| 3. SOS Fast Path (Core Value) | 0/TBD | Not started | - |
| 4. Geofencing | 0/TBD | Not started | - |
| 5. AI Analytics & Family Dashboard | 0/TBD | Not started | - |
| 6. Signature Safety Features | 0/TBD | Not started | - |
| 7. Health & Wellness Module | 0/TBD | Not started | - |

---
*Roadmap created: 2026-07-06*
*Granularity setting: standard — actual phase count (7) follows research's proposed 8-phase, core-value-first structure, with the SignalR real-time-layer phase folded into Phase 2 (Real-Time Location) since no v1 requirement uniquely required a standalone real-time-only phase; every other phase boundary from research is preserved.*
