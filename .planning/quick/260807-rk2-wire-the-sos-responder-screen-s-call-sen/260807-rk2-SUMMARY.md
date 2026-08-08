---
phase: quick-260807-rk2
plan: 01
subsystem: sos
tags: [aspnetcore, ef-core, riverpod, flutter, libphonenumber, signalr, phone-number, privacy]

# Dependency graph
requires:
  - phase: 03-05
    provides: PhoneNumberNormalizer (libphonenumber-csharp E.164 normalisation), EmergencyContact.PhoneNumberE164 naming convention
  - phase: 03-04
    provides: responder_alert_screen.dart's Call sender button and the 03-04 Known Stub it closes
provides:
  - Nullable User.PhoneNumberE164 column + PATCH /me/phone-number (settable/clearable)
  - Recipient-scoped SosSessionDto.TriggeredByPhoneNumberE164, visible only to a session's actual delivery-attempt recipients
  - Mobile profile phone-number card and a Call sender button that dials the real number
affects: [03-secure-phase-audit, future phases touching SosSessionDto or User profile fields]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-entry-point projection: a REQUIRED-parameter general entry point (ProjectAsync) plus one explicitly-named, doc-locked fan-out-only entry point (ProjectForRecipientAudienceAsync) for the one caller with no single caller id"
    - "Mobile null-means-fallback dial URI: sosDialUri(String?) builds an empty-path tel: URI on null/blank input instead of throwing or omitting the button"

key-files:
  created:
    - backend/src/SafePath.Application/Profile/UpdatePhoneNumberCommand.cs
    - backend/tests/SafePath.Application.Tests/Sos/SosSenderPhoneVisibilityTests.cs
    - mobile/test/features/sos/sos_call_sender_test.dart
    - mobile/test/features/profile/profile_phone_number_test.dart
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260807171030_AddUserPhoneNumber.cs
  modified:
    - backend/src/SafePath.Domain/Entities/User.cs
    - backend/src/SafePath.Application/Sos/SosSessionProjection.cs
    - backend/src/SafePath.Application/Sos/SosDtos.cs
    - backend/src/SafePath.Api/Controllers/MeController.cs
    - mobile/lib/features/sos/presentation/responder_alert_screen.dart
    - mobile/lib/features/profile/presentation/profile_screen.dart

key-decisions:
  - "SosSessionProjection.ProjectAsync's callerUserId parameter is REQUIRED (no default) so the compiler forces every existing/future call site to state whose eyes the payload is for."
  - "ProjectForRecipientAudienceAsync is a dedicated, explicitly-doc-locked entry point naming SosAlertDispatcher.DispatchSignalR as its only legal caller, since that fan-out has no single caller id but its own address list is already scoped to the recipient set."
  - "UpdatePhoneNumberCommandHandler deliberately does not stamp ProfileUpdatedAt or call BroadcastUpdatedAsync, unlike the display-name handler -- the number is not part of ProfileUpdateDto and stamping would needlessly bust every family member's cached avatar for a change they cannot see."
  - "PhoneNumberE164 is nullable with no backfill and no default -- signup, the Supabase user-sync trigger, family join, and SOS trigger all work unchanged for a null column."

requirements-completed: [QUICK-RK2-USER-PHONE-FIELD, QUICK-RK2-PATCH-ME-PHONE, QUICK-RK2-RECIPIENT-SCOPED-EXPOSURE, QUICK-RK2-PROFILE-UI, QUICK-RK2-CALL-SENDER-DIALS]

coverage:
  - id: D1
    description: "Nullable PhoneNumberE164 column on Users, applied to the live Supabase database via the AddUserPhoneNumber migration"
    requirement: "QUICK-RK2-USER-PHONE-FIELD"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#GetMe_ReturnsStoredPhoneNumberForOwningUser"
        status: pass
      - kind: other
        ref: "dotnet ef migrations list shows 20260807171030_AddUserPhoneNumber with no (Pending) marker"
        status: pass
    human_judgment: false
  - id: D2
    description: "PATCH /me/phone-number normalises via PhoneNumberNormalizer, rejects unparseable input with the normaliser's own 400 message, and clears the stored value on blank input"
    requirement: "QUICK-RK2-PATCH-ME-PHONE"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_NormalisesNationalFormatWithRegionHintToE164"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_RejectsUnparseableValueAndLeavesStoredValueUntouched"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_ClearsStoredValueOnBlankInput"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_DoesNotStampProfileUpdatedOrBroadcast"
        status: pass
    human_judgment: false
  - id: D3
    description: "SosSessionDto.TriggeredByPhoneNumberE164 is populated only for a session's actual delivery-attempt recipients -- never to the sender, never to a family member who merely passed membership, and the SignalR broadcast audience excludes the sender"
    requirement: "QUICK-RK2-RECIPIENT-SCOPED-EXPOSURE"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SosSenderPhoneVisibilityTests.cs (5 tests: recipient sees it, sender never sees own number, non-recipient member sees null despite membership, no-stored-number sender yields null, fresh+idempotent trigger replay carry null)"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs#Dispatch_BroadcastsSendersPhoneNumberToTheRecipientAudienceOnlyAndExcludesTheSender"
        status: pass
    human_judgment: false
  - id: D4
    description: "Mobile profile screen renders a phone-number card seeded from the loaded profile; saving persists the typed value; an empty save clears the number and reports removal, not an error"
    requirement: "QUICK-RK2-PROFILE-UI"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#renders a phone-number field seeded from the loaded profile and saves the typed value"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#saving an empty phone-number field calls the api with a clearing value and reports removal"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#ProfileController.updatePhoneNumber surfaces a ProfileApiException's message into state.error"
        status: pass
    human_judgment: false
  - id: D5
    description: "responder_alert_screen.dart's Call sender button dials the real E.164 number when present, and reproduces today's exact bare-dialler behaviour when absent -- no error, no crash, no on-screen rendering of the number"
    requirement: "QUICK-RK2-CALL-SENDER-DIALS"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_call_sender_test.dart (6 tests: wire parsing present/absent-key/explicit-null, dial-URI present/null/blank)"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/sos/responder_alert_screen_test.dart (zero edits, all 18 tests still pass -- Acknowledge flow, live-location card, canceled state, button layout unaffected)"
        status: pass
    human_judgment: false

duration: ~50min
completed: 2026-08-07
status: complete
---

# Phase Quick-260807-rk2: Wire the SOS Responder "Call sender" Button Summary

**Recipient-scoped SosSessionDto.TriggeredByPhoneNumberE164 fed by a nullable User.PhoneNumberE164 column, exposed through a two-entry-point SosSessionProjection and a real profile phone-number field, closing the 03-04 Known Stub where Call sender always opened a blank OS dialler.**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3
- **Files modified:** 21 (11 backend, 10 mobile)

## Accomplishments
- `User.PhoneNumberE164` (nullable, no backfill) + `PATCH /me/phone-number` reusing `PhoneNumberNormalizer.ToE164`, applied against the live Supabase database via `dotnet ef database update`
- `SosSessionProjection` reworked into a required-caller-id `ProjectAsync` entry point plus a doc-locked `ProjectForRecipientAudienceAsync` entry point that is the sole legal caller for `SosAlertDispatcher.DispatchSignalR`'s fan-out; all six existing call sites updated
- Mobile profile screen gained a phone-number card (empty save = remove, not an error) and `responder_alert_screen.dart`'s `_callSender()` now dials `session.triggeredByPhoneNumberE164` via a new testable `sosDialUri()` seam

## Task Commits

Each task was committed atomically:

1. **Task 1: Optional phone number on User + PATCH /me/phone-number** - `6cc54b6` (feat)
2. **Task 2: Recipient-scoped sender phone number on SosSessionDto** - `175ca5a` (feat)
3. **Task 3: Mobile phone-number field and a Call sender button that dials the real number** - `d570434` (feat)

**Plan metadata:** _(committed separately by the orchestrator)_

_Note: Each task followed RED (failing test / compile error) -> GREEN (implementation) within its own commit, per plan's `tdd="true"` requirement; RED state was verified via `dotnet test`/IDE diagnostics before implementing, then squashed into the single feat commit per task rather than separate test/feat commits, matching this repo's existing quick-task commit granularity._

## Files Created/Modified

**Backend:**
- `backend/src/SafePath.Domain/Entities/User.cs` - nullable `PhoneNumberE164` property
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/UserConfiguration.cs` - `HasMaxLength(20)`
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260807171030_AddUserPhoneNumber.*` - applied migration
- `backend/src/SafePath.Application/Profile/UpdatePhoneNumberCommand.cs` - new command + handler
- `backend/src/SafePath.Application/Profile/ProfileProjection.cs` - `FromUser` now projects the number
- `backend/src/SafePath.Application/Families/GetMeQuery.cs` - `GetMeResult.PhoneNumberE164`
- `backend/src/SafePath.Application/DependencyInjection.cs` - handler registration
- `backend/src/SafePath.Api/Controllers/MeController.cs` - `PATCH /me/phone-number` action, response field
- `backend/src/SafePath.Application/Sos/SosDtos.cs` - `SosSessionDto.TriggeredByPhoneNumberE164`
- `backend/src/SafePath.Application/Sos/SosSessionProjection.cs` - `ProjectAsync(callerUserId)` + `ProjectForRecipientAudienceAsync`
- `backend/src/SafePath.Application/Sos/{TriggerSosCommand,AcknowledgeSosCommand,CancelSosCommand,GetSosSessionQuery,SosAlertDispatcher}.cs` - the six call sites
- `backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs` - 5 new tests
- `backend/tests/SafePath.Application.Tests/Sos/SosSenderPhoneVisibilityTests.cs` - new, 5 tests
- `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` - 1 new test

**Mobile:**
- `mobile/lib/features/profile/data/user_profile.dart` - `phoneNumberE164` field
- `mobile/lib/features/profile/data/profile_api.dart` - `updatePhoneNumber` on `ProfileApi`/`DioProfileApi`
- `mobile/lib/features/profile/application/profile_controller.dart` - `updatePhoneNumber` mutator
- `mobile/lib/features/profile/presentation/profile_screen.dart` - `_PhoneNumberCard`, `_savePhoneNumber`
- `mobile/lib/features/sos/data/sos_models.dart` - `SosSession.triggeredByPhoneNumberE164`
- `mobile/lib/features/sos/presentation/responder_alert_screen.dart` - `sosDialUri()`, wired `_callSender`
- `mobile/test/helpers/fake_profile_api.dart` - `updatePhoneNumber` implementation
- `mobile/test/features/profile/profile_controller_test.dart` - `_FakeProfileApi.updatePhoneNumber` implementation
- `mobile/test/features/profile/profile_phone_number_test.dart` - new, 3 tests
- `mobile/test/features/sos/sos_call_sender_test.dart` - new, 6 tests

## Decisions Made
- The two-entry-point `SosSessionProjection` design (required-`callerUserId` general path vs. one doc-locked broadcast-only path) makes an un-updated call site a **compile error**, not a silent blanket-visibility bug — verified by `dotnet build` succeeding only after all six sites were updated.
- `UpdatePhoneNumberCommandHandler` deliberately skips `ProfileUpdatedAt`/`BroadcastUpdatedAsync`, unlike the display-name handler, since the number is invisible to family members and stamping would needlessly bust cached avatars.
- Mobile phone-number save treats an empty field as a valid "remove" submission (unlike display name's "enter one first" guard), matching the backend's blank-clears-to-null semantics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Killed stale locked `dotnet run` dev-server processes blocking every build**
- **Found during:** Task 1 and Task 2, before each `dotnet build`
- **Issue:** A leftover `dotnet run --launch-profile http --project src/SafePath.Api` process (orphaned under `nohup`) held file locks on `SafePath.Api.exe`'s referenced assemblies, causing `MSB3027`/`MSB3021` copy failures on every build attempt. It also respawned once between Task 1 and Task 2's builds.
- **Fix:** Identified the process chain via `Get-CimInstance Win32_Process` (parent PID -> `dotnet run` -> `SafePath.Api.exe`) and stopped it with `Stop-Process -Force` before each affected build.
- **Files modified:** None (process management only).
- **Verification:** `dotnet build SafePath.sln` succeeded cleanly immediately after.

### Not Fixed (documented only)

**2. [Out of scope] Pre-existing failing test unrelated to this task**
- **Found during:** Task 3's full `flutter test` run.
- **Issue:** `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`'s two tests fail with "A SemanticsHandle was active at the end of the test." Reproduces in isolation; neither the test file nor `member_map_pin.dart` were touched by this task (last modified in unrelated commits `555a22f`/`7246356`).
- **Action:** Logged to `.planning/quick/260807-rk2-wire-the-sos-responder-screen-s-call-sen/deferred-items.md`, not fixed (out of scope per the executor's scope boundary).

### Verification-gate note (not a code deviation)

**3. Task 2's literal negative-grep gate has one unavoidable, expected match**
- The plan's Task 2 verify command (`grep -rn 'PhoneNumber' backend/src/SafePath.Application/Families backend/src/SafePath.Application/Location | ... | wc -l -eq 0`) matches exactly one non-comment line: `GetMeResult.PhoneNumberE164` in `Families/GetMeQuery.cs`. That file/member is Task 1's own explicit requirement (the `/me` door the plan's `security_frame` and `must_haves` truths both explicitly declare legitimate: "it reaches clients through exactly two doors, `/me` for the owner and a recipient-scoped SOS session payload"). `GetMeQuery.cs` happens to live inside the `Families` folder even though `/me` is not a family-member-list DTO.
- Verified the substantive T-RK2-04 intent directly: zero matches in `Families` excluding `GetMeQuery.cs`, and zero matches anywhere in `Location`. No family-member-list DTO or location DTO carries the phone number.

---

**Total deviations:** 1 auto-fixed (Rule 3, environment), 1 out-of-scope item logged, 1 verification-gate note.
**Impact on plan:** No scope creep; all substantive security/correctness intents (T-RK2-01 through T-RK2-08) verified.

## Issues Encountered
See "Deviations from Plan" above (stale dev-server process locks; pre-existing unrelated test failure; expected grep-gate false positive).

## User Setup Required
None - no external service configuration required. The migration was applied directly to the live Supabase database as part of Task 1 (`dotnet ef database update`).

## Next Phase Readiness
- The 03-04 Known Stub ("Call sender opens a blank OS dialler") referenced in `STATE.md` is now closed.
- `SosSessionProjection`'s required-`callerUserId` pattern is now the template any future SOS payload field with a similar visibility rule should follow.
- Twilio SMS provisioning and the 03-07 airplane-mode smoke test remain the only outstanding pre-existing blockers (unrelated to this task).

---
*Phase: quick-260807-rk2*
*Completed: 2026-08-07*
