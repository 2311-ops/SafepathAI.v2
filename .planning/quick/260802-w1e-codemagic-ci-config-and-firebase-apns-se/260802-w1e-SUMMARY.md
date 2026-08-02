---
phase: quick-260802-w1e
plan: 01
subsystem: infra
tags: [codemagic, ci-cd, flutter, ios, testflight, firebase, apns, fcm, documentation]

requires:
  - phase: 03-sos-fast-path
    provides: FCM multi-device push (03-06) code-complete but never provisioned/verified against a real Firebase/APNs project
provides:
  - codemagic.yaml CI configuration (iOS TestFlight + optional Android APK workflows)
  - docs/EXTERNAL-SETUP.md external provisioning runbook (Firebase, APNs, App Store Connect, Codemagic)
affects: [03-06 Task 3 verification, future TestFlight/App Store releases]

tech-stack:
  added: []
  patterns: ["Codemagic automatic ios_signing + App Store Connect integration for hosted-Mac iOS builds with no local Xcode/macOS", "Secure environment-variable groups + base64-encoded gitignored config materialized at build time, guarded by explicit fail-fast checks"]

key-files:
  created:
    - codemagic.yaml
    - docs/EXTERNAL-SETUP.md
  modified:
    - docs/CONFIGURATION.md

key-decisions:
  - "Named the two Codemagic environment-variable groups safepath_mobile_config and safepath_firebase_config, and the App Store Connect integration safepath_asc_api_key, verbatim across both codemagic.yaml and docs/EXTERNAL-SETUP.md so the UI setup and the yaml cannot drift apart."
  - "Both Codemagic workflows are manual-start only (no triggering block) to protect the free tier's 500 build-minutes/month budget, since most commits in this repo touch backend or planning files, not mobile."
  - "android-apk workflow builds --debug deliberately, not --release, because the app module's release build type is still signed with the debug keystore -- a release APK there would carry no more trust than debug and would mask that gap."
  - "docs/EXTERNAL-SETUP.md explicitly corrects 03-06-PLAN.md's superseded FIREBASE_PROJECT_ID/GOOGLE_APPLICATION_CREDENTIALS env var names to the shipped Firebase:ProjectId/Firebase:CredentialsPath binding (backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs), naming both the old and new names so a reader arriving from 03-06 finds a correction rather than a contradiction."
  - "docs/EXTERNAL-SETUP.md is a new docs/ living-doc location (SCREAMING-KEBAB, matching the existing docs/ convention) rather than a .planning/ phase-scoped artifact, since it must outlive any single phase and carries a running 'Still outstanding' external-provisioning checklist."

patterns-established:
  - "External third-party provisioning documentation lives in docs/EXTERNAL-SETUP.md, separate from docs/CONFIGURATION.md's local-env-file scope; new external dependencies get appended to its 'Still outstanding' table rather than spawning new docs."

requirements-completed: [SOS-02, NOTIF-03]

coverage:
  - id: D1
    description: "codemagic.yaml defines a manual-start ios-testflight workflow (mac_mini_m2, working_directory mobile, automatic app_store code signing via the App Store Connect integration, auto-incremented TestFlight build number, gitignored-config materialization with fail-fast checks) and a manual-start android-apk workflow (debug APK), with zero literal credentials"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "python -c yaml.safe_load structural assertions (workflows keys, working_directory, ios_signing.bundle_identifier, integrations.app_store_connect, publishing.app_store_connect.submit_to_testflight/auth, absence of triggering) -- see PLAN.md Task 1 <verify>"
        status: pass
      - kind: other
        ref: "grep-based negative/positive checks: working_directory: mobile x2, com.safepath.mobile, dart-define-from-file=env.json x2, get-latest-testflight-build-number, GoogleService-Info.plist, google-services.json, EXTERNAL-SETUP.md, zero occurrences of BEGIN PRIVATE KEY"
        status: pass
    human_judgment: true
    rationale: "No macOS/Xcode host is available in this environment (Windows dev machine, per PLAN.md's stated constraint) and no Codemagic/Firebase/Apple Developer accounts exist yet to actually run this workflow. YAML structure, credential-free grep checks, and diff scope are all verified automatically; whether a real Codemagic build actually produces and uploads a signed IPA can only be confirmed once a human completes the accounts/keys in docs/EXTERNAL-SETUP.md and runs the workflow."
  - id: D2
    description: "docs/EXTERNAL-SETUP.md runbook covers Firebase project/app registration, APNs key upload, corrected backend Firebase/Twilio config keys, App Store Connect API key creation, Codemagic account/variable/integration setup (every codemagic.yaml var/group/integration name cross-referenced verbatim), a condensed FCM verification checklist with troubleshooting table, known gotchas (aps-environment sandbox-vs-production, generated Podfile, iOS deployment target, missing-config-file silent failure), and a seeded 'Still outstanding' external-provisioning list; docs/CONFIGURATION.md gains exactly one cross-reference line"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "python string-membership assertions for required section/term presence (Prerequisites, Firebase, APNs, App Store Connect, Codemagic, Still outstanding, com.safepath.mobile x2+, Firebase__ProjectId, Firebase__CredentialsPath, Twilio__AccountSid, aps-environment, Podfile), line count > 80, and CONFIGURATION.md cross-reference presence -- see PLAN.md Task 2 <verify>"
        status: pass
      - kind: other
        ref: "grep checks: Firebase__ProjectId >=1, GOOGLE_APPLICATION_CREDENTIALS >=1 (correction note only), developer.apple.com/programs >=1, case-insensitive android >=3 (actual 16), every codemagic.yaml var/group/integration name (safepath_mobile_config, safepath_firebase_config, safepath_asc_api_key, APP_STORE_APPLE_ID, MOBILE_ENV_JSON, GOOGLE_SERVICE_INFO_PLIST_BASE64, GOOGLE_SERVICES_JSON_BASE64, API_BASE_URL) present verbatim, git diff --stat docs/CONFIGURATION.md shows exactly 1 insertion/0 deletions"
        status: pass
    human_judgment: true
    rationale: "This is a human-facing runbook whose ultimate correctness (whether a real developer following it end-to-end actually reaches a working TestFlight build and a real FCM push) can only be judged by a human actually walking through Firebase console, Apple Developer portal, App Store Connect, and Codemagic UI steps -- none of which exist in this environment yet. Automated checks verify content presence, required terms, and internal consistency with codemagic.yaml, not real-world dashboard correctness."

duration: 25min
completed: 2026-08-02
status: complete
---

# Quick Task 260802-w1e: Codemagic CI Config and Firebase/APNs External Setup Runbook Summary

**Added `codemagic.yaml` (hosted macOS CI building/signing an iOS IPA to TestFlight via Codemagic's automatic signing + App Store Connect integration, plus an optional Android APK workflow) and `docs/EXTERNAL-SETUP.md` (the human runbook for Firebase, APNs, App Store Connect, and Codemagic provisioning), unblocking the pending 03-06 Task 3 FCM verification todo for a developer with no Mac.**

## Performance

- **Duration:** 25 min
- **Completed:** 2026-08-02
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments
- `codemagic.yaml`: a `ios-testflight` workflow (mac_mini_m2, `working_directory: mobile`, `ios_signing` with `distribution_type: app_store` and `bundle_identifier: com.safepath.mobile`, App Store Connect integration `safepath_asc_api_key`, gitignored-config materialization from secure variables with fail-fast checks naming the missing variable, auto-incremented TestFlight build number via `app-store-connect get-latest-testflight-build-number`, and `submit_to_testflight: true` publishing) plus an `android-apk` workflow (debug APK, deliberately not release-signed). Both workflows are manual-start only (no `triggering` block) to protect the Codemagic free tier's 500 build-minutes/month budget.
- `docs/EXTERNAL-SETUP.md`: a new docs/ living runbook leading with the paid Apple Developer Program prerequisite and the free Android-only fallback, covering Firebase project/app registration against `com.safepath.mobile`, APNs authentication key upload, the backend's actual `Firebase__ProjectId`/`Firebase__CredentialsPath`/`Twilio__AccountSid` etc. configuration keys (explicitly correcting 03-06's superseded `FIREBASE_PROJECT_ID`/`GOOGLE_APPLICATION_CREDENTIALS` names), App Store Connect API key creation, Codemagic account/variable/integration setup (with every `codemagic.yaml` variable and group name cross-referenced verbatim, and PowerShell base64-encoding commands for a Windows developer), a condensed 10-step-to-troubleshooting-table FCM verification checklist, known gotchas (`aps-environment` sandbox-vs-production entitlement, the not-committed/generated `Podfile`, iOS deployment target vs. Firebase SDK minimum, silent-failure-on-missing-config), and a seeded "Still outstanding" table of other external provisioning this project still needs.
- `docs/CONFIGURATION.md` gained exactly one cross-reference line pointing to the new runbook.

## Task Commits

1. **Task 1: Codemagic workflow for iOS TestFlight (primary) and Android APK (optional)** - `92abded` (feat)
2. **Task 2: External provisioning runbook and its cross-reference** - `20fd982` (docs)

**Plan metadata:** committed separately by the orchestrator after this summary.

## Files Created/Modified
- `codemagic.yaml` - Codemagic CI config: `ios-testflight` (primary, TestFlight upload) and `android-apk` (optional, debug APK) workflows, both rooted at `mobile/`, zero literal credentials.
- `docs/EXTERNAL-SETUP.md` - External provisioning runbook for Firebase, APNs, App Store Connect, and Codemagic; seeded running list of outstanding external dependencies.
- `docs/CONFIGURATION.md` - One added cross-reference line to `EXTERNAL-SETUP.md`.

## Decisions Made
- Named the two Codemagic environment-variable groups `safepath_mobile_config` and `safepath_firebase_config`, and the App Store Connect integration `safepath_asc_api_key`, identically in both `codemagic.yaml` and the runbook so the Codemagic UI setup and the committed config cannot silently drift apart.
- Both workflows are manual-start only (no `triggering` block) — the free tier's 500 build-minutes/month is easily burned by an automatic trigger on a repo where most commits are backend/planning, not mobile.
- `android-apk` builds `--debug`, not `--release`, because `mobile/android/app/build.gradle.kts`'s `release` build type is still signed with the debug keystore — a "release" APK there would carry no more trust than debug and would mask that unresolved gap (tracked in the runbook's "Still outstanding" table).
- Explicitly corrected 03-06-PLAN.md's `user_setup` env var names (`FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`) to the names the shipped `FirebaseOptions` binding actually reads (`Firebase:ProjectId`, `Firebase:CredentialsPath`), naming both explicitly in the runbook so a reader arriving from the older plan finds a correction, not a silent contradiction.

## Deviations from Plan

None - plan executed exactly as written. One in-flight self-correction during Task 2 verification: the first draft of the `docs/CONFIGURATION.md` cross-reference edit added a blank separator line in addition to the new sentence, producing a 2-line diff against the plan's stated "exactly one line added" acceptance criterion; reworded to a plain adjacent line with no blank-line insertion so the diff is exactly 1 insertion / 0 deletions. This was corrected before either task commit was made, so no commit needed amending.

## Issues Encountered
None.

## User Setup Required

**External services require manual configuration.** See [docs/EXTERNAL-SETUP.md](../../../docs/EXTERNAL-SETUP.md) for:
- Apple Developer Program enrolment (paid, prerequisite for all iOS steps) and the free Android-only fallback
- Firebase project creation and Android/iOS app registration (`google-services.json`, `GoogleService-Info.plist`)
- APNs authentication key generation and upload to Firebase
- Backend `Firebase__ProjectId`/`Firebase__CredentialsPath` environment configuration
- App Store Connect app record and API key creation
- Codemagic account creation, repository connection, App Store Connect integration registration, and the environment-variable groups `codemagic.yaml` references
- The condensed FCM end-to-end verification checklist (originally 03-06 Task 3's ten-step script)

None of this was performed as part of this quick task — all of it is human-only per the plan's explicit non-goals (no external account/project/key creation, no application code change, no touching `mobile/ios/Runner/Runner.entitlements` or `Info.plist`).

## Next Phase Readiness
- The pending todo `.planning/todos/pending/2026-08-02-provision-firebase-apns-and-verify-fcm-push-deep-link.md` (03-06 Task 3) is now actionable by a human with no further investigation: `docs/EXTERNAL-SETUP.md` gives exact console paths, exact configuration key names, and a condensed verification checklist.
- `codemagic.yaml` is ready to run in Codemagic once the accounts/keys/variables in `docs/EXTERNAL-SETUP.md`'s "Codemagic setup" section are provisioned; no further repository changes are needed to attempt a first build.
- Blocker carried forward (unchanged by this task, tracked in the runbook's "Still outstanding" table): the `aps-environment` entitlement is `development` for every build configuration, so no TestFlight/App Store push test should be trusted as proving production delivery until a per-configuration entitlements split exists — explicitly out of scope for this task per its non-goals.
- Blocker carried forward: Android release signing keystore is still the debug keystore; not required to unblock 03-06 Task 3 verification (which can run on `flutter build apk --debug` or `flutter run`), but flagged for whenever a real Play Store release is considered.

---
*Phase: quick-260802-w1e*
*Completed: 2026-08-02*

## Self-Check: PASSED

- FOUND: codemagic.yaml
- FOUND: docs/EXTERNAL-SETUP.md
- FOUND: docs/CONFIGURATION.md
- FOUND: commit 92abded (Task 1)
- FOUND: commit 20fd982 (Task 2)
