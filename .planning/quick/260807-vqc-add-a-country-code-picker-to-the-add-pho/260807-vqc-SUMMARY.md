---
phase: quick-260807-vqc
plan: 01
subsystem: profile
tags: [flutter, riverpod, country_picker, libphonenumber, e164, phone-number, profile]

# Dependency graph
requires:
  - phase: quick-260807-rk2
    provides: User.PhoneNumberE164 column, PATCH /me/phone-number, the bare phone-number TextField this task replaces
provides:
  - A package-free PhoneCountry model with pure composeE164/splitE164/resolvePhoneCountry/defaultPhoneCountry composition rules
  - country_picker_adapter.dart, the single seam onto the third-party country_picker package
  - PhoneNumberField shared widget (country button + national-number field)
  - Backend regression proof that PATCH /me/phone-number already accepts E.164 from any country
affects: [future phases touching the profile phone-number card or the SOS Call-sender number]

# Tech tracking
tech-stack:
  added:
    - "country_picker 2.0.28 (pinned exact, MIT, pure Dart, no native code)"
  patterns:
    - "Package-free model + single-adapter seam: phone_country.dart has zero Flutter/package imports and is unit-tested directly; country_picker_adapter.dart is the only file importing the third-party package, exposed as two overridable Riverpod Providers"
    - "Parent-owned selection state: PhoneNumberField takes country/controller/onCountryChanged as params and owns no state itself, so the profile screen can seed both halves of a restored E.164 number together in one seed latch"

key-files:
  created:
    - mobile/lib/core/phone/phone_country.dart
    - mobile/lib/core/phone/country_picker_adapter.dart
    - mobile/lib/shared_widgets/phone_number_field.dart
    - mobile/test/core/phone/phone_country_test.dart
  modified:
    - mobile/pubspec.yaml
    - mobile/pubspec.lock
    - mobile/lib/features/profile/presentation/profile_screen.dart
    - mobile/test/features/profile/profile_phone_number_test.dart
    - backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs

key-decisions:
  - "country_picker pinned to the exact version 2.0.28 (not a caret range), pubspec.lock committed -- pure Dart, no native code, MIT, 464 likes/160 pub points/~114k downloads recorded during planning."
  - "PhoneCountry model and its compose/split/resolve/default functions live in phone_country.dart with zero Flutter or country_picker imports, verified by grep gates, so the composition rules stay unit-testable with plain test() bodies and no widget harness."
  - "splitE164's tie-break for a shared dial code (NANP's '1', '7' for RU/KZ, '44' for GB) is a small explicit preference map (1->US, 7->RU, 44->GB), falling back to first-in-list -- cosmetic only, since every tied country contributes identical digits to the composed value."
  - "composeE164 passes a +-prefixed national input straight through (digits kept, separators dropped) instead of re-prefixing the selected dial code, so pasting a complete international number can never be double-prefixed."
  - "Backend needed no production change: PhoneNumberUtil.Parse ignores its defaultRegion argument whenever input already carries a leading '+', confirmed and pinned down as a regression guard in Task 1 rather than assumed."

requirements-completed: [QUICK-VQC-COUNTRY-PICKER, QUICK-VQC-E164-COMPOSE, QUICK-VQC-RESTORE-COUNTRY, QUICK-VQC-BACKEND-MULTICOUNTRY]

coverage:
  - id: D1
    description: "PATCH /me/phone-number accepts E.164 from any country with no region hint, still accepts it when a configured Sms:DefaultRegion disagrees, and rejects an E.164 value with a valid country code but a nonsense subscriber part -- proven by test, not assumption"
    requirement: "QUICK-VQC-BACKEND-MULTICOUNTRY"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_AcceptsE164FromAnyCountryWithNoRegionHint (theory: EG/GB/JP/BR)"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_AcceptsE164WhenTheConfiguredDefaultRegionDisagrees"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#UpdatePhoneNumber_RejectsAnE164NumberThatIsInvalidForItsOwnCountryCode"
        status: pass
      - kind: other
        ref: "git diff --name-only backend/src is empty for this task's commit"
        status: pass
    human_judgment: false
  - id: D2
    description: "Package-free composition rules (compose/split/resolve/default) proven correct against a five-country fixture, including trunk-zero stripping, +-prefixed passthrough, longest-dial-code-prefix matching, and a lossless round trip for four countries"
    requirement: "QUICK-VQC-E164-COMPOSE"
    verification:
      - kind: unit
        ref: "mobile/test/core/phone/phone_country_test.dart (19 tests: composeE164 x6, splitE164 x6, round trip x4, defaultPhoneCountry x3)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The profile phone card renders a country button beside the national-number field, seeds both halves from the stored E.164 value on load, and lets the user search/pick a different country via the injected picker seam"
    requirement: "QUICK-VQC-COUNTRY-PICKER"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#restores the saved country and national number"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#picking a different country recomposes the saved value"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#an unset number falls back to the default country and an empty field"
        status: pass
    human_judgment: false
  - id: D4
    description: "A restored number re-saves byte-identical, and clearing the field still removes the number regardless of selected country -- the round-trip and removal invariants both hold"
    requirement: "QUICK-VQC-RESTORE-COUNTRY"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#re-saving a restored number without editing sends the identical E.164 string"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#saving an empty field still clears the number regardless of selected country"
        status: pass
      - kind: unit
        ref: "mobile/test/features/profile/profile_phone_number_test.dart#ProfileController.updatePhoneNumber surfaces a ProfileApiException's message into state.error"
        status: pass
    human_judgment: false

duration: ~55min
completed: 2026-08-07
status: complete
---

# Quick-260807-vqc: Country-Code Picker for the Profile Phone Number Field Summary

**A package-free PhoneCountry model with tested E.164 composition rules, a single-file adapter onto `country_picker` 2.0.28, and a reusable field widget wired into the profile phone card so a user can pick their real country instead of being silently assumed into the US — backed by a new backend regression proving multi-country E.164 was already accepted.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3
- **Files modified:** 10 (1 backend, 9 mobile)

## Accomplishments
- Proved (not assumed) that `PATCH /me/phone-number` already accepts valid E.164 numbers from any country with no region hint, and even when a configured `Sms:DefaultRegion` disagrees with the submitted number's own country — three new regression tests, zero production changes.
- Built `phone_country.dart`: an immutable `PhoneCountry` value type plus four pure functions (`composeE164`, `splitE164`, `resolvePhoneCountry`, `defaultPhoneCountry`) with zero Flutter or third-party-package imports, covered by 19 unit tests against a five-country fixture (Egypt, US, Canada, UK, Japan) including a byte-identical round-trip invariant.
- Added `country_picker_adapter.dart` as the sole seam onto the `country_picker` package (pinned to exact version 2.0.28), exposing `phoneCountriesProvider` and `phoneCountryPickerProvider`, both overridable in tests.
- Replaced the profile phone card's bare `TextField` with `PhoneNumberField` (country button + national field), seeded from the stored E.164 value via `splitE164` and composed back via `composeE164` on save — the wire contract, `ProfileApi`, and `ProfileController` are byte-for-byte unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Prove PATCH /me/phone-number already accepts E.164 from any country** - `b768b88` (test)
2. **Task 2: Package-free phone model, the picker seam, and the reusable field widget** - `7f7e94b` (feat)
3. **Task 3: Wire the picker into the profile phone card and update its widget tests** - `15da58f` (feat)

## Files Created/Modified

**Backend:**
- `backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs` - 3 new tests (multi-country theory, disagreeing-config-region, invalid-for-own-country-code rejection)

**Mobile:**
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - `country_picker: 2.0.28` (pinned exact)
- `mobile/lib/core/phone/phone_country.dart` - new: `PhoneCountry` + `composeE164`/`splitE164`/`resolvePhoneCountry`/`defaultPhoneCountry`
- `mobile/lib/core/phone/country_picker_adapter.dart` - new: `phoneCountriesProvider`, `phoneCountryPickerProvider`
- `mobile/lib/shared_widgets/phone_number_field.dart` - new: `PhoneNumberField` (`phone-country-button` + `phone-number-field`)
- `mobile/lib/features/profile/presentation/profile_screen.dart` - `_PhoneNumberCard` now renders `PhoneNumberField`; seed latch runs `splitE164`/`defaultPhoneCountry`; save composes via `composeE164`
- `mobile/test/core/phone/phone_country_test.dart` - new, 19 tests
- `mobile/test/features/profile/profile_phone_number_test.dart` - rewritten, 6 tests (restore split, byte-identical re-save, country switch recomposition, unset fallback, empty-clears, controller-error)

## Decisions Made
- Verified the real `country_picker` 2.0.28 API from its resolved pub-cache source (`Country.phoneCode`/`countryCode`/`name`/`flagEmoji`, `CountryService().getAll()`, top-level `showCountryPicker(...)`) before writing the adapter, rather than assuming field names — this project has previously been burned by that shortcut (Phase 01-09, `google_sign_in`).
- Chose the four backend theory numbers (Egypt `+20234567890`, UK `+441212345678`, Japan `+81312345678`, Brazil `+551123456789`) and the invalid-number case (`+20000000000`) by probing `libphonenumber-csharp`'s own `GetExampleNumber`/`IsValidNumber` via a temporary throwaway test rather than inventing digits, per the plan's explicit instruction — the probe file was deleted before committing.
- `defaultPhoneCountry` takes an optional `localeCountryCode` parameter rather than reading `dart:ui`/device locale itself, keeping it pure and directly unit-testable; `profile_screen.dart` supplies `Localizations.localeOf(context).countryCode` at the one call site, mirroring `emergency_contacts_screen.dart`'s existing pattern for its own (untouched) phone entry.

## Deviations from Plan

### Not Fixed (documented only)

**1. [Out of scope, pre-existing] `member_map_pin_semantics_test.dart` — 2 failing tests, unrelated to this task**
- **Found during:** Task 3's full `flutter test` run.
- **Issue:** Both tests in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart` fail with "A SemanticsHandle was active at the end of the test."
- **Verified pre-existing:** Reproduces identically in isolation, and reproduces identically with this task's two Task-3 file changes (`profile_screen.dart`, `profile_phone_number_test.dart`) stashed out via `git stash` — confirmed not introduced by this task. This is the same pre-existing failure already logged in `260807-rk2-SUMMARY.md`'s "Deviations from Plan" section (neither `member_map_pin.dart` nor its semantics test were touched by that task either).
- **Action:** Not fixed — out of scope per this task's scope boundary ("Do NOT touch unrelated SOS/location code").

No other deviations. All three tasks matched their plan exactly.

## Verification Results
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Profile.ProfileCommandTests` — 24/24 pass.
- `dotnet test backend/tests/SafePath.Application.Tests` (full suite) — 184/184 pass.
- `git diff --name-only backend/src` — empty for Task 1's commit (production tree untouched).
- `cd mobile && flutter test test/core/phone/phone_country_test.dart` — 19/19 pass.
- `cd mobile && flutter test test/features/profile/profile_phone_number_test.dart` — 6/6 pass.
- `cd mobile && flutter analyze` — no issues found.
- `cd mobile && flutter test` (full suite) — 388/390 pass; the 2 failures are the pre-existing, unrelated `member_map_pin_semantics_test.dart` failures documented above.
- `git diff --stat mobile/lib/features/profile/data/profile_api.dart mobile/lib/features/profile/application/profile_controller.dart` — empty (wire contract and controller unchanged).

## User Setup Required
None. `country_picker` is a pure-Dart package with no native code, no platform channels, and no external service configuration.

## Next Phase Readiness
- The profile phone-number field now supports any country, closing the "silently assumed US" gap that could have produced a guardian call that never connects during an SOS.
- The `phone_country.dart` package-free model + `country_picker_adapter.dart` single-seam pattern is available as a template for any future phone-entry surface (e.g. if the emergency-contacts screen is ever migrated off its own bespoke `_CountryDialCode` implementation — explicitly out of scope for this task).
- The pre-existing `member_map_pin_semantics_test.dart` failure remains untracked as a dedicated todo (it was logged only in `260807-rk2-SUMMARY.md`'s prose, not `STATE.md`'s Pending Todos table) — worth promoting to a tracked todo in a future session.

---
*Phase: quick-260807-vqc*
*Completed: 2026-08-07*
