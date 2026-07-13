# Requirements: SafePath AI

**Defined:** 2026-07-06
**Core Value:** The SOS system must always work — a single tap or covert Silent/Duress trigger reliably delivers an immediate alert with live location to a user's designated guardians within seconds, bypassing every routine and AI pipeline.

## v1 Requirements

### Authentication (AUTH)

- [x] **AUTH-01**: User can register with email and password
- [x] **AUTH-02**: User can log in via JWT (access + refresh tokens) and stay logged in across sessions
- [x] **AUTH-03**: User can log out
- [x] **AUTH-04**: User can reset their password via a one-time, expiring emailed link
- [x] **AUTH-05**: User is assigned a role (Guardian, Member, Caregiver, or org-level e.g. School Admin) during setup
- [x] **AUTH-06**: User can sign in with Google (Supabase-native OAuth) alongside email/password, from Welcome/Login/Register

### Family Groups (FAM)

- [x] **FAM-01**: User can create a family circle
- [x] **FAM-02**: User can invite a family member by email
- [x] **FAM-03**: Invited user can accept or reject an invitation
- [x] **FAM-04**: Guardian can manage per-member permissions (view-only, full-location, notification-only)
- [x] **FAM-05**: Guardian can remove a member from the circle

### Real-Time Location Tracking (LOC)

- [x] **LOC-01**: User's live location updates continuously and appears on a shared family map
- [x] **LOC-02**: User sees each family member's last-seen timestamp and online/offline status
- [x] **LOC-03**: User sees a stale-location indicator with a visible accuracy radius when location data is old or imprecise
- [x] **LOC-04**: User sees a battery-usage transparency screen explaining what background tracking costs in battery
- [x] **LOC-05**: User sees an in-app permission-priming screen before the OS location-permission dialog appears

### Location History (HIST)

- [x] **HIST-01**: User can view a historical timeline of a family member's stays and movements
- [x] **HIST-02**: User can view a route visualization of past travel
- [x] **HIST-03**: User can view travel statistics (distance, time away, stops)

### User Profile & Map Identity (PROFILE)

- [x] **PROFILE-01**: User can upload a profile picture, stored in Supabase Storage (private bucket) with only the image path/URL persisted in the database
- [x] **PROFILE-02**: User can replace their existing profile picture
- [x] **PROFILE-03**: User can remove their profile picture, reverting to the default avatar everywhere it's shown
- [ ] **PROFILE-04**: User can edit their display name, shown on their map marker and profile
- [ ] **PROFILE-05**: User can view their own profile (display name, profile picture, role)
- [ ] **PROFILE-06**: Live family map renders every visible family member as a custom marker with a circular avatar (or default avatar), display name above the marker, an online/offline indicator, and current location, updating in real time as they move
- [ ] **PROFILE-07**: Guardian view shows every family member's avatar, name, live location, and status; Member view shows the guardian and other approved family members' avatars, names, and live locations — scoped to the same Family Circle only

### Geofencing (GEO)

- [ ] **GEO-01**: Guardian can create a safe zone (Home, School, University, Workplace) with a defined radius
- [ ] **GEO-02**: User/guardian receives enter/exit notifications for a safe zone, using native OS geofencing APIs with dwell-time/hysteresis to prevent GPS-drift false positives
- [ ] **GEO-03**: User can view a zone activity log per geofence

### Emergency SOS System (SOS)

- [ ] **SOS-01**: User can trigger an emergency SOS via a large, always-visible one-tap button that immediately alerts designated guardians/hosts with live location, bypassing routine and AI processing
- [ ] **SOS-02**: Guardian/emergency contact receives the SOS alert through multiple channels (SignalR push + FCM + SMS fallback) with server-side delivery-acknowledgment tracking
- [ ] **SOS-03**: If there's no network connectivity at the moment of SOS trigger, the app queues and retries delivery and shows the user a clear "not sent yet" state
- [ ] **SOS-04**: User's location streams live to responders for a fixed window after an SOS trigger
- [ ] **SOS-05**: User can cancel a false SOS alarm via a self-cancel channel that runs in parallel to — and never delays — the guardian alert
- [ ] **SOS-06**: SOS can also be triggered via an OS-level backup shortcut (side-button sequence, Android Accessibility shortcut, or lock-screen widget)

### Smart Notifications (NOTIF)

- [x] **NOTIF-01**: User receives a low-battery alert for themselves or a family member
- [ ] **NOTIF-02**: User receives a geofence enter/exit alert
- [ ] **NOTIF-03**: User receives an SOS alert
- [ ] **NOTIF-04**: User receives an inactivity alert
- [ ] **NOTIF-05**: Alert push notifications carry the plain-language explanation, not just a bare alert

### AI Features (AI)

- [ ] **AI-01**: System detects an unusual route, stop, or movement pattern (Isolation Forest) and shows a plain-language explanation
- [ ] **AI-02**: System predicts a user's arrival time (XGBoost) with a confidence range
- [ ] **AI-03**: System computes a single, explainable safety score per user from recent behavior
- [ ] **AI-04**: System generates a daily movement summary and a weekly activity report
- [ ] **AI-05**: Anomaly detection is baselined per user/family with a cold-start suppression period to avoid alert fatigue on normal but varied routines

### Dashboard and Analytics (DASH)

- [ ] **DASH-01**: User sees a family overview dashboard (combined activity, safety metrics)
- [ ] **DASH-02**: User sees activity charts for a selected family member
- [ ] **DASH-03**: User sees a location heatmap of visited places

### Privacy and Security (PRIV)

- [x] **PRIV-01**: All sensitive communication is end-to-end encrypted
- [x] **PRIV-02**: User can toggle sharing per data type (live location, history, wellness) and per recipient
- [x] **PRIV-03**: User can enable temporary, time-boxed location sharing that auto-stops
- [x] **PRIV-04**: User can export or delete their data from a Privacy Center
- [x] **PRIV-05**: Platform maintains a documented, verifiable no-data-resale commitment

### Walk-Me-Home Mode (WALK)

- [ ] **WALK-01**: User can start a Walk-Me-Home session to a chosen destination with a live ETA countdown
- [ ] **WALK-02**: Designated watchers are notified if the user doesn't arrive within the predicted window
- [ ] **WALK-03**: An unresolved Walk-Me-Home overrun auto-escalates into the SOS alert pipeline after a grace period

### Silent / Duress SOS (DURESS)

- [ ] **DURESS-01**: User can configure a covert Silent/Duress trigger (decoy PIN or gesture)
- [ ] **DURESS-02**: Triggering Duress fires the identical SOS alert pipeline while the screen shows a normal-looking decoy state (e.g. a weather app), with no visible delay, sound, or vibration
- [ ] **DURESS-03**: The duress trigger secret is stored using platform secure storage, never in a form recoverable in a way that could endanger the user under coercion

### Mutual Visibility Ledger (LEDGER)

- [ ] **LEDGER-01**: Every location view is logged (viewer, viewed user, timestamp, context)
- [ ] **LEDGER-02**: Viewed user can see "who's viewed your location" with context and timestamps
- [ ] **LEDGER-03**: User must give explicit consent before their granted view access is re-shared or extended to another person

### Predictive (Soft) Geofencing (PGEO)

- [ ] **PGEO-01**: System learns each user's typical arrival/departure pattern at a zone and raises a soft alert when behavior deviates from that baseline, before any hard boundary is crossed
- [ ] **PGEO-02**: Predictive geofencing degrades gracefully (no false soft-alerts) during the cold-start period for a new user or newly created zone

### Cross-Modal Anomaly Detection (XMOD)

- [ ] **XMOD-01**: System correlates a sudden stop in movement with an abnormal health signal (from the Health module) and can auto-escalate to the SOS pipeline
- [ ] **XMOD-02**: Cross-modal detection uses seeded/synthetic test data where real anomalous health events aren't available for demonstration

### Health & Wellness (HEALTH)

- [ ] **HEALTH-01**: User sees a daily/weekly health dashboard (steps, calories, distance)
- [ ] **HEALTH-02**: User can connect a wearable (Apple Watch/Wear OS) via HealthKit/Health Connect, with narrowly-scoped permission requests at first use of each feature
- [ ] **HEALTH-03**: Guardian/caregiver sees a family health overview with elderly-care abnormal-pattern alerts (e.g. prolonged inactivity)

### Signature Extras (EXTRA)

- [ ] **EXTRA-01**: System detects a phone-accelerometer crash/fall event, reusing the Cross-Modal Anomaly pipeline, without requiring a wearable

### Design System (DESIGN)

- [x] **DESIGN-01**: Every screen matches the existing 36-screen design system (colors, type, spacing, motion) recreated as Flutter widgets/`ThemeData`
- [ ] **DESIGN-02**: The SOS button is implemented exactly per spec: always-visible, raised center of bottom nav, 64px circle, 3-second press-and-hold arming with a circular progress ring, release-to-cancel

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Family Groups

- **FAM-06**: Companion/Kiosk Mode — a software-only account profile giving a non-smartphone family member (e.g. a young child on a hand-me-down device) a presence in the family circle

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Proprietary/dedicated hardware of any kind | Software-only is a core competitive differentiator (vs. AngelSense/Jiobit/GeoZilla) |
| Driving-behavior analytics (harsh braking/acceleration) | Future enhancement per brief Section 19 |
| Federated learning / differential privacy for on-device training | Future enhancement per brief Section 19 |
| Wearable integration as a hard dependency | Health data is optional/supplementary; Cross-Modal Detection can use seeded/synthetic data instead |
| Multi-language support | Future enhancement per brief Section 19 |
| Organization-tier fleet/school dashboards, bulk geofence management | Future enhancement per brief Section 19 |
| Voice-activated SOS | Future enhancement per brief Section 19 |
| Human-staffed 24/7 dispatch center | Not code-buildable; incompatible with solo-dev scope |
| A second memorized duress PIN | Documented UX failure mode (ATM SafetyPIN precedent) — the decoy-gesture pattern is used instead |
| Training AI models from scratch pre-launch instead of seeded/synthetic data | Real anomalous events are hard to produce on demand; already correctly scoped this way in the brief |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Pending |
| AUTH-02 | Phase 1 | Pending |
| AUTH-03 | Phase 1 | Pending |
| AUTH-04 | Phase 1 | Pending |
| AUTH-05 | Phase 1 | Pending |
| AUTH-06 | Phase 1 | Complete |
| FAM-01 | Phase 1 | Complete |
| FAM-02 | Phase 1 | Complete |
| FAM-03 | Phase 1 | Complete |
| FAM-04 | Phase 1 | Complete |
| FAM-05 | Phase 1 | Complete |
| DESIGN-01 | Phase 1 | Complete |
| LOC-01 | Phase 2 | Complete |
| LOC-02 | Phase 2 | Complete |
| LOC-03 | Phase 2 | Complete |
| LOC-04 | Phase 2 | Complete |
| LOC-05 | Phase 2 | Complete |
| HIST-01 | Phase 2 | Complete |
| HIST-02 | Phase 2 | Complete |
| HIST-03 | Phase 2 | Complete |
| NOTIF-01 | Phase 2 | Complete |
| PRIV-01 | Phase 2 | Complete |
| PRIV-02 | Phase 2 | Complete |
| PRIV-03 | Phase 2 | Complete |
| PRIV-04 | Phase 2 | Complete |
| PRIV-05 | Phase 2 | Complete |
| PROFILE-01 | Phase 2 | Complete |
| PROFILE-02 | Phase 2 | Complete |
| PROFILE-03 | Phase 2 | Complete |
| PROFILE-04 | Phase 2 | Pending |
| PROFILE-05 | Phase 2 | Pending |
| PROFILE-06 | Phase 2 | Pending |
| PROFILE-07 | Phase 2 | Pending |
| SOS-01 | Phase 3 | Pending |
| SOS-02 | Phase 3 | Pending |
| SOS-03 | Phase 3 | Pending |
| SOS-04 | Phase 3 | Pending |
| SOS-05 | Phase 3 | Pending |
| SOS-06 | Phase 3 | Pending |
| NOTIF-03 | Phase 3 | Pending |
| DESIGN-02 | Phase 3 | Pending |
| GEO-01 | Phase 4 | Pending |
| GEO-02 | Phase 4 | Pending |
| GEO-03 | Phase 4 | Pending |
| NOTIF-02 | Phase 4 | Pending |
| AI-01 | Phase 5 | Pending |
| AI-02 | Phase 5 | Pending |
| AI-03 | Phase 5 | Pending |
| AI-04 | Phase 5 | Pending |
| AI-05 | Phase 5 | Pending |
| DASH-01 | Phase 5 | Pending |
| DASH-02 | Phase 5 | Pending |
| DASH-03 | Phase 5 | Pending |
| NOTIF-04 | Phase 5 | Pending |
| NOTIF-05 | Phase 5 | Pending |
| WALK-01 | Phase 6 | Pending |
| WALK-02 | Phase 6 | Pending |
| WALK-03 | Phase 6 | Pending |
| DURESS-01 | Phase 6 | Pending |
| DURESS-02 | Phase 6 | Pending |
| DURESS-03 | Phase 6 | Pending |
| LEDGER-01 | Phase 6 | Pending |
| LEDGER-02 | Phase 6 | Pending |
| LEDGER-03 | Phase 6 | Pending |
| PGEO-01 | Phase 6 | Pending |
| PGEO-02 | Phase 6 | Pending |
| XMOD-01 | Phase 6 | Pending |
| XMOD-02 | Phase 6 | Pending |
| EXTRA-01 | Phase 6 | Pending |
| HEALTH-01 | Phase 7 | Pending |
| HEALTH-02 | Phase 7 | Pending |
| HEALTH-03 | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 71 total
- Mapped to phases: 71 (100%)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-06*
*Last updated: 2026-07-06 after roadmap creation (traceability populated; corrected v1 requirement count from 56 to 64 to match the actual requirement list above)*
*Updated 2026-07-13: added PROFILE-01..07 (User Profile & Map Identity) as an additive post-close wave on Phase 2 — v1 requirement count now 71.*
