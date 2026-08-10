# Phase 4: Geofencing - Research

**Researched:** 2026-08-10
**Domain:** Native Android/iOS geofencing, reliable transition confirmation, routine notifications, and activity history
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Zone creation is map-first: the Guardian positions a movable pin and can use a **Use current location** shortcut.
- **D-02:** Radius selection combines quick presets with fine slider adjustment.
- **D-03:** Zones support both standard categories (Home, School, University, and Workplace) and custom names.
- **D-04:** Before saving, show a confirmation preview containing the zone circle, center, radius, assigned member, and notification settings.
- **D-05:** Favor reliability over immediacy near boundaries; a transition requires continuous inside/outside dwell confirmation, and crossing back resets the timer.
- **D-06:** Do not confirm a transition while the reported GPS accuracy range overlaps the zone boundary; wait for a clearly inside or outside reading.
- **D-07:** The Guardian can adjust sensitivity independently for each zone.
- **D-08:** Each zone has a configurable Guardian recipient list.
- **D-09:** The tracked member may receive their own enter/exit notification through a Guardian-controlled per-zone switch.
- **D-10:** Every confirmed transition must appear through push notification and in the in-app notification feed. The activity record remains durable even when push delivery fails.
- **D-11:** Geofence alerts are routine-priority and respect quiet hours. SOS remains high-priority, bypasses quiet hours, and is unaffected by geofence delivery behavior.
- **D-12:** Each activity entry shows the member, zone, transition type, exact timestamp, and completed visit duration.
- **D-13:** Display activity newest-first, grouped by day, and pair matching entry and exit events into one visit when possible.
- **D-14:** Guardians can filter history by family member, zone, transition type, and date range.
- **D-15:** Retain geofence activity for seven days, then delete it automatically.

### the agent's Discretion

- Exact radius preset values and slider bounds.
- Exact dwell/hysteresis thresholds and how each Guardian-facing sensitivity level maps to them, while honoring D-05 through D-07.
- Native geofencing package selection, permission flow details, and platform-specific recovery behavior, subject to current Android and iOS policy verification during research.
- Empty-state wording, visual styling, and loading/error presentation within established app patterns.

### Deferred Ideas (OUT OF SCOPE)

### Reviewed Todos (not folded)
- Existing `FamilyController` cold-start todo — reviewed during Phase 4 discussion and deliberately kept outside this phase because it does not belong to geofencing scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GEO-01 | "Guardian can create a safe zone (Home, School, University, Workplace) with a defined radius" [VERIFIED: .planning/REQUIREMENTS.md:51] | Server-owned zone CRUD, Guardian authorization, `VectorMap` circles, and the locked map-first review flow. |
| GEO-02 | "User/guardian receives enter/exit notifications for a safe zone, using native OS geofencing APIs with dwell-time/hysteresis to prevent GPS-drift false positives" [VERIFIED: .planning/REQUIREMENTS.md:52] | Native candidate triggers plus a bounded accuracy-aware confirmation state machine, idempotent persistence, and routine delivery. |
| GEO-03 | "User can view a zone activity log per geofence" [VERIFIED: .planning/REQUIREMENTS.md:53] | Paired visit projection, seven-day purge, filterable API, and the UI-spec activity route. |
| NOTIF-02 | "User receives a geofence enter/exit alert" [VERIFIED: .planning/REQUIREMENTS.md:67] | Server-persist-first routine FCM/in-app-feed fan-out and notification-tap routing. |
</phase_requirements>

## Summary

Implement SafePath geofencing as a **three-stage routine pipeline**: native OS region monitoring produces a candidate; a short, bounded location-confirmation window evaluates dwell, hysteresis, and reported accuracy; the backend atomically records the confirmed visit/activity before attempting routine delivery. This meets the reliability-first decisions without silently turning Phase 2's foreground-only live tracking into perpetual background tracking. Android explicitly supports enter, exit, and dwell transitions, but background events can be delayed; iOS can wake/relaunch for monitored-region changes but has a per-app monitoring cap. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions]

Keep geofence processing structurally separate from SOS. The existing emergency broadcaster states verbatim: `"a future inactivity or geofence alert must never be able to change or slow this code path"`. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs:8-10] Create a dedicated routine notification/feed service and normal-priority channel instead of parameterizing `SosAlertDispatcher`, `AlertHub`, or the SOS-specific mobile push service.

**Primary recommendation:** Build narrow Kotlin/Swift native adapters over the platform APIs. On Android, synchronously retain the callback in an app-private outbox, enqueue unique WorkManager work, and invoke a headless Dart entry point that restores the existing Supabase session before using the shared authenticated Dio path; normal cold relaunch drains the same outbox if headless execution cannot finish. Prove this on a real Android device before CRUD/UI/activity/push expansion. On iOS, queue the Core Location callback in app-private storage and drain after the relaunched Flutter engine restores the same session. Add no third-party Flutter geofencing wrapper or native token store. [CITED: https://docs.flutter.dev/platform-integration/platform-channels] [ASSUMED, resolved by PR-02]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Guardian zone management and review | API / Backend | Browser / Client | The server owns authorization and durable configuration; Flutter renders/edit-validates it. [ASSUMED] |
| Region registration and raw crossings | Browser / Client | OS location service | Only the tracked member's device can register its native regions and receive OS callbacks. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions] |
| Accuracy-aware dwell confirmation | Browser / Client | API / Backend | The device samples and submits candidate evidence during a bounded window; the server is authoritative for state, duplicate suppression, and final confirmation. [ASSUMED] |
| Activity history and seven-day retention | Database / Storage | API / Backend | Visits, unmatched transitions, notification rows, and purge eligibility must survive app/process/push failure. [ASSUMED] |
| Routine push and in-app feed | API / Backend | Browser / Client | Persist first, then use existing token fan-out; Flutter renders normal UI and routes a user-initiated tap. [VERIFIED: backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs:12-22] [ASSUMED] |
| SOS isolation | API / Backend | Browser / Client | SOS remains its existing dedicated route; geofence work cannot share its hub, channel, priority, or navigation behavior. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs:8-10] |

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Android `GeofencingClient` / `BroadcastReceiver` | Platform API | Native circular region registration and raw enter/exit/dwell candidates | Android documents this combination, requires fine plus background location for this use, and caps each app/device-user at 100 active geofences. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] |
| Apple Core Location region monitoring | Platform API | Native iOS circular-region monitoring and launch/recovery handling | iOS monitoring can wake/relaunch the app for transitions, but limits an app to 20 monitored conditions. [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions] |
| Flutter platform channels | Flutter SDK already used by the app | Narrow Dart-to-Kotlin/Swift zone-sync commands and native-to-Dart transition bridge | Flutter documents asynchronous host-platform messaging and supports Kotlin and Swift host implementations. [CITED: https://docs.flutter.dev/platform-integration/platform-channels] |
| Existing Firebase token/push seam | Existing integration | Routine FCM fan-out after durable persistence | `IPushSender` already reports provider acceptance and invalid tokens without claiming end-device delivery. [VERIFIED: backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs:12-22] |

### Supporting

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| Existing `VectorMap` + `MapCircle` | In-repo abstraction | Map-first editor/review/detail circle rendering | The public circle constructor exposes `id`, `center`, `radiusMeters`, and `colorHex`; use it rather than importing a map SDK in Phase 4 screens. [VERIFIED: mobile/lib/features/location/presentation/vector_map.dart:151-168] |
| Existing `geolocator` permission seam | Existing integration | Read current permission, route to app settings, and obtain bounded confirmation fixes | It currently maps both `LocationPermission.always` and `LocationPermission.whileInUse` to `LocationPermissionStatus.granted`; Phase 4 needs a separate background-geofence capability state rather than treating that result as sufficient. [VERIFIED: mobile/lib/features/location/application/permission_controller.dart:57-65] |
| Existing hosted-service pattern | Existing backend pattern | Seven-day activity-purge worker | `SharingPreferenceSweepService` supplies the scoped `BackgroundService` / `PeriodicTimer` pattern. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs:14-18] [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs:51-85] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct native adapters | A Flutter geofencing wrapper package | A wrapper reduces initial Kotlin/Swift code but adds package lifecycle/background-runtime risk and obscures platform recovery rules; no authoritative package documentation or legitimacy audit was completed, so do not add one. [ASSUMED] |
| Bounded post-candidate confirmation | Raw OS enter/exit notification | Raw crossings cannot meet D-05/D-06 because they do not establish continuous clear-side dwell with a non-overlapping accuracy envelope. [ASSUMED] |
| Routine notification service | Reusing SOS `AlertHub` / SOS channel | Existing code explicitly prohibits future geofence alerts changing or slowing that emergency path. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs:8-10] |

**Installation:** No new Flutter/Pub package is recommended. Add only the official Android location SDK dependency needed by the native adapter after checking the Android documentation's current compatible version during implementation; Core Location ships with iOS. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing]

## Architecture Patterns

### System Architecture Diagram

```text
Guardian Flutter UI
  -> authenticated zone CRUD/review API
  -> SafeZone + recipient configuration in database
  -> target-device configuration sync
  -> Kotlin GeofencingClient / Swift Core Location registration

Native OS candidate (enter / exit / dwell)
  -> native receiver/delegate + durable local outbox
  -> bounded high-accuracy confirmation samples
  -> authenticated candidate-evidence API
  -> server transition state machine
       -> unclear / crossed-back: reset candidate, no alert
       -> confirmed: transaction writes activity + notification feed row
                    -> routine FCM fan-out (quiet-hours policy)
                    -> Flutter normal-priority feed and tap route

SOS path: separate existing AlertHub + SOS channel; no edge joins from this flow
```

Android registration must use a `PendingIntent` delivered to a receiver; Android advises receivers to start longer work rather than making UI visible. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] Native events are *candidates*, not activity records. The planner must schedule an Android tracer that survives an app swipe/kill, captures a callback, and uploads one authenticated candidate before proceeding to the full UI. [ASSUMED]

### Recommended Project Structure

```text
backend/src/
├── SafePath.Domain/Entities/          # safe-zone, candidate, visit, routine-notification entities
├── SafePath.Application/Geofencing/   # commands, queries, evaluator, DTOs, authorization
├── SafePath.Infrastructure/Persistence/EntityConfigurations/
├── SafePath.Infrastructure/Geofencing/# routine dispatch + retention worker
└── SafePath.Api/Controllers/          # Guardian CRUD, activity query, candidate evidence endpoint

mobile/lib/features/geofencing/
├── data/                              # API/native-bridge contracts
├── application/                       # pure transition/permission state and Riverpod controllers
└── presentation/                      # list, edit/review, detail/activity, notification feed
mobile/android/.../                    # GeofencingClient receiver and registration adapter
mobile/ios/Runner/                     # CLLocationManager adapter and restoration bridge
```

The structure is a recommendation, not an existing file map. [ASSUMED]

### Pattern 1: Candidate → evidence → confirmed transition

**What:** Treat native `enter`, `exit`, and `dwell` callbacks as wake-up hints. Maintain one server-side candidate per active `(zone, member, intended-side)`; clear it whenever evidence returns to the prior/ambiguous side. Only the confirmed transition creates a visit/activity/notification row. [ASSUMED]

**When to use:** Every native callback, including duplicate, late, replayed, post-reboot, or out-of-order callbacks. Android explicitly warns that background geofence alerts are not instantaneous. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing]

**Accuracy rule:** For distance `d` from center, zone radius `R`, reported horizontal accuracy `a`, and per-sensitivity hysteresis margin `h`, accept inside evidence only when `d + a <= R - h`; accept outside evidence only when `d - a >= R + h`. Otherwise the uncertainty range overlaps the boundary and the candidate waits. This is the direct operationalization of D-06. [ASSUMED]

**Recommended calibration:** Reliable = 120-second dwell / 50 m margin; Balanced = 60 seconds / 30 m; Responsive = 30 seconds / 15 m. Sample on a bounded interval while the candidate is active, require all samples to be clear-side, and reset immediately on a cross-back or ambiguous sample. Use no zone radius below 100 m; Android identifies 100 m as its recommended minimum to account for typical network-location accuracy. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [ASSUMED]

```dart
// Planner skeleton — thresholds and data types are deliberately not final API values.
bool isClearSide(LocationEvidence evidence, ZoneGeometry zone, IntendedSide side) {
  final distance = distanceMeters(evidence.point, zone.center);
  final envelope = evidence.horizontalAccuracyMeters;
  final margin = zone.hysteresisMeters;
  return side.accepts(distance, envelope, zone.radiusMeters, margin);
}

TransitionDecision evaluate(Candidate candidate, LocationEvidence evidence) {
  if (!isClearSide(evidence, candidate.zone, candidate.side)) {
    return candidate.resetOrWait();
  }
  return candidate.extendDwell(evidence.observedAtUtc).confirmWhenReady();
}
```

The skeleton is intentionally illustrative and every proposed type/operation is [ASSUMED].

### Pattern 2: Transactional activity before best-effort delivery

**What:** In one database transaction, deduplicate the candidate event, write the confirmed transition/paired visit, write recipient feed rows, and enqueue a routine delivery job. Send FCM after commit; capture per-recipient failure without deleting the activity/feed data. [ASSUMED]

**When to use:** Each confirmed transition. It is necessary for D-10's durable history when push is unavailable. The existing push contract also says a successful provider return means only that FCM accepted a message, not that a device received it. [VERIFIED: backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs:12-17]

### Pattern 3: Per-target-device activation budget and acknowledgement

**What:** Restrict *active* zones assigned to a single tracked member to 20, require native registration acknowledgement from that member's device before displaying the zone as active, and retain the zone with an actionable inactive/needs-permission state if the device cannot register it. [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions] [ASSUMED]

**When to use:** Zone save, member reassignment, enable, app launch, login, boot/recovery, permission change, and native-registration failure. Android's 100-region cap is higher, so the iOS 20-region cap is the cross-platform product limit. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions]

### Anti-Patterns to Avoid

- **Raw callback equals arrival/departure:** Platform callbacks can be delayed and inaccurate; confirm clear-side dwell before activity/fan-out. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [ASSUMED]
- **Continuous background tracking:** Start a short confirmation window only after a candidate and stop it on confirm/reset/timeout; do not repurpose the SOS foreground-service path. [VERIFIED: mobile/android/app/src/main/AndroidManifest.xml:8-13] [ASSUMED]
- **Genericizing SOS:** Do not alter `safepath_sos`, its high/critical local settings, `AlertHub`, or SOS force-navigation. The existing mobile code declares `const sosAndroidChannelId = 'safepath_sos';` and creates it as `Importance.max`; iOS uses `InterruptionLevel.critical`. [VERIFIED: mobile/lib/core/push/push_service.dart:23-28] [VERIFIED: mobile/lib/core/push/push_service.dart:155-188]
- **Client-authoritative recipients or zone ownership:** Re-check family membership and Guardian role server-side. Existing authorization queries the caller's active membership row and does not trust a client role claim. [VERIFIED: backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:8-12] [VERIFIED: backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:23-47]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Background region trigger | Dart polling loop or permanent foreground service | `GeofencingClient` on Android and Core Location monitoring on iOS | The OS owns power-aware region monitoring, background wake behavior, and platform quotas. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions] |
| Map circle geometry | Screen-pixel radius approximation | Existing metre-accurate `MapCircle` | `MapCircle` exposes a `radiusMeters` field and is rendered from geographic geometry. [VERIFIED: mobile/lib/features/location/presentation/vector_map.dart:147-168] |
| Push token fan-out | A second FCM client/credential path | Existing `IPushSender` and device-token records | The app already has provider abstraction and invalid-token reporting. [VERIFIED: backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs:9-22] |
| Activity retention | UI-side hiding or ad-hoc SQL from a controller | Hosted retention worker + server query filters | Existing backend uses a scoped background service for time-based data state. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs:14-18] [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs:51-85] |
| Authorization | Client role check | `IFamilyAuthorizationService` membership/role re-check | It prevents cross-family and forged-role access. [VERIFIED: backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:8-12] |

**Key insight:** Native geofencing should save battery and wake the app at the right time; it is not a reliable business-level transition oracle. The application confirmation state machine is still required. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [ASSUMED]

## Common Pitfalls

### Pitfall 1: Promise immediate notifications

**What goes wrong:** Android background callback delivery is batched; a user sees an alert minutes after crossing and assumes the app is broken. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing]

**How to avoid:** UI/copy must describe confirmed routine alerts, not real-time boundary precision; log native event time, candidate time, confirmation time, and delivery attempt time separately. [ASSUMED]

### Pitfall 2: GPS drift creates ping-pong visits

**What goes wrong:** A device's accuracy circle spans both sides of the boundary, producing an enter/exit cycle with no real visit. [ASSUMED]

**How to avoid:** Enforce the envelope rule, hysteresis, contiguous dwell, cross-back reset, idempotency, and a 100 m minimum radius. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [ASSUMED]

### Pitfall 3: Lost registrations after recovery

**What goes wrong:** Android registration is not automatically recoverable after device boot, app/data clear, Google Play Services data clear, or `GEOFENCE_NOT_AVAILABLE`; iOS requires monitor reconstruction after relaunch. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions]

**How to avoid:** Make server configuration canonical, sync/ack active registrations, re-register on the documented recovery points, and expose a needs-permission/needs-sync state instead of a false active state. [ASSUMED]

### Pitfall 4: Incorrect permission model

**What goes wrong:** Treating foreground permission as adequate either prevents background callbacks or causes surprise OS prompts. Android requires background location for Android 10+ geofencing; iOS background/terminated region handling requires an explicit, value-first authorization flow and correct usage-description keys. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [CITED: https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services]

**How to avoid:** Ask only after Save safe zone, as locked by UI spec; model foreground, background-geofence-capable, denied, restricted, and unavailable separately. On Android 11+, background access leads the user to Settings rather than offering "Allow all the time" in the dialog. [CITED: https://developer.android.com/develop/sensors-and-location/location/permissions/background] [ASSUMED]

### Pitfall 5: Routine delivery accidentally inherits SOS behavior

**What goes wrong:** A geofence notification gets high/critical priority, bypasses quiet hours, or force-navigates the recipient. [ASSUMED]

**How to avoid:** Add a distinct normal Android channel/local presenter and a generic route payload; preserve the existing SOS-only constants/handlers unchanged. [VERIFIED: mobile/lib/core/push/push_service.dart:20-28] [VERIFIED: mobile/lib/core/push/push_service.dart:195-251] [ASSUMED]

## Code Examples

Verified architecture patterns from official sources:

### Native adapter boundary

```dart
// Source: https://docs.flutter.dev/platform-integration/platform-channels
abstract interface class NativeGeofenceGateway {
  Future<void> replaceMonitoredZones(List<ZoneRegistration> registrations);
  Future<NativeCapability> getCapability();
  Stream<NativeGeofenceCandidate> get candidates;
}
```

Flutter documents asynchronous named platform channels for host-platform communication. The interface and all symbols above are [ASSUMED] planner scaffolding; the app should bind it to one Kotlin and one Swift implementation, not expose platform SDK types to widgets. [CITED: https://docs.flutter.dev/platform-integration/platform-channels]

### Routine notification tap routing

```dart
void onRoutineNotificationTap(RoutineNotificationRoute route) {
  router.go(route.activityPath);
}
```

Firebase documents handling both cold-start and background notification interaction paths with `getInitialMessage()` and `onMessageOpenedApp`; route only after a user tap and never force-navigate for a routine event. [CITED: https://firebase.google.com/docs/cloud-messaging/flutter/get-started] The code symbols are [ASSUMED] planner scaffolding.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flutter-only foreground polling | Native OS region monitoring plus bounded application confirmation | Phase 4 recommendation | Preserves battery behavior and can receive background region candidates, while retaining SafePath's drift protections. [CITED: https://developer.android.com/develop/sensors-and-location/location/geofencing] [ASSUMED] |
| Single platform cap assumption | Cross-platform active-zone budget of 20 per tracked member | Current Apple platform constraint | Avoids an Android-only configuration that silently fails registration on iOS. [CITED: https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions] [ASSUMED] |
| SOS-only notification handling | Separate routine feed and normal-priority notification path | Phase 4 recommendation | Keeps the emergency core value structurally isolated. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs:8-10] [ASSUMED] |

**Deprecated/outdated:** Do not follow earlier Phase 2 assumptions that all location functionality is foreground-only: the Phase 4 requirement explicitly needs native background region monitoring, but the expansion must remain event-triggered and bounded rather than a general tracking service. [VERIFIED: .planning/phases/02-real-time-location-history-privacy/02-CONTEXT.md:13-14] [ASSUMED]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The PR-02 native-outbox/headless-Dart bridge can restore the existing Supabase session after Android process death; cold relaunch is the durable fallback. iOS uses relaunch of the main Flutter engine rather than an Android-style worker. | Summary / Architecture | Runtime behavior is gated by the early Android checkpoint and final physical-iPhone checkpoint. |
| A2 | The bounded confirmation calibration is 120/60/30 seconds with 50/30/15 m margins. | Pattern 1 | May be too noisy or too slow on real devices/places. |
| A3 | Twenty active zones per tracked member is the appropriate product-level cross-platform limit. | Pattern 3 | Product capacity may need a tighter business limit or different assignment rules. |
| A4 | Zone activity/feed rows and dispatch jobs can be made atomic in the existing EF Core persistence architecture. | Pattern 2 | Delivery/retry design may need an outbox worker/migration refinement. |
| A5 | Routine payload carries only type/activity/zone identifiers plus display copy; PR-03 stores recipient-owned local start/end and IANA time zone and defers only routine push. | Pitfall 5 | Covered by dispatcher, payload, and SOS-isolation tests. |

## Resolved Questions

1. **Authenticated process-death/relaunch upload — RESOLVED (PR-02).** Android uses `BroadcastReceiver -> app-private native outbox -> unique WorkManager -> headless Dart entry point -> Supabase.initialize/session restore-or-refresh -> existing AuthInterceptor/Dio -> POST /geofences/candidates -> acknowledge on accepted/duplicate`. No token is stored by Kotlin. A failed headless attempt remains queued and the normal authenticated cold-start bootstrap drains it. iOS persists the Core Location event and uses the relaunched main Flutter engine to perform the same authenticated drain. The early Android device gate must pass before later expansion; iOS runtime proof is final acceptance.

2. **Quiet-hours ownership — RESOLVED (PR-03).** Each recipient owns one disabled-by-default setting and may edit only their own local start/end plus IANA time zone. The server evaluates the current row at each job attempt, preserves activity/feed immediately, and defers only normal-priority push. SOS has no dependency on the policy.

3. **iOS environment and acceptance — RESOLVED (PR-04).** Runtime acceptance requires a supported macOS/Xcode toolchain, signed physical iPhone, Always-location authorization, and provisioned APNs. Windows source analysis and simulator tests are useful prechecks but do not close iOS GEO-02/NOTIF-02; absence of the environment leaves the phase open with explicit evidence recorded.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | Mobile implementation/tests | ✓ (`C:\\Flutter\\flutter\\bin\\flutter.bat`) | Not probed; CLI version request did not complete within the research timeout | — |
| Dart SDK | Flutter analysis/tests | ✓ (`C:\\Flutter\\flutter\\bin\\dart.bat`) | Not probed | — |
| .NET SDK | Backend/migration/tests | ✓ (`C:\\Program Files\\dotnet\\dotnet.exe`) | Not probed | — |
| Android device with Google Play services | Android native geofence tracer | Not confirmed | — | Android emulator/physical device, but physical-device validation remains required. [CITED: https://firebase.google.com/docs/cloud-messaging/flutter/get-started] |
| macOS/Xcode + physical iPhone | iOS Core Location/APNs validation | ✗ on this Windows workspace | — | No local fallback; use a macOS CI/maintainer device. [ASSUMED] |
| Firebase/APNs credentials and signing capability | Real routine push | Not confirmed | — | Logging/no-push build is possible, but cannot validate NOTIF-02 end-to-end. Existing build explicitly permits Firebase-disabled builds. [VERIFIED: mobile/android/app/build.gradle.kts:7-16] |

**Missing dependencies with no fallback:** macOS/Xcode/iPhone for iOS behavior; provisioned FCM/APNs credentials for end-to-end push.

**Missing dependencies with fallback:** Android hardware can be supplemented by an emulator for initial registration tests, but not for final movement/accuracy confidence. [ASSUMED]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter `flutter_test`; .NET xUnit projects. [VERIFIED: mobile/test/features/sos/push_service_test.dart:1-8] [VERIFIED: backend/SafePath.sln:1-22] |
| Config file | `mobile/analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. [VERIFIED: mobile/analysis_options.yaml:8-10] |
| Quick run command | `cd mobile; flutter test test/features/geofencing` / `dotnet test backend/tests/SafePath.Application.Tests` |
| Full suite command | `cd mobile; flutter analyze; flutter test` and `dotnet test backend/SafePath.sln` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GEO-01 | Guardian-only create/edit/delete and native-registration request payload | backend unit + Flutter widget | `dotnet test backend/tests/SafePath.Application.Tests --filter Geofencing` | ❌ Wave 0 |
| GEO-02 | Clear-side envelope, dwell, cross-back reset, dedupe, routine delivery isolation | backend unit + mobile unit | `flutter test test/features/geofencing/geofence_transition_evaluator_test.dart` | ❌ Wave 0 |
| GEO-03 | Visit pairing, newest-first filter, seven-day deletion | backend unit + API integration | `dotnet test backend/tests/SafePath.Application.Tests --filter GeofenceActivity` | ❌ Wave 0 |
| NOTIF-02 | Persist before send, quiet-hours deferral, normal tap to activity | backend unit + Flutter push service tests | `flutter test test/features/geofencing/routine_notification_route_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** affected Flutter or .NET geofencing tests plus `flutter analyze` for Dart changes. [ASSUMED]
- **Per wave merge:** full mobile and backend suites. [ASSUMED]
- **Phase gate:** the early real-Android process-death authenticated-upload tracer must pass before CRUD/UI/activity/push expansion. Final acceptance requires real Android boot recovery plus a signed physical-iPhone 20-region/permission/relaunch/APNs test and SOS regression. Missing iOS infrastructure leaves the phase open per PR-04. [ASSUMED]

### Wave 0 Gaps

- [ ] `mobile/test/features/geofencing/geofence_transition_evaluator_test.dart` — drift/dwell state machine.
- [ ] `mobile/test/features/geofencing/native_geofence_gateway_test.dart` — adapter contract fakes and permission states.
- [ ] `mobile/test/features/geofencing/routine_notification_route_test.dart` — feed/tap routing without SOS navigation.
- [ ] `backend/tests/SafePath.Application.Tests/Geofencing/` — commands, authorization, persistence, pairing, retention, and dispatch failure.
- [ ] `backend/tests/SafePath.Api.IntegrationTests/GeofencesControllerTests.cs` — authenticated cross-family/role gates.
- [ ] Native device test checklist — Android API 29+, Android boot recovery, iOS Always/When-in-Use denial, iOS restart, poor-accuracy boundary behavior.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Require authenticated API access; reject unauthenticated candidate evidence. Existing location controller uses `[Authorize]`. [VERIFIED: backend/src/SafePath.Api/Controllers/LocationController.cs:8-10] |
| V3 Session Management | yes | PR-02 restores the existing Supabase session inside Dart and never copies access/refresh tokens into native storage; prove headless restore plus cold-relaunch fallback in the device tracer. [ASSUMED] |
| V4 Access Control | yes | Re-check active family membership and Guardian role in every zone-management/query command; candidate submitter must equal the assigned member/device. [VERIFIED: backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:23-47] [ASSUMED] |
| V5 Input Validation | yes | Server-validate coordinates, radius, category/name, target membership, recipient membership, sensitivity, event timestamp/accuracy, filters, and idempotency key. [ASSUMED] |
| V6 Cryptography | yes | Use existing HTTPS/auth transport and platform secure storage; do not create custom crypto or serialize an access token into a notification payload. [ASSUMED] |

### Known Threat Patterns for geofencing

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Forged/replayed candidate event | Spoofing / Repudiation | Authenticate device user, bind member/zone/family server-side, validate timestamp, and enforce immutable idempotency keys. [ASSUMED] |
| Guardian edits another family’s zone | Elevation of privilege | Use current-user membership and role re-check; never trust body family/role fields. [VERIFIED: backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:8-12] |
| Location accuracy manipulated or stale | Tampering | Treat raw callback as a candidate; require fresh bounded evidence and clear-side envelope before confirm. [ASSUMED] |
| Push data leaks location or forces navigation | Information disclosure / Denial of service | Keep payload to zone/transition/activity route identifier, send no coordinates, and route only on explicit user tap. [ASSUMED] |
| Routine work degrades SOS | Denial of service | Dedicated routine services/channels and regression tests; leave emergency interfaces unchanged. [VERIFIED: backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs:8-10] |

## Sources

### Primary (HIGH confidence)

- [SafePath `AlertBroadcastService`](backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs) — existing SOS isolation.
- [SafePath `VectorMap`](mobile/lib/features/location/presentation/vector_map.dart) — map-circle abstraction.
- [SafePath family authorization](backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs) — active membership/role re-check.

### Secondary (MEDIUM confidence)

- [Android: Create and monitor geofences](https://developer.android.com/develop/sensors-and-location/location/geofencing) — registration, permissions, dwell, limits, latency, recovery.
- [Apple: Monitoring proximity to geographic regions](https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions) — region monitoring, wake/relaunch, 20-condition cap.
- [Apple: Requesting location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services) — When In Use / Always behaviors.
- [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels) — Kotlin/Swift bridge pattern.
- [Firebase Cloud Messaging for Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) — background handler limitations and interaction paths.

### Tertiary (LOW confidence)

- None; recommendations requiring device behavior are explicitly listed in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — platform/Flutter/FCM choices are supported by official docs; current build integration needs a device tracer.
- Architecture: MEDIUM — PR-02/PR-03 define concrete contracts and the existing SOS/push/authorization seams are verified; Android and iOS runtime behavior remains explicitly device-gated.
- Pitfalls: MEDIUM — Android/iOS constraints are official; calibration values need field testing.

**Research date:** 2026-08-10
**Valid until:** 2026-08-17
