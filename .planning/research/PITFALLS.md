# Pitfalls Research

**Domain:** Family-safety / real-time location-intelligence platform (Flutter + ASP.NET Core/SignalR + Supabase + Python AI, background location, SOS/duress, geofencing, health data)
**Researched:** 2026-07-06
**Confidence:** MEDIUM (broad web/community + official-docs corroboration across multiple independent sources per topic; no single-vendor primary-source deep dive was fetched, so treat exact numbers — e.g. "180s", "100-150m" — as directional, not contractual)

## Critical Pitfalls

### Pitfall 1: Background location silently stops working on real devices (OS/OEM kills, not your code)

**What goes wrong:**
The app works perfectly in development (USB-connected, screen on, emulator) but in the field, location updates stop arriving after the phone is locked for a while, especially on Xiaomi/Huawei/Oppo/Samsung devices, or after a few hours on iOS. Guardians see a family member's dot "frozen" at their last position with no indication anything failed.

**Why it happens:**
Android 8+ aggressively manages background execution to save battery, and Chinese-OEM battery managers (covering 70%+ of the global Android install base) kill background processes/services outright regardless of what the OS API contract says. On iOS, plain background execution grace periods are short (tens of seconds to ~180s); only the Significant-Location-Change (SLC) service or region monitoring can relaunch a terminated app, and even that fails silently if the user has Background App Refresh disabled. Solo developers typically only test on their own device/emulator, which never reproduces OEM kill behavior.

**How to avoid:**
- Android: use a **foreground service with a persistent, transparent notification** (not just `flutter_background_service` in isolate mode) + `WorkManager`/periodic re-arm to recover from kills; explicitly prompt the user to whitelist the app from battery optimization during onboarding (with a one-time explainer screen, since this is intrusive).
- iOS: enable `UIBackgroundModes: location`, set `allowsBackgroundLocationUpdates=true`, `pausesLocationUpdatesAutomatically=false` for active tracking sessions (e.g., Walk-Me-Home), but fall back to **Significant-Location-Change** for steady-state "last seen" tracking to avoid iOS killing the app for excessive battery use.
- Build a **heartbeat/staleness indicator** in the UI: if no location update has arrived in N minutes, show "last seen X ago, may be offline" instead of silently showing a stale dot as if it were live. This turns a silent failure into a visible, honest one.
- Test on at least one real budget Android OEM device (Xiaomi/Oppo/Samsung), not only an emulator or flagship, before any milestone demo.

**Warning signs:**
- Location dot stops updating after screen-off but app still shows "online."
- Works fine when phone plugged into USB/dev machine, fails after real unplugged use for hours.
- No staleness/last-updated timestamp visible anywhere in the tracking UI.

**Phase to address:** Location-tracking core phase (foreground service + SLC fallback architecture) — must be designed in from the start, not bolted on later, since it changes the tracking architecture (polling model, permission flow, battery-exemption onboarding).

---

### Pitfall 2: SOS/Silent-Duress alert has a hidden single point of failure in the delivery path

**What goes wrong:**
The SOS button fires, the app shows "Alert sent," but the guardian's phone never rings/buzzes — because the push notification was silently dropped, or the SignalR socket had already disconnected and the client didn't know it, or the app was force-quit and its background reconnection never happened. This is the worst possible failure mode for this domain: the user believes help is coming and it isn't.

**Why it happens:**
FCM/APNs "delivery" only means the OS push gateway *accepted* the message — not that the recipient device received or displayed it. iOS explicitly does not guarantee delivery of silent/background pushes, and can drop them based on battery state or connectivity. Real-world delivery rates without careful tuning of priority/TTL/payload format can fall well below 90% and even below 40% in poorly configured implementations. Separately, SignalR's "connected" state on a mobile client is misleading: a backgrounded or force-quit app appears connected until the next network hiccup reveals it's dead, and reconnection after a full app restart gets a brand-new connection ID with no memory of prior state — so any guardian-side subscription tied to the old connection silently stops receiving events unless explicitly re-subscribed.

**How to avoid:**
- Treat the SOS path as **multi-channel, not single-channel**: SignalR push for guardians who are actively in-app (lowest latency) + a guaranteed **push notification with high-priority/immediate delivery flags** (APNs `apns-priority: 10`, FCM `high` priority + short TTL) as the durable fallback + an **SMS fallback via Twilio or similar** for the actual emergency contact (not just in-app guardians) since SMS bypasses app-state and OS push-throttling entirely.
- On SOS trigger, the client must **confirm server receipt with an ack**, not just "we called the API." If no ack within N seconds, retry over a different channel (e.g., raw HTTP if SignalR failed) and surface a "still trying to send..." state to the user rather than a false "Sent" checkmark.
- Server-side: log every SOS event through actual delivery confirmation (push receipt, SMS delivery webhook) — not just "message queued" — so you can detect and alert on a systemic delivery failure before a real incident exposes it.
- On reconnect (including post-force-quit), always **re-subscribe + pull any missed events via an HTTP gap-fill query** rather than assuming the socket state carried over.
- Consider the brief's OS-level backup shortcut (e.g., wiring into native SOS mechanisms like Android's Emergency SOS gesture or a widget/shortcut that fires even if the Flutter app process is dead) as a true last-resort path independent of your own server entirely.

**Warning signs:**
- SOS "success" UI state is set as soon as the local API call returns 200, before any delivery confirmation.
- No test coverage for "guardian's app was force-quit 10 minutes ago" scenario.
- No SMS/alternate channel — SOS depends entirely on push + SignalR, both of which are best-effort.

**Phase to address:** SOS/alerting core phase — this is the Core Value of the whole project per PROJECT.md, so its delivery-confirmation and multi-channel fallback design must be a first-class phase deliverable, verified with actual force-quit/airplane-mode/background test scenarios before it's considered "done."

---

### Pitfall 3: Geofencing "flapping" and false alerts erode trust before the AI layer even gets a chance

**What goes wrong:**
A user standing still near a zone boundary (a parking garage, dense urban block, or building with poor GPS reception) triggers repeated enter/exit notifications ("Emma left School... Emma entered School... Emma left School...") within minutes, even though they never moved. Guardians quickly learn to ignore geofence alerts, undermining the entire safety-notification premise.

**Why it happens:**
Consumer GPS drifts 20-50m even with good signal, and drifts far more (hundreds of meters) in urban canyons, garages, or under heavy tree cover. A geofence radius that's too tight relative to that drift will register spurious boundary crossings ("flapping") purely from noise, not movement.

**How to avoid:**
- Enforce a **minimum geofence radius** (roughly 100-150m for outdoor GPS/Wi-Fi zones) rather than letting users draw arbitrarily tight circles around a school gate.
- Add a **dwell-time/confirmation window** (~60-120s) before firing an enter/exit event — only fire if the state persists past the window, filtering out drive-bys and GPS noise spikes.
- Use **hysteresis**: separate inner and outer buffer radii for entry vs. exit detection so the boundary isn't a single line that noise can cross repeatedly.
- Where possible, fuse Wi-Fi/BLE signals for known high-value zones (home) to sharpen indoor/near-boundary accuracy beyond raw GPS.
- Rate-limit/deduplicate notifications: never send a second "left X" notification within N minutes of a "entered X" for the same zone-user pair without an intervening stable period outside.

**Warning signs:**
- Multiple enter/exit events for the same zone within a short window in test logs.
- User reports of "phantom" notifications while stationary indoors.
- Notification volume climbing without a corresponding increase in real movement.

**Phase to address:** Geofencing core phase — dwell-time and hysteresis logic must be in the initial geofence-evaluation design (server or on-device), since retrofitting state-machine logic onto a naive point-in-polygon check is a rewrite, not a patch.

---

### Pitfall 4: Isolation Forest anomaly detection creates alert fatigue on legitimately-varied family routines

**What goes wrong:**
Real families don't have a single fixed routine — kids have irregular after-school activities, parents have variable commute times, weekends look nothing like weekdays. An Isolation Forest tuned naively flags a large fraction of normal-but-varied behavior as "anomalous," and guardians start ignoring AI alerts entirely — at which point the AI layer has actively made the product *less* trustworthy than having no AI at all, which directly undermines the brief's "explainable AI, builds trust" positioning.

**Why it happens:**
Isolation Forest's `contamination` parameter directly sets the false-positive rate — set it too high (or leave scikit-learn defaults sized for a different distribution) and normal variation gets treated as anomalous. The algorithm also struggles when true anomalies sit inside a "ring" of otherwise-varied normal behavior — it can't isolate them cleanly, producing both false positives on normal variation *and* false negatives on real anomalies simultaneously. Cold-start compounds this: a new family with only days of history has no reliable "normal" baseline at all, so anything looks anomalous in the first weeks.

**How to avoid:**
- **Per-user/per-family baselines**, not a single global model — a teenager's "normal" and a toddler's "normal" are entirely different distributions; train (or at minimum threshold) per person or per role.
- **Layer rule-based filters on top of the ML output** (e.g., suppress anomaly alerts inside any known-safe geofence, suppress on days matching a recognized recurring pattern like "every other Tuesday soccer practice") rather than trusting the raw model score.
- **Cold-start policy**: explicitly suppress or heavily downweight anomaly alerts for the first ~2-3 weeks of a new user's data collection, during which the UI should say "still learning your routine" rather than staying silent or (worse) alerting on everything. This must be paired with the Explainability Layer requirement in PROJECT.md — every alert needs a plain-language "why," which also serves as a natural throttle: if you can't produce a clear explanation, don't fire the alert.
- **Human-tunable sensitivity**: let guardians adjust an alert threshold (low/medium/high sensitivity) per family member rather than a single global contamination value baked into the model — this converts "the AI is wrong" complaints into "the AI is too sensitive, let me turn it down," which preserves trust.
- Track and periodically review real-world false-positive rate per family; if a family consistently dismisses/ignores a given alert type, treat that as an implicit negative-feedback signal to retrain/adjust thresholds.

**Warning signs:**
- Anomaly alert volume per user climbing over time without corresponding real incidents.
- No cold-start/"learning your routine" state distinguishing week-1 users from established users.
- No per-family or per-role sensitivity control — one-size-fits-all contamination parameter.
- Explanations that are just a raw anomaly score, not a human-readable reason (violates the brief's explainability requirement and hides tuning problems).

**Phase to address:** AI/analytics phase (anomaly detection) — the per-user baselining, cold-start suppression, and rule-based filter layer must be designed alongside the model, not added after users complain; the Explainability Layer requirement should be treated as the mechanism that forces this discipline.

---

### Pitfall 5: Predictive/soft geofencing and ETA prediction are unusable (or actively wrong) during cold-start

**What goes wrong:**
ETA prediction (XGBoost) and Predictive/Soft Geofencing (baseline-deviation alerts) both require a meaningful history of a person's actual travel patterns to be accurate. For any new user — which is *every* user at launch, and every new family member added later — there is no history, so early predictions are either wildly wrong (eroding trust immediately) or the feature has to stay silent (making the "signature feature" invisible during any demo or early adoption window).

**Why it happens:**
This is the classic ML cold-start problem: a personalized model needs the very data it doesn't yet have. Solo developers commonly underestimate this and demo the AI features against a fully warmed-up synthetic dataset, discover in later testing that real fresh accounts show empty/garbage predictions, and have to retrofit a fallback path under time pressure.

**How to avoid:**
- Design a **two-tier prediction system from the start**: a population/context-level fallback (generic road-network ETA from a maps API distance/duration estimate, or a simple average-based baseline) for cold-start users, seamlessly handed off to the personalized model once sufficient history (e.g., N trips or M days) accumulates.
- Make the **transition visible and honest** in the UI/explanation ("estimate based on typical travel time — will get more personal as we learn your routine") rather than presenting a low-confidence personalized number as if it were as reliable as a warmed-up one.
- For demo purposes, plan to **seed synthetic/historical data** (the brief already allows seeded/synthetic health data for Cross-Modal detection — do the same for location history) so the graduation demo shows warmed-up behavior, but keep the cold-start fallback path as the actual default for real fresh accounts.

**Warning signs:**
- ETA/soft-geofence features only ever tested against pre-seeded data, never a truly fresh account.
- No fallback path when the personalized model has insufficient training rows — code either crashes, returns garbage, or silently doesn't fire.

**Phase to address:** AI/analytics phase (ETA prediction, predictive geofencing) — cold-start fallback logic is core scope for these features, not a "nice to have," since without it the feature is unusable for the first weeks of every real user's life.

---

### Pitfall 6: Duress/Silent-SOS secret storage betrays the user exactly when it matters most

**What goes wrong:**
A Silent/Duress PIN or gesture is implemented as "just another PIN field" stored the same way as the regular login PIN, or the app behaves detectably differently when the duress path is triggered (a visible delay, a crash, a suspicious "wiping" animation, or forensic artifacts that reveal two distinct app states exist). If an attacker forcing the victim to unlock the phone can detect that a duress mode exists at all, the entire safety mechanism is worse than useless — it can escalate real-world danger.

**Why it happens:**
Developers treat the duress trigger as a UI/logic feature ("if PIN == duress_pin, show decoy screen") without thinking about it as a security-under-coercion problem: what state changes are observable, how is the secret stored, and what happens to fired-off background requests during the "normal-looking" decoy flow.

**How to avoid:**
- Store the duress trigger secret the same way as any other secret credential — via platform secure storage (Android Keystore/iOS Keychain through `flutter_secure_storage`), never in shared preferences or plain SQLite, and never logged.
- The decoy state must be a **genuinely functional, normal-looking UI state** with no visible timing difference, no crash, no "wipe" animation — the SOS network call must happen silently in the background with zero UI indication (no spinner, no toast, nothing that a person watching over the victim's shoulder would notice).
- Do **not** implement any destructive/wipe behavior on duress trigger — per security research, an unusually wiped/reset device is itself suspicious evidence to an attacker who knows duress features exist. The correct pattern for a *personal safety* app (not a data-vault app) is: fire the real alert silently, show an innocuous decoy, and never destroy or visibly alter data.
- Test the duress flow against "does this look different from the honest flow to an external observer" as an explicit QA criterion, not just "does it technically send the alert."
- Rate-limit/avoid any server-side response or push notification that could bounce back to the victim's device and reveal the alert fired (e.g., don't send the victim's own device a "guardians notified" push during a duress session).

**Warning signs:**
- Duress PIN comparison logic sitting next to/reusing normal-PIN comparison code with no separate secure-storage path.
- Any visible UI difference (delay, animation, toast) between normal unlock and duress unlock.
- Confirmation feedback sent back to the triggering device itself.

**Phase to address:** Silent/Duress SOS phase — must be designed as a security-under-coercion feature from day one (threat-modeled explicitly: "what can an attacker holding the phone observe"), not layered onto the existing SOS UI late in the project.

---

### Pitfall 7: JWT/refresh-token handling mistakes common to Flutter apps handling sensitive location+health data

**What goes wrong:**
Tokens are stored in `shared_preferences` (Android) or plist-backed storage without encryption, are long-lived (hours/days) without rotation, aren't cleared on logout/device-change, or leak into logs — any of which lets a stolen/rooted device (or a coerced unlock, tying back to Pitfall 6) expose a family's entire live location and health history via a single extracted token.

**Why it happens:**
`shared_preferences` is the path-of-least-resistance API in Flutter tutorials and looks identical to secure storage in casual testing, so it's an easy default that's never revisited once "it works."

**How to avoid:**
- Use `flutter_secure_storage` (Android Keystore-backed / iOS Keychain-backed) for both access and refresh tokens, never `shared_preferences`.
- Short-lived access tokens (well under 30 minutes) with silent refresh; refresh tokens rotated on use (refresh-token-rotation, not a static long-lived refresh token) and revoked server-side on logout or password change.
- Never log tokens, even at debug level (a common accidental leak via `print`/`debugPrint` during development that ships to production builds).
- Given the data sensitivity (live location + health), pair token security with local biometric/PIN re-auth for high-risk actions (viewing another family member's live location or health data), not just for app-open.

**Warning signs:**
- Any `SharedPreferences.setString('token', ...)` in the codebase.
- No token-refresh-rotation on the backend (a single refresh token valid indefinitely).
- Tokens visible in `flutter logs`/`adb logcat` output during dev testing.

**Phase to address:** Auth/backend core phase — this is foundational plumbing that every other feature depends on, so get it right in the initial auth phase rather than retrofitting secure storage after data has already been at risk.

---

### Pitfall 8: HealthKit/Health Connect integration mistakes trigger app-store rejection or violate user trust

**What goes wrong:**
The app requests broad health-data access up front during onboarding "just in case," later ships an ad/analytics SDK that inadvertently receives health data via a shared data layer, or the privacy policy doesn't explicitly disclose HealthKit usage — any of which risks App Store/Play rejection or, worse, a genuine privacy breach for a family-safety app whose entire value proposition is trust.

**Why it happens:**
Health data permission APIs are broad by default (it's easy to request "all types") and it's tempting to ask for everything during account setup rather than contextually when the Health & Wellness module is actually opened, especially under solo-dev time pressure.

**How to avoid:**
- Request **only the specific data types actually used** (steps, heart rate, sleep — each separately) and only at the moment the Health & Wellness module is first opened, not during initial onboarding.
- Explicit privacy policy language disclosing exactly what health data is read and that it is never used for advertising, never sold, and never shared with third-party analytics — consistent with the brief's "no-data-resale" positioning, which should be made contractually explicit in-app, not just marketing copy.
- Keep health data access architecturally isolated from any analytics/crash-reporting SDK integration so there's no accidental data leak path (e.g., don't pass raw health values into a generic logging/analytics call used elsewhere in the app).
- Since the brief allows optional/seeded health data (wearables are optional), ensure the app degrades gracefully and legibly when health permissions are denied, rather than breaking the Cross-Modal Anomaly Detection feature silently.

**Warning signs:**
- A single broad HealthKit/Health Connect permission request fired at signup before the user has even seen the Health module.
- Privacy policy that doesn't mention HealthKit/Health Connect by name.
- Health values passed through the same logging/analytics pipeline as other app telemetry.

**Phase to address:** Health & Wellness module phase — permission-scoping and privacy-policy language should ship together with the first HealthKit/Health Connect integration, not be retrofitted right before a store submission.

---

### Pitfall 9: Solo-developer scope collapse — the brief is a multi-team product, not a semester project

**What goes wrong:**
The single most common failure mode for a project this size (mobile + backend + AI service + 5 "signature" features + a full health module + a 36-screen design system) built by one person is **partial completion across everything and a fully-working nothing** — auth half-done, tracking flaky, AI features stubbed, SOS untested end-to-end — because ambitious scope plus solo perfectionism plus no external pressure to cut scope leads to spreading effort evenly across too many surfaces instead of finishing a vertical slice.

**Why it happens:**
Without a hard deadline (explicitly true here per PROJECT.md) there's no external forcing function to cut scope, and the natural tendency is to build breadth-first (a little bit of every feature) rather than depth-first (one complete, demo-able, trustworthy path). This is compounded by the project's own "Core Value" statement — SOS must always work — being just one line item among ~15 Active requirements with no explicit sequencing signal.

**How to avoid:**
- Treat **PROJECT.md's Core Value line ("SOS system must always work... bypassing every routine and AI pipeline") as the literal MVP**, not aspirational framing: Phase 1 target is auth + family groups + live tracking + visible SOS button with confirmed multi-channel delivery — nothing else — fully working and demoable end-to-end before any AI or signature feature work starts.
- Sequence the five "signature" features (Walk-Me-Home, Silent/Duress, Mutual Visibility Ledger, Predictive Geofencing, Cross-Modal Detection) and the Health module explicitly *after* the core loop is solid, each as its own phase with its own demoable output, rather than building slices of all of them in parallel (which the current Key Decisions table in PROJECT.md notes was the initial inclination — "core and signature features in parallel where they share infrastructure" — worth revisiting given solo-dev bandwidth).
- At each phase boundary, force a **working, demoable artifact** (not "70% done on 5 things") as the exit criterion — this is the single best predictor of finishing vs. stalling for solo/capstone projects.
- Explicitly defer the hardest, least load-bearing pieces (Cross-Modal fused detection, which depends on the optional Health module and the AI anomaly layer both being done) to the last phase, since it's the most likely single item to consume unbounded time for the least demo impact if attempted early.

**Warning signs:**
- Multiple features simultaneously "in progress" with none reaching a demoable, end-to-end state.
- SOS pipeline still untested against real force-quit/airplane-mode/background scenarios while AI features are already being built.
- Growing backlog of "TODO: come back to this" comments in auth/tracking/SOS code while newer, flashier AI code is being written.

**Phase to address:** Roadmap/phase-sequencing itself — this is a planning-level pitfall, not a single phase's problem; the roadmap should explicitly order phases core-first (auth → tracking → SOS → geofencing) before AI/signature features, with each phase gated on a working demo, not a percentage-complete estimate.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|--------------------|-----------------|------------------|
| Storing tokens in `shared_preferences` instead of secure storage | Faster to wire up auth | Full account/location/health takeover if device compromised | Never — even for the earliest prototype, use `flutter_secure_storage` from day one; the swap cost later is nontrivial once many call sites assume plaintext access |
| Single global Isolation Forest model (no per-user baseline) | Simpler to ship first AI pass | Alert fatigue, users disable/ignore AI notifications entirely | Acceptable only for an internal/demo build with synthetic data; must be per-user before any real family uses it |
| Naive point-in-polygon geofence check (no dwell-time/hysteresis) | Simple to implement, fast demo | Flapping notifications erode trust in the whole notification system, not just geofencing | Acceptable for a throwaway prototype/spike only; never for anything shown to a real test family |
| Single-channel SOS delivery (SignalR or push only, no SMS/HTTP fallback) | Faster to build initial SOS flow | Silent total failure exactly when it matters most | Acceptable temporarily in the very first internal build, but must be flagged as an explicit gap and closed before any real-person testing, let alone the final submission demo |
| Requesting all HealthKit data types up front | Simpler permission flow to code | App Store rejection risk, privacy-trust erosion | Never in a shipped/demo build; acceptable only in a local dev branch never submitted for review |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|------------------|-------------------|
| FCM/APNs (push) | Treating "message accepted by FCM/APNs" as "delivered to guardian" | Require a device-side delivery/read acknowledgment for SOS-class messages; fall back to SMS if no ack within seconds |
| SignalR (Azure/self-hosted) | Assuming reconnect resumes prior subscription/session state automatically | Always re-subscribe + gap-fill via HTTP query on every reconnect, especially after a full app-restart (new connection ID) |
| Google/Apple background location APIs | Using one mechanism (e.g., only continuous standard location updates) for all tracking needs | Combine continuous updates (active sessions like Walk-Me-Home) with Significant-Location-Change (steady-state background) depending on context, to balance accuracy vs. battery vs. app-relaunch guarantees |
| HealthKit / Health Connect | Requesting broad data access at onboarding before the Health module is even opened | Request narrowly-scoped, per-data-type permission at first actual use of the Health & Wellness module |
| Supabase/Postgres (new provisioning) | Assuming default connection pooling/row-level-security settings are safe for multi-tenant family data without configuring RLS policies per family/role | Explicitly design and test Postgres RLS policies for Guardian/Member/Caregiver/org-role visibility before storing any real family data |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Constant high-accuracy GPS polling regardless of movement/context | Battery drops to ~20% by midday on test devices (documented real-world complaint pattern for this exact class of app) | Adaptive-frequency tracking: high accuracy only during active sessions (Walk-Me-Home) or near geofence boundaries; low-power/SLC mode otherwise | Becomes a visible user complaint (uninstall risk) even at single-digit user counts — this is a UX/trust issue from day one, not a scale issue |
| Running full AI inference (anomaly detection, ETA) synchronously in the SOS/alert request path | SOS latency creeps up as AI models grow, violating the "bypass every routine and AI pipeline" core value | Architect the SOS pipeline as fully independent of the AI/analytics pipeline at the code level (separate service call, not a shared request handler with a feature flag) | Immediately, even in early testing — this is a correctness/architecture issue, not something that "breaks at scale" |
| Storing raw high-frequency location pings indefinitely without aggregation | Location-history queries and heatmap generation slow down as history grows | Aggregate/downsample historical pings (e.g., keep raw for N days, roll up to hourly/daily summaries after) | Noticeable after a few months of continuous multi-family-member tracking, well before any "real scale" concern |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Duress-trigger logic sharing code paths/observable timing with normal auth | Attacker forcing device unlock can detect the duress mechanism exists, escalating real-world danger | Fully separate, silent, non-observable duress code path; no destructive/wipe behavior; QA'd explicitly for "does this look different to an observer" |
| Health + location data flowing through a shared generic analytics/logging pipeline | Accidental leak of sensitive health/location data to third-party analytics/crash-reporting SDKs | Architecturally isolate sensitive data paths from general telemetry; audit every SDK that touches the data layer |
| Long-lived static refresh tokens with no rotation/revocation | Stolen device or leaked token grants long-term access to a family's live location + health history | Refresh-token rotation, short access-token lifetime, explicit revoke-on-logout and revoke-on-password-change |
| No server-side RLS/authorization check assuming client-side role enforcement is sufficient | A Member or Caregiver role could query another family's or a Guardian-only data via a crafted API call | Enforce Postgres RLS + backend authorization on every family/role-scoped query, never trust client-supplied role claims alone |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Showing a live-looking location dot that's actually hours-stale (background tracking silently died) | Guardian believes they know where someone is when they don't — dangerous false confidence | Always show a "last updated X ago" staleness indicator; visually distinguish live vs. stale |
| SOS button shows "Sent" the instant the local API call returns, before any delivery confirmation | User believes help is coming when the alert may have silently failed to reach anyone | Show a progressive status ("Sending... Delivered to 2 of 3 guardians...") tied to actual delivery acks |
| Geofence/anomaly notifications fire too often on normal variation | Alert fatigue — guardians start ignoring all notifications, including real ones | Dwell-time/hysteresis for geofences; per-user AI baselines + adjustable sensitivity + cold-start suppression |
| Requesting all permissions (location always, health, notifications, camera, etc.) in one onboarding blast | High onboarding drop-off, user distrust of a "safety" app that behaves like a data-hungry app | Contextual, incremental permission requests tied to the specific feature being used at that moment |

## "Looks Done But Isn't" Checklist

- [ ] **Background location tracking:** Often missing OEM-killer resilience — verify by leaving the app backgrounded for 4+ hours on a real budget Android device (Xiaomi/Oppo/Samsung) with screen off and confirming location updates still arrive.
- [ ] **SOS alert delivery:** Often missing true end-to-end delivery confirmation — verify by force-quitting the guardian's app, then triggering SOS from another device, and confirming the guardian still receives the alert (via push/SMS fallback) within the target latency.
- [ ] **Silent/Duress trigger:** Often missing the "no observable difference" requirement — verify by having a third party watch the screen during a duress trigger and confirm they see nothing but the normal decoy flow (no spinner, no delay, no visual tell).
- [ ] **Geofencing:** Often missing dwell-time/hysteresis — verify by standing near (not crossing) a zone boundary for 10+ minutes and confirming no spurious enter/exit notifications fire.
- [ ] **AI anomaly/ETA features:** Often missing a cold-start path — verify by creating a brand-new family account with zero history and confirming the feature shows a sensible "still learning" state rather than garbage or silence.
- [ ] **Token/session security:** Often missing secure storage — verify by inspecting the app's local storage/shared_preferences on a rooted device/emulator and confirming no token is readable in plaintext.
- [ ] **Health data permissions:** Often missing narrow scoping — verify the permission dialog only requests the specific data types the Health module actually reads, not a blanket request.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Background tracking dies silently on OEM devices | MEDIUM | Add foreground service + persistent notification + WorkManager re-arm; add staleness indicator to UI; this is a targeted architecture fix, not a rewrite, if caught before too much UI logic assumes "always fresh" data |
| SOS delivery has a silent single point of failure | MEDIUM-HIGH | Add SMS fallback channel + delivery-ack tracking; requires backend changes (ack endpoint, retry logic) and client changes (progressive status UI) but doesn't require re-architecting the whole alert pipeline if it was built with a clean service boundary |
| Isolation Forest causing alert fatigue in production/testing | LOW-MEDIUM | Add per-user contamination tuning + rule-based post-filter + cold-start suppression window; doesn't require retraining approach, just wrapping the existing model call |
| Tokens stored insecurely and already shipped to test users | MEDIUM | Rotate to `flutter_secure_storage`, force-invalidate all existing tokens server-side, require re-login; the migration itself is straightforward but requires a coordinated client+server release |
| Scope collapse (many features half-done) | HIGH | Freeze new feature work, pick the single most complete vertical slice (should be SOS+tracking+auth per Core Value), cut everything else to "not in this milestone," and drive that one slice to a genuinely demoable state before resuming other features |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|--------------------|----------------|
| Background location silently dies (OS/OEM kills) | Location-tracking core phase | Real-device (budget OEM) 4+ hour backgrounded test; staleness indicator present in UI |
| SOS delivery single point of failure | SOS/alerting core phase | Force-quit + airplane-mode + background test matrix on guardian device; delivery-ack logged server-side |
| Geofencing flapping/false positives | Geofencing core phase | Stationary-near-boundary test produces zero spurious enter/exit events over 10+ minutes |
| Isolation Forest alert fatigue | AI/analytics phase (anomaly detection) | Synthetic-family test dataset with realistic day-to-day variation produces a false-positive rate low enough that no more than ~1 alert/week fires on non-anomalous data |
| ETA/predictive-geofencing cold start | AI/analytics phase (ETA + predictive geofencing) | Brand-new zero-history account shows a labeled fallback/"learning" state, not garbage or silence |
| Silent/Duress secret storage & observability | Silent/Duress SOS phase | Secure-storage code review + third-party "spot the difference" observation test on the duress flow |
| JWT/refresh-token handling | Auth/backend core phase | Local storage inspection on rooted device/emulator shows no plaintext token; refresh-rotation verified server-side |
| HealthKit/Health Connect compliance | Health & Wellness module phase | Permission dialog requests only specific used data types at first module use; privacy policy explicitly names HealthKit/Health Connect |
| Solo-dev scope collapse | Roadmap/phase-sequencing (cross-cutting) | Each phase boundary produces a genuinely demoable artifact, verified before starting the next phase, with core (auth+tracking+SOS) fully solid before any signature/AI feature phase begins |

## Sources

- [I Benchmarked Every Background Location Plugin for Flutter (Medium)](https://medium.com/@kiranbjm/i-benchmarked-every-background-location-plugin-for-flutter-android-ios-heres-why-most-of-them-5e46ba8fe472)
- [Handling Background Services in Flutter: Android 14 & iOS 17 (Medium)](https://medium.com/@shubhampawar99/handling-background-services-in-flutter-the-right-way-across-android-14-ios-17-b735f3b48af5)
- [Handling location updates in the background — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [iOS Background Execution Limits: What Every Developer Must Know (2026)](https://www.appsonair.com/blogs/background-execution-limits-in-ios-what-every-developer-must-know)
- [Understanding Significant Location in iOS: A Developer's Guide (Medium/Swiftfy)](https://medium.com/swiftfy/understanding-significant-location-in-ios-a-developers-guide-463162753a10)
- [Understand push notification delivery — Klaviyo Help Center](https://help.klaviyo.com/hc/en-us/articles/15594685536539)
- [Push Notifications Deep Dive: APNs & FCM Technical Guide](https://www.spritle.com/blog/push-notifications-deep-dive-the-ultimate-technical-guide-to-apns-fcm/)
- [Why Most Mobile Push Notification Architecture Fails](https://www.netguru.com/blog/why-mobile-push-notification-architecture-fails)
- [Understanding Client Disconnections and Reconnection in Azure SignalR — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-signalr/signalr-concept-client-disconnections)
- [Understanding and Handling Connection Lifetime Events in SignalR — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/signalr/overview/guide-to-the-api/handling-connection-lifetime-events)
- [How Geofence Push Notifications Work: Best Practices & Examples (NextBillion.ai)](https://nextbillion.ai/feeds/blog/geofence-push-notification-service)
- [How accurate is geofencing? The truth about real-world precision (Radar)](https://radar.com/blog/how-accurate-is-geofencing)
- [Combating Threat-Alert Fatigue with Online Anomaly Detection Using Isolation Forest (ACM/Springer)](https://dl.acm.org/doi/10.1007/978-3-030-36708-4_62)
- [Deep Isolation Forest for Anomaly Detection (arXiv)](https://arxiv.org/pdf/2206.06602)
- [The Cold-Start Problem In ML Explained & 6 Mitigating Strategies (SpotIntelligence)](https://spotintelligence.com/2024/02/08/cold-start-problem-machine-learning/)
- [Dealing with the new user cold-start problem in recommender systems (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S0306437914001525)
- [What Is Secure Storage in Flutter: Best Practices, Common Mistakes (LeanCode)](https://leancode.co/glossary/secure-storage-in-flutter)
- [Securely Store Tokens and API Keys in Flutter (Medium)](https://medium.com/@vikranthsalian/securely-store-tokens-and-api-keys-in-flutter-a-practical-guide-with-best-practices-b98b35e2565d)
- [I Built a Panic PIN Into My Photo Vault App — Jungle Labs](https://jungle-labs.co/en/blog/panic-pin-plausible-deniability/)
- [I use a duress PIN to protect my data — Android Authority](https://www.androidauthority.com/grapheneos-duress-pin-3584795/)
- [Designing a duress PIN: plausible deniability (Random Oracle)](https://blog.randomoracle.io/2021/05/29/designing-a-duress-pin-plausible-deniability-part-ii/)
- [Protecting user privacy — Apple HealthKit Developer Documentation](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [iOS App Store Requirements For Health Apps (Dash Solutions)](https://blog.dashsdk.com/app-store-requirements-for-health-apps/)
- [What You Can (and Can't) Do With Apple HealthKit Data](https://www.themomentum.ai/blog/what-you-can-and-cant-do-with-apple-healthkit-data)
- [This Is Why MOST Solo Dev Projects Fail (daily.dev)](https://preview.app.daily.dev/posts/this-is-why-most-solo-dev-projects-fail-dpb5hfvxa)
- [How to Prevent & Manage Scope Creep in MVP (Imaginovation)](https://imaginovation.net/blog/prevent-scope-creep-mvp-development/)
- [Does Life360 Drain Battery? (AEANET)](https://www.aeanet.org/does-life360-drain-battery/)
- [Life360 and Battery Usage — official Life360 support](https://support.life360.com/hc/en-us/articles/23053716563223-Life360-and-Battery-Usage)

---
*Pitfalls research for: Family-safety / real-time location-intelligence platform*
*Researched: 2026-07-06*
