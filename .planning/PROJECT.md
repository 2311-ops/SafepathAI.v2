# SafePath AI

## What This Is

SafePath AI is a software-only, cross-platform family-safety and real-time location-intelligence
platform: a Flutter mobile app (Android + iOS), an ASP.NET Core backend (Clean Architecture),
a Supabase/PostgreSQL database, and a Python AI analytics layer. It gives every family one
continuous safety graph across every life stage — live location tracking, geofencing, an
always-visible SOS system, explainable AI analytics (anomaly detection, ETA prediction, safety
scoring, activity analysis), and an optional health & wellness module — with a privacy-first,
no-data-resale, explainable-AI positioning throughout.

## Core Value

The SOS system must always work: a single tap on the visible SOS button, or a covert
Silent/Duress trigger, reliably delivers an immediate alert with live location to a user's
designated guardians and emergency contacts within seconds — bypassing every routine and AI
pipeline. Everything else in the app (tracking, AI insights, geofencing) supports this
guarantee; none of it may ever slow it down.

## Requirements

### Validated

- ✓ Real-time location tracking: live map, last-seen status, online/offline indicators — Phase 02
- ✓ Location history: timeline view, route visualization, travel statistics — Phase 02
- ✓ Privacy by design (location scope): user-controlled/temporary sharing, granular per-recipient privacy settings, verifiable no-data-resale policy copy, one-tap export/delete of location data — Phase 02
- ✓ User profile identity: display name + profile photo, editable, propagating live to the map header and family member markers via SignalR `ProfileUpdated` — Phase 02 (emerged mid-phase, not in original requirement list)
- ✓ Always-visible emergency SOS system: one-tap arm (3s hold) + OS-level home-screen backup shortcut (no arming hold), parallel non-destructive self-cancel (2s hold), multi-channel guardian/emergency-contact delivery (SignalR AlertHub + FCM push + SMS fallback) with honest per-recipient/per-channel delivery status, offline queue/retry surviving app-kill, and a server-authoritative live-location streaming window — structurally isolated from the routine location/AI pipeline throughout — Phase 03

### Active

- [ ] Secure authentication & role-based family groups (Guardian, Member, Caregiver, org roles e.g. School Admin)
- [ ] Family group management: create circles, invite/accept/reject members, per-member permissions
- [ ] Geofencing: safe zones (Home/School/University/Workplace), enter/exit notifications, zone activity log
- [ ] Smart notifications: low battery (delivered — Phase 02), SOS alert (delivered — Phase 03), geofence, inactivity alerts
- [ ] AI analytics: anomaly detection (Isolation Forest), ETA prediction (XGBoost), safety scoring, activity analysis — each paired with a plain-language explanation via the Explainability Layer
- [ ] Family dashboard & analytics: family overview, activity charts, location heatmaps, safety metrics
- [ ] Privacy by design (remaining): end-to-end encrypted communication (messaging, not location — not yet addressed)
- [ ] Walk-Me-Home mode: proactive ETA-based session that auto-escalates to the SOS pipeline on overrun
- [ ] Silent/Duress SOS: covert trigger (decoy PIN/gesture) firing the same alert pipeline behind a normal-looking decoy screen
- [ ] Mutual Visibility Ledger: logs and surfaces every location view back to the person who was viewed
- [ ] Predictive (Soft) Geofencing: baseline-deviation alerts before a hard boundary is crossed
- [ ] Cross-Modal Anomaly Detection: fused location + health signals, can auto-escalate to SOS (depends on Health module)
- [ ] Health & Wellness module: steps/calories/sleep/heart rate, health score, family health overview, elderly-care abnormal-pattern alerts
- [ ] Full Flutter recreation of the existing 36-screen design system (Material 3 / Cupertino-adaptive), wiring the design tokens in `SYSTEM_DESIGN (1).md` into `ThemeData`/`ColorScheme`

### Out of Scope

- Proprietary/dedicated hardware of any kind — the platform is explicitly software-only; this is a core differentiator (vs. AngelSense/Jiobit/GeoZilla)
- Driving-behavior analytics (harsh braking/acceleration) — future enhancement
- Federated learning / differential privacy for on-device training — future enhancement
- Wearable integration (Apple Watch/Wear OS) as a hard dependency — optional/future; Cross-Modal detection can use seeded/synthetic health data instead
- Multi-language support — future enhancement
- Organization-tier fleet/school dashboards, bulk geofence management — future enhancement
- Voice-activated SOS — future enhancement

## Context

- A complete design system already exists: 36 high-fidelity screens across 8 feature sets,
  authored as HTML/CSS references (`SafePath AI.dc (1).html`, `SafePath AI - Standalone (1).html`)
  plus a design-token README (`SYSTEM_DESIGN (1).md`) and a Flutter logo widget
  (`safepath_logo (1).dart` / `.svg`). These are visual specs, not production code — Flutter
  widgets must be built to match them. The README wins over the HTML on any conflict.
- A detailed graduation-project brief already exists (`SafePathAI_Master_Brief_enhanced_features.docx`,
  rev 3.1) covering competitive landscape/differentiation, full system architecture, database
  schema & ERD, the AI/analytics layer, security architecture, and technology stack. Treat it as
  an authoritative source alongside this document and `REQUIREMENTS.md`.
- Solo developer (Youssef Hassan), graduation project, no hard submission deadline currently driving phasing.
- Nothing is provisioned yet: no Supabase project, no Azure resources, no Firebase project — the
  roadmap must include setting these up from scratch.
- Git history starts clean: this folder previously had no dedicated repo (it inherited a stray
  git root at the user's home directory tracking an unrelated GitHub remote). A fresh repo was
  initialized here with origin `https://github.com/2311-ops/SafepathAI.v2.git`.

## Constraints

- **Tech stack**: Flutter/Dart (mobile, OpenStreetMap via flutter_map, FCM), ASP.NET Core Web API + SignalR
  (backend, Clean Architecture, Repository Pattern, DI, SOLID), Supabase (managed PostgreSQL) via
  Npgsql/EF Core, Python (Pandas/NumPy/Scikit-learn, Isolation Forest, XGBoost) for AI, Azure for
  backend/AI hosting — fixed by the brief, not open for re-litigation.
- **No hardware**: Software-only positioning is a core competitive differentiator.
- **Design fidelity**: The UI must faithfully recreate the existing 36-screen design system via
  Flutter widgets/`ThemeData` — colors (including SOS red, reserved exclusively for
  emergency/SOS), Manrope/JetBrains Mono type, spacing/radius/shadow/motion specs are fixed, not
  to be redesigned.
- **SOS non-negotiable**: The SOS pipeline (visible button + Silent/Duress path) must bypass all
  routine/AI processing and deliver within seconds — every phase's architecture must preserve
  this priority path.
- **Explainability**: Every AI output (anomaly, score, prediction) ships with a plain-language
  explanation via `ExplanationLogs` — never a bare number or unexplained alert.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Monorepo (mobile + backend + AI service in one repo) | Solo dev; simpler coordination across layers for one graduation project | — Pending |
| Phases sliced by architectural layer, not strict feature priority | User chose to build core and signature features in parallel where they share infrastructure, rather than a strict core→AI→signature sequence | — Pending |
| Fresh dedicated git repo at `safepathai_V2` → `github.com/2311-ops/SafepathAI.v2` | Prior repo root was accidentally the entire home directory, tracking an unrelated remote | ✓ Good |
| No infra pre-provisioned; roadmap includes Supabase/Azure/Firebase setup from scratch | Confirmed nothing exists yet | — Pending |
| Supabase owns authentication; backend owns app authorization/profile state | Comprehensive Phase 1 review found architecture drift risk around custom JWT remnants and `/me` role sourcing | Backend validates Supabase JWTs, `/me` reads app role/profile from `Users`, custom `AuthResult` removed |
| Phase 1 supports one active family per user | Mobile Phase 1 has no family switcher, so multiple active memberships created ambiguous restore/navigation behavior | Enforced in command handlers and with a filtered unique index on active `FamilyMembers.UserId` |
| Family tables are backend API owned for Phase 1 | RLS is defense in depth, but EF/backend handlers are the source of authorization for family workflows | Migration enables RLS and revokes Data API grants for family tables; backend handlers keep Guardian/member checks |
| Mid-Phase-02 migration from `google_maps_flutter` to `flutter_map`/OpenStreetMap | Project direction change (2026-07-13) away from a Google Maps SDK/billing dependency | All map surfaces (live map, route history) rebuilt on flutter_map/OSM; no `google_maps_flutter` references remain; see `02-OSM-MIGRATION-IMPACT.md` |
| Location sharing enforced by a server-side double gate: active family membership + enabled/unexpired `SharingPreference` | Client-only toggles are trivially bypassable; privacy-first positioning requires the server, not the UI, to be the enforcement boundary | Enforced in `ReportLocationCommand`, `GetLiveLocationsQuery`, and `GetLocationHistoryQuery`; verified in Phase 02 security review (74/74 threats closed) |
| Profile avatars stored via a private Supabase Storage bucket with backend-issued signed URLs only — mobile never calls `supabase_flutter` Storage directly | Keeps the backend as the sole trust boundary for upload validation (re-encode, size/dimension limits, path derived from server-side user Guid) | Implemented across Phases 02-13–02-16; verified via UAT and security threat register (no direct Storage access from client) |
| Foreground-only location tracking for Phase 02 (no background/Always permission) | Matches `geolocator`-only foreground scope decided for this milestone; background tracking deferred | Android/iOS manifests carry no background location strings; verified in UAT test 24 |
| `quick_actions` OS home-screen shortcut fires SOS immediately with no arming hold (D-27) | The user already made a deliberate two-step choice by long-pressing the app icon and selecting the action; re-requiring a 3s hold would defeat the point of a backup trigger | Shortcut reuses the identical `SosController.arm()` entry point the in-app button calls — no second arming implementation |
| SMS (Twilio) and iOS/APNs push remain unprovisioned at Phase 03 close | Zero-cost-default pattern (`LoggingSmsGateway`/graceful Firebase-init failure) keeps the rest of the phase unblocked; explicitly deferred by the user, not a code gap | SignalR + FCM (Android) delivery is live-device-verified; SMS/iOS provisioning tracked as open ops items in STATE.md, not phase defects |
| Phase 03 code review found and fixed a Critical IDOR (CR-01): `TriggerSosCommandHandler`'s idempotent-replay branch returned full session data to any authenticated user who knew a session id, skipping the `RequireMembership` check every sibling handler enforces | Discovered via the phase's standard code-review gate before phase completion, not by external report | Fixed to check `existing.FamilyId` before the early return, mirroring the sibling handlers' pattern; regression test added; see `03-REVIEW.md`/`03-REVIEW-FIX.md` |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-08 after Phase 03 (SOS fast path) completion*
