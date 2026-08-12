# External Setup

This document covers one-time provisioning of third-party services that live outside this
repository: Firebase, Apple Push Notification service (APNs), App Store Connect, and Codemagic.
Local configuration file contents and the keys the app and backend read from them stay in
[`CONFIGURATION.md`](./CONFIGURATION.md); this document is about accounts, dashboards, and
credentials that exist outside the repo.

Nothing here is required to build, test, or demo this project. The backend falls back to a
logging implementation for both push (`LoggingPushSender`) and SMS (`LoggingSmsGateway`) whenever
Firebase or WhatsApp credentials are absent, and the mobile app catches and logs a failed
`Firebase.initializeApp` rather than crashing. This document is required only to exercise real
push delivery end to end and to ship a signed iOS build to TestFlight.

## Prerequisites and Costs

iOS push notifications and TestFlight distribution both require a paid Apple Developer Program
membership (an annual fee, enrolment at `developer.apple.com/programs`). There is no free path to
an APNs authentication key or to a TestFlight build. Do not start the iOS-specific sections below
without an active membership; every iOS step in this document assumes one already exists.

Codemagic's free tier grants 500 build minutes per month on macOS M2 runners and does not require
a payment card to start an account.

Firebase Cloud Messaging on Android is entirely free and needs no Apple account of any kind. If an
Apple Developer Program membership is not yet available, the FCM verification in "Verifying FCM
end to end" below can be completed on Android alone: register only the Android app in Firebase,
skip the entire "APNs authentication key" section, run the `android-apk` Codemagic workflow (or a
local `flutter run`) instead of `ios-testflight`, and defer steps that name iOS or TestFlight
specifically until Apple Developer Program enrolment completes.

| Item | Cost | Unlocks |
| --- | --- | --- |
| Apple Developer Program membership | Paid, annual | APNs auth key, TestFlight, iOS code signing |
| Firebase project | Free | FCM push on Android and iOS, backend push sender |
| Codemagic account | Free tier (500 build minutes/month, macOS M2) | `codemagic.yaml` CI builds, TestFlight upload |
| WhatsApp Business Cloud API (Meta Graph API) | Free for Utility-category template sends within Meta's free tier conversation limits | Real SOS fallback SMS delivery plus a genuine HMAC-signed delivery-status webhook (see "Still outstanding") |

## Firebase Project and App Registration

1. Create a Firebase project, or reuse an existing one.
   Location: `Firebase Console -> Add project` (or select an existing project).
2. Register the Android app using the package name `com.safepath.mobile`.
   Location: `Firebase Console -> Project settings -> Your apps -> Add app -> Android`.
3. Download `google-services.json` and place it at:

   ```text
   mobile/android/app/google-services.json
   ```

4. Register the iOS app using the bundle identifier `com.safepath.mobile`.
   Location: `Firebase Console -> Project settings -> Your apps -> Add app -> iOS`.
5. Download `GoogleService-Info.plist` and place it at:

   ```text
   mobile/ios/Runner/GoogleService-Info.plist
   ```

Both files are gitignored by design (`mobile/.gitignore`) and must never be committed. The Google
Services Gradle plugin is already wired at version 4.4.4 in `mobile/android/build.gradle.kts` and
applied in `mobile/android/app/build.gradle.kts`, so no Gradle edit is needed once
`google-services.json` is in place.

## APNs Authentication Key

1. Generate an APNs authentication key.
   Location: `developer.apple.com -> Certificates, Identifiers & Profiles -> Keys -> Create a key`,
   with the Apple Push Notifications service (APNs) capability enabled.
2. Download the private key file (`.p8`) immediately. It can only be downloaded once; if it is
   lost, a new key must be generated.
3. Record the Key ID shown next to the key, and the Team ID from
   `developer.apple.com -> Membership details`.
4. Upload the key with those two ids.
   Location: `Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration
   -> APNs Authentication Key -> Upload`.

iOS push notifications silently never arrive without this step, and no error surfaces anywhere in
the app or backend to explain why. This is the single most common FCM-on-iOS failure.

The Push Notifications capability and the remote-notification background mode are already
committed in `mobile/ios/Runner/Runner.entitlements` and `mobile/ios/Runner/Info.plist`. No Xcode
GUI action is required for either capability. This supersedes the corresponding
"Enable Push Notifications and Background Modes" line in `03-06-PLAN.md`'s `user_setup` block,
which predates that entitlements/Info.plist work landing in the codebase.

## Backend Configuration Keys

The backend binds these configuration keys, following the same double-underscore-to-colon mapping
described in `CONFIGURATION.md` (`Firebase__ProjectId` in an environment variable or `.env` file
maps to the `Firebase:ProjectId` configuration value the code reads).

| Key | Purpose |
| --- | --- |
| `Firebase__ProjectId` | Firebase project id, from `Firebase Console -> Project settings -> General -> Project ID` |
| `Firebase__CredentialsPath` | Absolute path to a Firebase service-account JSON key, from `Firebase Console -> Project settings -> Service accounts -> Generate new private key` |
| `WhatsApp__AccessToken` | Meta System User access token with `whatsapp_business_messaging` + `whatsapp_business_management` scopes, from `Meta Business Suite -> Business settings -> Users -> System users -> Generate new token` |
| `WhatsApp__PhoneNumberId` | The sending phone number's id, from `Meta App Dashboard -> WhatsApp -> API Setup -> Phone number ID` |
| `WhatsApp__WabaId` | The WhatsApp Business Account id, from `Meta App Dashboard -> WhatsApp -> API Setup -> WhatsApp Business Account ID` |
| `WhatsApp__AppSecret` | The Meta app's secret, from `Meta App Dashboard -> App settings -> Basic -> App secret` — used only to verify `X-Hub-Signature-256` on inbound status callbacks |
| `WhatsApp__WebhookVerifyToken` | An operator-chosen random string; must be typed identically into `Meta App Dashboard -> WhatsApp -> Configuration -> Webhook -> Verify token` |
| `WhatsApp__TemplateName` | The approved Utility-category template name (the SOS alert template). Must NOT be a separate Authentication-category template (e.g. `otp_verification`) — Meta locks those to OTP-only. The template body must carry exactly three body placeholders (see "WhatsApp Business Platform Setup" step 4) — the backend always sends three ordered template parameters |
| `WhatsApp__TemplateLanguage` | Optional; defaults to `en` when unset |
| `WhatsApp__BaseUrl` | Optional; defaults to `https://graph.facebook.com` when unset |
| `WhatsApp__ApiVersion` | Optional; defaults to the Graph API version pinned in `WhatsAppOptions` when unset |

`03-06-PLAN.md`'s `user_setup` block named these variables `FIREBASE_PROJECT_ID` and
`GOOGLE_APPLICATION_CREDENTIALS`. Those names are superseded: the shipped
`backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs` binds `Firebase:ProjectId` and
`Firebase:CredentialsPath`, and the names in the table above are authoritative.

Save the Firebase service-account JSON file outside the repository and set
`Firebase__CredentialsPath` to its absolute path. Never commit it. All WhatsApp values above go
only into the local gitignored `backend/.env` and never into `appsettings.json` or any committed
file.

Observable success signal: on restart, the API logs "Push sender active: FirebasePushSender
(Firebase credentials configured)" rather than the logging sender, and separately logs "SMS
gateway active: WhatsAppSmsGateway (WhatsApp credentials configured)" rather than its own logging
fallback. If either log line still names the logging implementation after setting the
corresponding keys, the values were not read (check for typos in the key names or a missing
restart).

## WhatsApp Business Platform Setup

The SOS emergency-contact fallback channel sends through the WhatsApp Business Cloud API (Meta
Graph API) when configured, and through `LoggingSmsGateway` (free, no account) when not.

1. Create a Meta app and a WhatsApp Business Account (WABA), or reuse existing ones.
   Location: `developers.facebook.com/apps -> Create App -> Business -> add the WhatsApp
   product`.
2. Generate a System User access token with the `whatsapp_business_messaging` and
   `whatsapp_business_management` permissions.
   Location: `Meta Business Suite -> Business settings -> Users -> System users -> Generate new
   token`.
   A temporary 24-hour token issued from `API Setup` will expire and is not suitable for anything
   beyond a first smoke test — use the System User token for anything that needs to keep working.
3. Locate the Phone Number ID (`1190449597495068`) and WABA ID (`1605779661263531`).
   Location: `Meta App Dashboard -> WhatsApp -> API Setup`.
4. Create and submit the Utility-category SOS template for approval (e.g. `sos_alert`), containing
   three body placeholders, in order: the triggering member's name, the location link, and the
   trigger timestamp. The placeholder count must match what the backend sends, or Meta rejects
   every send with a parameter-count mismatch. For example, the template body might read: `{{1}}
   triggered an SOS on SafePath and needs help. Location: {{2}}. Time: {{3}}.`
   Location: `Meta App Dashboard -> WhatsApp -> Message Templates -> Create Template`.
   Do **not** use the separately-approved `otp_verification` Authentication-category template for
   SOS content — Meta locks Authentication templates to OTP-only, and setting it as
   `WhatsApp__TemplateName` will fail every send.
5. Subscribe the webhook once the API is reachable over a public https origin: set the callback
   URL to that origin plus `/webhooks/sms/status`, set the verify token to match
   `WhatsApp__WebhookVerifyToken` exactly, and subscribe the WABA to the `messages` field — no
   status callback arrives until this subscription is active.
   Location: `Meta App Dashboard -> WhatsApp -> Configuration -> Webhook`.

Two recipient-side caveats that will otherwise surprise the operator:

- An emergency contact must have WhatsApp installed on the number stored in
  `EmergencyContact.PhoneNumberE164` — the send fails otherwise.
- Unverified/development Meta apps are limited to sending to pre-registered test recipient
  numbers until the business is verified.

## App Store Connect API Key

1. Create the app record in App Store Connect using the bundle identifier `com.safepath.mobile`.
   Location: `App Store Connect -> Apps -> +`. Record the app's numeric Apple ID shown on the
   app's General information page — `codemagic.yaml` needs this value as `APP_STORE_APPLE_ID`.
2. Generate a team API key with a role sufficient to upload builds (App Manager or Admin).
   Location: `App Store Connect -> Users and Access -> Integrations -> App Store Connect API ->
   Generate API Key`.
3. Record the Issuer ID (shown above the key list) and the Key ID (shown next to the generated
   key).
4. Download the private key file (`.p8`) once. It can only be downloaded once.

## Codemagic Setup

1. Create a Codemagic account and connect this repository.
   Location: `codemagic.io -> Add application`.
2. Register the App Store Connect API key (Issuer ID, Key ID, and the downloaded `.p8` file) as an
   integration, naming it exactly `safepath_asc_api_key` — `codemagic.yaml` references this exact
   string in its `integrations.app_store_connect` key.
   Location: `Codemagic -> Team settings (or personal account) -> Integrations -> App Store
   Connect -> Add key`.
3. Create the two environment-variable groups `codemagic.yaml` references, and add the variables
   below to each. Group and variable names must match exactly, or the workflow fails at the
   "Materialize gitignored configuration from secure variables" script step.
   Location: `Codemagic -> Application settings -> Environment variables`.

| Variable | Group | Secure | Value | How to produce it |
| --- | --- | --- | --- | --- |
| `MOBILE_ENV_JSON` | `safepath_mobile_config` | yes | Full contents of `mobile/env.json` | Copy `mobile/env.json`'s JSON contents (see `CONFIGURATION.md`, "Mobile Configuration") verbatim into the variable value |
| `API_BASE_URL` | `safepath_mobile_config` | no | A host testers can reach, e.g. `https://api.safepath.example.com` | Must not be a loopback (`127.0.0.1`) or Android-emulator (`10.0.2.2`) address — TestFlight testers run on real devices with no route to your development machine |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `safepath_firebase_config` | yes | Base64 of `mobile/ios/Runner/GoogleService-Info.plist` | See PowerShell command below |
| `GOOGLE_SERVICES_JSON_BASE64` | `safepath_firebase_config` | yes | Base64 of `mobile/android/app/google-services.json` | See PowerShell command below |
| `APP_STORE_APPLE_ID` | (workflow `vars`, or a secure group) | optional | The numeric Apple ID recorded in "App Store Connect API key" step 1 | Copy from the app's General information page in App Store Connect |

Because development happens on Windows, produce each base64 value with PowerShell rather than a
Unix `base64` command:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("mobile/ios/Runner/GoogleService-Info.plist"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("mobile/android/app/google-services.json"))
```

Paste each command's full output as the corresponding variable's value in the Codemagic UI.

To start a build, open the application in Codemagic, choose the `ios-testflight` or `android-apk`
workflow, and click "Start new build" — both workflows are manual-start by design, with no
automatic trigger, to protect the free tier's monthly build-minute budget. The built IPA/APK and
build logs are collected as artifacts on the finished build's page, downloadable from there
without any local macOS or Xcode installation.

## Verifying FCM End to End

This condenses `03-06-PLAN.md`'s Task 3 ten-step verification script down to the steps that carry
the actual pass/fail signal. See that plan file for the full script.

1. Confirm the Firebase and APNs steps above are complete for both platforms being tested.
2. Set `Firebase__ProjectId` and `Firebase__CredentialsPath` for the backend and restart it.
   Confirm the startup log names `FirebasePushSender`, not the logging sender.
3. Sign in as a Guardian on device B, in the same family as device A.
4. Fully background device B (press Home — do not just switch screens within the app).
5. On device A, press and hold the SOS button for three seconds.
6. On device B, confirm a heads-up notification arrives naming the sender.
7. Tap the notification. Confirm the app opens directly on the SOS Responder Alert screen for that
   exact session — not the Live Map, not the home shell.
8. On device A's emergency session, confirm device B's delivery chip moves from Queued to
   Delivered.
9. Repeat steps 4-7 with device B fully terminated (swipe the app away) to exercise the cold-start
   `getInitialMessage` path.
10. If the Guardian is signed in on a second device, confirm both devices received the
    notification.

| Symptom | Likely cause |
| --- | --- |
| Nothing arrives on iOS | No APNs authentication key uploaded to Firebase, or the wrong Key ID/Team ID recorded — see "APNs authentication key" |
| Nothing arrives on Android | `google-services.json` missing or in the wrong path, or the backend still logs `LoggingPushSender` at startup |
| Notification arrives but the tap lands on the wrong screen | Cold-start `getInitialMessage` path not exercised — repeat with the app fully terminated, not just backgrounded |
| Delivery chip stays Queued forever | Device never called `POST /sos/{id}/push-receipt`, or the tapped notification did not reach `push_service.dart`'s handler — confirm the app registered a device token on sign-in |

## Known Gotchas

### Production APNs entitlement

The committed `mobile/ios/Runner/Runner.entitlements` sets `aps-environment` to `development`. A
TestFlight or App Store build is signed for distribution and registers against the APNs
production environment, not the sandbox — but Apple requires the entitlement value to match the
signing environment, so a distribution-signed build carrying the `development` value has its push
capability rejected or silently fails to register for remote notifications. Before trusting any
TestFlight push test, a per-configuration entitlements setup is required so the Release
configuration carries the production `aps-environment` value while Debug keeps `development`. This
is intentionally not changed as part of this setup — it is scoped out of `codemagic.yaml` and this
document, which only provision the build pipeline and the third-party accounts it depends on.

### Podfile is generated, not committed

`mobile/ios/Podfile` is not committed to this repository — it is generated by the Flutter tool on
the first iOS build. A first Codemagic run therefore does more work than later runs (CocoaPods
resolves and installs dependencies for the first time), and a `pod install` failure on that first
run is expected to be about a deployment-target or plugin-resolution conflict rather than a defect
in `codemagic.yaml` itself.

### iOS deployment target versus Firebase SDK minimum

`mobile/ios/Runner.xcodeproj`'s `IPHONEOS_DEPLOYMENT_TARGET` is currently `13.0`. The Firebase iOS
SDK pulled in transitively by `firebase_core ^4.12.1` and `firebase_messaging ^16.4.3` may require
a higher minimum. If CocoaPods fails on the first Codemagic build with a deployment-target
conflict, the fix is to raise the deployment target in the Xcode project and in the generated
Podfile to the version CocoaPods names in its own error message. No specific required version is
asserted here — record it in this document once the first real build reports it.

### Every gitignored config file must exist before the build

`mobile/env.json`, `mobile/android/app/google-services.json`, and
`mobile/ios/Runner/GoogleService-Info.plist` must all exist on the build runner before any build
step runs. If one is silently missing, the build still produces an app that installs and runs, and
that app then silently never receives a push — there is no error message anywhere pointing at the
missing file. `codemagic.yaml`'s materialization scripts fail loudly by name if the corresponding
secure variable is unset; do not remove those checks.

## Still Outstanding

This list is appended to as new external dependencies appear during development. It is the reason
this document lives in `docs/` rather than under a phase directory in `.planning/` — it is meant
to outlive any single phase.

| Item | Why it is needed | When it becomes blocking | Status |
| --- | --- | --- | --- |
| OpenStreetMap production tile-hosting provider (MapTiler, Stadia Maps, or Thunderforest) | OSM's own tile server (`tile.openstreetmap.org`) is rate-limited and its usage policy disallows production app traffic at scale; see `.planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md` | Before any real-user traffic; no key is needed for development | Outstanding |
| Android release signing keystore | The app module's `release` build type is still signed with the debug keystore (`mobile/android/app/build.gradle.kts`) | Before a real Play Store release; the `android-apk` Codemagic workflow deliberately builds `--debug` to avoid masking this gap | Outstanding |
| Release-configuration APNs production entitlement | `aps-environment` is `development` for every build configuration today; see "Production APNs entitlement" above | Before any TestFlight or App Store push delivery can be trusted | Outstanding |
| WhatsApp Business Cloud API provisioning | Real SOS SMS delivery to emergency contacts plus a genuine Delivered status; the code path is complete since quick task 260812-wgl but `backend/.env` is not yet populated and the webhook is not yet subscribed | Before a real SOS SMS can be sent or a delivery status can be confirmed | Outstanding (code-complete, unprovisioned) |
| Supabase Storage `avatar` bucket | Backend-mediated avatar upload/delete/signed-URL creation reads/writes this private bucket | Already required for profile-photo features | Done (verified in 02-13) |
| Six Labors ImageSharp license | ImageSharp 4.0.0 enforces a build-time license (`sixlabors.lic` or `SIXLABORS_LICENSE_KEY`); required to build the backend at all | Every backend build, including CI | Outstanding for CI (a local uncommitted license file exists per developer machine per 02-13) |
