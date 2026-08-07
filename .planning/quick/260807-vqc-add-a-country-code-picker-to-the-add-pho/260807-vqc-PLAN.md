---
type: quick
phase: quick-260807-vqc
plan: 01
wave: 1
depends_on: []
slug: 260807-vqc-add-a-country-code-picker-to-the-add-pho
title: Add a searchable country-code picker to the profile phone-number field and send a full E.164 number for any country
autonomous: true
files_modified:
  - mobile/pubspec.yaml
  - mobile/pubspec.lock
  - mobile/lib/core/phone/phone_country.dart
  - mobile/lib/core/phone/country_picker_adapter.dart
  - mobile/lib/shared_widgets/phone_number_field.dart
  - mobile/lib/features/profile/presentation/profile_screen.dart
  - mobile/test/core/phone/phone_country_test.dart
  - mobile/test/features/profile/profile_phone_number_test.dart
  - backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs
requirements: [QUICK-VQC-COUNTRY-PICKER, QUICK-VQC-E164-COMPOSE, QUICK-VQC-RESTORE-COUNTRY, QUICK-VQC-BACKEND-MULTICOUNTRY]

must_haves:
  truths:
    - A user opens the profile phone-number card, taps the country button, searches a country list by name or dial code, picks Egypt, types their national number, and saves — the value that reaches PATCH /me/phone-number is the full E.164 number for Egypt (+20...), not a US-assumed one.
    - Reopening the profile screen with a saved number restores both parts — the country button shows that number's own country and dial code, and the text field shows only the national remainder.
    - Restoring a saved number and saving it again with no edits sends back a byte-identical E.164 string — a round trip can never silently rewrite a stored number.
    - Clearing the field and saving still removes the number, whatever country happens to be selected — the field stays genuinely optional and removable exactly as quick task 260807-rk2 built it.
    - PATCH /me/phone-number accepts and stores, unchanged, a valid E.164 number from any country, regardless of what Sms:DefaultRegion is (or is not) configured to — proven by test, not by assumption.
    - A user who pastes a complete international number (leading +) into the national field is not double-prefixed with the selected dial code.
    - The only file in the mobile app that imports the third-party picker package is the adapter — the phone model, the composition rules and every unit test run without it.
  artifacts:
    - mobile/lib/core/phone/phone_country.dart (PhoneCountry value type + the pure compose/split/resolve functions, package-free and directly unit-testable)
    - mobile/lib/core/phone/country_picker_adapter.dart (the single seam onto the third-party picker — phoneCountriesProvider + phoneCountryPickerProvider, both overridable in tests)
    - mobile/lib/shared_widgets/phone_number_field.dart (country button + national-number field, keys phone-country-button and phone-number-field)
    - mobile/lib/features/profile/presentation/profile_screen.dart (_PhoneNumberCard seeds country + national parts from the saved E.164 and composes on save)
    - mobile/test/core/phone/phone_country_test.dart (compose/split/round-trip/default-country coverage against a fixture country list)
    - mobile/test/features/profile/profile_phone_number_test.dart (updated: restore, pick-a-different-country, compose-on-save, clear-on-save)
    - backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs (multi-country E.164 acceptance regression coverage)
  key_links:
    - The composed E.164 string is a convenience, never the authority. UpdatePhoneNumberCommandHandler still re-parses every submitted value through PhoneNumberNormalizer.ToE164 (libphonenumber-csharp) and persists only what libphonenumber returns, so a wrong client-side composition surfaces as a 400 the user can see rather than a corrupt stored number.
    - PhoneNumberUtil.Parse ignores its defaultRegion argument whenever the input already carries a leading '+'. That single library behaviour is why the existing "US" fallback in PhoneNumberNormalizer.DefaultRegionFallback does not need to change for this feature — and why Task 1's regression test is mandatory rather than cosmetic. If that assumption ever stops holding, Task 1 fails loudly instead of Egypt numbers silently 400-ing in production.
    - splitE164 -> PhoneNumberField -> composeE164 must be a lossless round trip for a value that was not edited. The tie-break when several countries share one dial code (+1 across the NANP, +7 across RU/KZ) is cosmetic only, because every tied country contributes the same digits to the composed value — which is exactly what the round-trip test pins down.
    - The TextField key phone-number-field is a contract with the existing widget tests from 260807-rk2 and must survive the refactor into shared_widgets/phone_number_field.dart, even though the field now holds only the national portion.
---

<!-- planner-discipline-allow: country_picker -->

<objective>
Today the profile phone-number card is a single bare text field. A user who types a local
Egyptian number gets it silently interpreted as a US number by the backend's default region and
rejected, and a user who wants their real country has to know and hand-type the international
prefix. Replace that field with a country button plus a national-number field: pick your country
from a searchable list, type your number, and the app composes the full E.164 value before it
ever reaches the API.

Purpose: the number set here is the number a guardian dials from the SOS responder screen
(quick task 260807-rk2). A number stored under the wrong country code is a call that does not
connect during an emergency — the exact failure the Call-sender button exists to remove.

Output: a package-free phone model with tested composition rules, one thin adapter onto a
maintained country-list package, a reusable field widget, the profile card wired to it, and a
backend regression test proving multi-country E.164 was already accepted (and stays accepted).

Explicit non-goals: the emergency-contacts screen keeps its own phone entry untouched; no change
to how the number is exposed on SOS payloads (rk2's recipient scoping stands); no new request
field on PATCH /me/phone-number — the wire contract stays `{ "phoneNumber": "<E.164>" }`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@.planning/quick/260807-rk2-wire-the-sos-responder-screen-s-call-sen/260807-rk2-SUMMARY.md
</context>

<investigation_findings>
Read before planning, so the executor does not need to rediscover it:

- The phone-number feature was built by quick task **260807-rk2** (commits `6cc54b6`, `175ca5a`,
  `d570434`), not by plan 03-06 (which is FCM push). The planning brief's "phase 03-06" pointer
  is stale — every file below was located by reading those three commits.
- **Mobile entry UI:** `mobile/lib/features/profile/presentation/profile_screen.dart` →
  `_PhoneNumberCard`, a bare `TextField` keyed `phone-number-field`, seeded once from
  `profile.phoneNumberE164` via the `_phoneSeeded` latch in `_ProfileScreenState.build`, saved by
  `_savePhoneNumber` which sends the trimmed raw text and treats an empty submission as a
  deliberate "remove my number".
- **Wire path:** `ProfileController.updatePhoneNumber(String?)` →
  `DioProfileApi.updatePhoneNumber` → `PATCH /me/phone-number` with body
  `{'phoneNumber': <text>}` → response parsed by `UserProfile.fromJson` (`phoneNumberE164`).
- **Backend validation:** `MeController.UpdatePhoneNumber` →
  `UpdatePhoneNumberCommand(CallerUserId, PhoneNumber, Region = null)` →
  `PhoneNumberNormalizer.ToE164(input, region)` where `region = command.Region ??
  configuration["Sms:DefaultRegion"]`, falling back to `DefaultRegionFallback = "US"`.
  `ToE164` delegates to `libphonenumber-csharp`'s `PhoneNumberUtil.Parse` + `IsValidNumber` +
  `Format(E164)`.
- **Therefore the backend needs no production change.** `PhoneNumberUtil.Parse` ignores its
  default-region argument when the input already starts with `+`, so a client that submits a
  complete E.164 number is validated against that number's own country. What the backend *does*
  lack is any proof of this: every existing phone test in `ProfileCommandTests.cs` uses the same
  US number `(202) 555-0173` with region `"US"`. Task 1 closes that gap, because the whole mobile
  design in Tasks 2-3 rests on this behaviour.
- **No country/phone package is present** in `mobile/pubspec.yaml`. `country_picker` was
  evaluated during planning against pub.dev: **2.0.28**, MIT, 464 likes, 160/160 pub points,
  ~114k downloads, pure Dart (no native code, no platform channels), depends only on
  `collection` / `flutter` / `universal_io`. It is the dependency this plan adds, pinned exactly.
</investigation_findings>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Prove PATCH /me/phone-number already accepts E.164 from any country</name>
  <files>backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs</files>
  <read_first>
    - backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs (the five phone tests added by 260807-rk2 around line 128: the `SqliteInMemoryDbContextFactory` + `CreateUser(userId)` seeding convention, and the `UpdatePhoneNumberCommandHandler(db)` construction with no `IConfiguration`)
    - backend/src/SafePath.Application/Profile/UpdatePhoneNumberCommand.cs (the `command.Region ?? _configuration?["Sms:DefaultRegion"]` resolution)
    - backend/src/SafePath.Application/Sos/PhoneNumberNormalizer.cs (`DefaultRegionFallback`, and that `Parse` is given the resolved region)
  </read_first>
  <behavior>
    - `UpdatePhoneNumber_AcceptsE164FromAnyCountryWithNoRegionHint`: a `[Theory]` over at least four real, valid international numbers — one Egyptian (+20), one British (+44), one Japanese (+81) and one Brazilian (+55) — submitted with `Region = null` and no `IConfiguration`, each stored and returned byte-identical to the submitted string.
    - `UpdatePhoneNumber_AcceptsE164WhenTheConfiguredDefaultRegionDisagrees`: the same Egyptian number submitted while an `IConfiguration` supplies a `Sms:DefaultRegion` of a different country is still stored as the Egyptian E.164 — proving the leading `+` wins over the configured region.
    - `UpdatePhoneNumber_RejectsAnE164NumberThatIsInvalidForItsOwnCountryCode`: a `+`-prefixed value with a valid country code but a nonsense subscriber part throws `ArgumentException` and leaves the stored column untouched — the client-side composition is convenience, never authority.
  </behavior>
  <action>
Add the three behaviours above to the existing `ProfileCommandTests` class, following its
established shape exactly: `await using var db = _factory.CreateContext();`, seed with
`CreateUser(userId)`, save, construct `new UpdatePhoneNumberCommandHandler(db)`, call
`Handle(new UpdatePhoneNumberCommand(...))`, then assert against
`db.Users.Single(u => u.Id == userId)` and the returned result.

For the configuration case, pass a real `IConfiguration` built with
`new ConfigurationBuilder().AddInMemoryCollection(...)` supplying a `Sms:DefaultRegion` value
that is deliberately *not* the country of the number under test, and hand it to the handler's
second constructor parameter.

Choose the theory numbers from `libphonenumber`'s own valid ranges rather than inventing digits —
a number that fails `IsValidNumber` would make this test assert the opposite of its intent.
Verify each candidate is accepted before committing; if one is rejected, replace it with a valid
number for that country rather than weakening the assertion to a prefix check.

Assert equality against the exact submitted string (`Assert.Equal(submitted, user.PhoneNumberE164)`),
not merely that it starts with `+` — an assertion that only checks the prefix would pass even if
the normaliser silently rewrote the country code, which is precisely the failure this test exists
to catch.

Make no production-code change in this task. The finding recorded in
`<investigation_findings>` is that the handler is already correct; this task converts that
finding from an assumption into a regression guard that Tasks 2-3 can build on.
  </action>
  <verify>
    <automated>dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Profile.ProfileCommandTests</automated>
  </verify>
  <acceptance_criteria>
    - `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Profile.ProfileCommandTests` is green, with the theory's country cases visible as separate passing cases in the output.
    - `grep -c 'AcceptsE164FromAnyCountryWithNoRegionHint' backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs` returns 1.
    - `grep -c 'Sms:DefaultRegion' backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs` returns at least 1.
    - `git diff --name-only backend/src` is empty for this task's commit — the backend production tree is untouched.
    - `dotnet test backend/tests/SafePath.Application.Tests` (full suite) is green.
  </acceptance_criteria>
  <done>Four countries' E.164 numbers are proven to survive PATCH /me/phone-number byte-identical with no region hint and with a disagreeing configured default region, and an E.164 number that is invalid for its own country code is proven to be rejected rather than stored.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Package-free phone model, the picker seam, and the reusable field widget</name>
  <files>mobile/pubspec.yaml, mobile/lib/core/phone/phone_country.dart, mobile/lib/core/phone/country_picker_adapter.dart, mobile/lib/shared_widgets/phone_number_field.dart, mobile/test/core/phone/phone_country_test.dart</files>
  <read_first>
    - mobile/lib/core/deep_link/deep_link_service.dart (the `Provider` + injectable-seam convention this codebase uses instead of static singletons, and the Notifier/`set()` style noted for Riverpod 3.3.2)
    - mobile/lib/shared_widgets/profile_avatar.dart (the shared_widgets file shape: a small presentational widget with named required params and design-token imports only)
    - mobile/lib/core/theme/app_colors.dart, app_spacing.dart, app_typography.dart (the exact token names available — use only tokens that already exist; the emergency red token is reserved for SOS surfaces and must not appear on this control)
    - mobile/lib/features/profile/presentation/profile_screen.dart (`_PhoneNumberCard` as it stands: the card copy, the `phone-number-field` key, `keyboardType: TextInputType.phone`, `onSubmitted`)
    - The resolved package source of the picker dependency after `flutter pub get` (its `lib/src/country.dart` and `lib/src/country_service.dart` under the pub cache) — confirm the real field and method names before writing the adapter. This project has been burned by assuming a package API before (Phase 01-09 verified `google_sign_in` 7.2.0 from source for exactly this reason).
  </read_first>
  <behavior>
    - `composeE164` joins the selected dial code and the typed national digits into `+<dial><national>`, discarding spaces, dashes and parentheses.
    - `composeE164` removes a single leading trunk zero from the national part, so an Egyptian user typing `01001234567` with Egypt selected yields `+201001234567`.
    - `composeE164` passes a `+`-prefixed input straight through (digits kept, separators dropped) instead of prefixing the selected dial code again, so pasting a complete international number cannot double-prefix.
    - `composeE164` returns an empty string for blank input, and for input whose only digit was the stripped trunk zero — the clear-my-number path from 260807-rk2 survives whatever country is selected.
    - `splitE164` splits a stored value on the longest matching dial code in the supplied country list: `+201001234567` yields Egypt and `1001234567`; `+447700900123` yields the United Kingdom and `7700900123`.
    - `splitE164` returns null for a value with no leading `+`, for a value with no matching dial code, and for a non-digit body — the caller falls back to the default country and an empty field instead of throwing.
    - Round trip: for `+201001234567`, `+12025550173`, `+447700900123` and `+819012345678`, `composeE164` applied to the output of `splitE164` reproduces the original string exactly.
    - `defaultPhoneCountry` resolves the device locale's country code when it matches a country in the list, and falls back to `US` otherwise — matching the backend's own `DefaultRegionFallback` so client and server agree on the unset case.
  </behavior>
  <action>
Add the country-list dependency to `mobile/pubspec.yaml` pinned to an exact version
(`country_picker: 2.0.28`, not a caret range) alongside the other pinned entries such as
`geolocator` and `maplibre_gl`, run `flutter pub get`, and commit the updated `pubspec.lock`.
Legitimacy evidence recorded during planning: MIT licence, 464 likes, 160/160 pub points, ~114k
downloads, pure Dart with no native code and only `collection` / `flutter` / `universal_io` as
dependencies.

Create `mobile/lib/core/phone/phone_country.dart` holding a small immutable `PhoneCountry` value
type (`isoCode`, `dialCode`, `displayName`, `flagEmoji`, plus value equality) and four top-level
pure functions: `composeE164`, `splitE164`, `resolvePhoneCountry` and `defaultPhoneCountry`.
Every function takes the country list as a parameter rather than reaching for a global, so the
unit tests drive them with a five-country fixture. This file must depend only on Dart core — no
Flutter widgets and nothing from the third-party picker — because it is the piece the tests and
the composition rules rest on.

`splitE164` performs a longest-dial-code-prefix match. When several countries share the winning
dial code (the whole NANP shares `1`; `7` covers Russia and Kazakhstan; `44` covers the UK and
the Crown dependencies), resolve the tie through a small explicit preference map keyed by dial
code, falling back to the first match in list order. Document in a header comment that this
tie-break is cosmetic only: every tied country contributes identical digits to the composed
value, so an imperfect flag can never change what is stored — which is the invariant the
round-trip test pins down.

Create `mobile/lib/core/phone/country_picker_adapter.dart` as the one and only file that imports
the third-party picker. It exposes exactly two Riverpod `Provider`s so widget tests can override
them without any package UI: one yielding the full `List<PhoneCountry>` mapped from the
package's country service, and one yielding a `PhoneCountryPicker` typedef
(`Future<PhoneCountry?> Function(BuildContext)`) whose real implementation calls the package's
bottom-sheet picker with the phone-code column and the search box enabled, mapping the selection
back into `PhoneCountry`. Confirm the package's actual class fields and service method names from
its resolved source first; if a field you expected is absent, adapt the mapping rather than
inventing an alias.

Create `mobile/lib/shared_widgets/phone_number_field.dart`: a `ConsumerWidget` that reads both
providers and renders a `Row` of a tappable country button (key `phone-country-button`, showing
the flag glyph, the `+`-prefixed dial code and a dropdown affordance) and the national-number
`TextField` (key `phone-number-field`, `keyboardType: TextInputType.phone`, `onSubmitted`
forwarded). It takes `country`, `controller`, `onCountryChanged` and `onSubmitted` as named
parameters and owns no state of its own — the parent holds the selected country, which keeps the
widget trivially testable and lets the profile screen seed both halves together. Tapping the
button awaits the injected picker and, on a non-null result, invokes `onCountryChanged`. Style it
with existing design tokens only (card-consistent hairline border, radius and spacing); the
reserved emergency colour has no place on a profile control. Give the country button a
`Semantics` label naming the selected country and dial code, following the precedent set for
`MemberMapPin`, so a screen reader does not announce a bare flag glyph.

Write `mobile/test/core/phone/phone_country_test.dart` covering the eight behaviours above
against a fixture list of five countries (Egypt, United States, Canada, United Kingdom, Japan) —
no package import, no `WidgetTester`, plain `test()` bodies.
  </action>
  <verify>
    <automated>cd mobile &amp;&amp; flutter test test/core/phone/phone_country_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `cd mobile && flutter test test/core/phone/phone_country_test.dart` passes with at least 8 tests.
    - `cd mobile && flutter analyze` reports no new issues.
    - `grep -c 'country_picker: 2.0.28' mobile/pubspec.yaml` returns 1.
    - `grep -c 'country_picker' mobile/lib/core/phone/country_picker_adapter.dart` returns at least 1.
    - `grep -v '^ *//' mobile/lib/core/phone/phone_country.dart | grep -c 'country_picker'` returns 0 — the model and its rules stay package-free.
    - `grep -v '^ *//' mobile/lib/core/phone/phone_country.dart | grep -c "package:flutter"` returns 0 — pure Dart, no widget dependency.
    - `grep -c 'phone-country-button' mobile/lib/shared_widgets/phone_number_field.dart` returns 1.
    - `grep -c 'phone-number-field' mobile/lib/shared_widgets/phone_number_field.dart` returns 1.
  </acceptance_criteria>
  <done>The composition rules are proven by unit tests with no package or widget dependency, the third-party picker is reachable only through two overridable providers in a single adapter file, and a reusable field widget renders a country button beside the national-number field.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Wire the picker into the profile phone card and update its widget tests</name>
  <files>mobile/lib/features/profile/presentation/profile_screen.dart, mobile/test/features/profile/profile_phone_number_test.dart</files>
  <read_first>
    - mobile/lib/features/profile/presentation/profile_screen.dart (read in full: the `_nameSeeded`/`_phoneSeeded` latches in `build`, `_savePhoneNumber`'s empty-is-a-removal contract and its snackbar copy, and `_PhoneNumberCard`'s current layout and caption)
    - mobile/test/features/profile/profile_phone_number_test.dart (read in full: `_FixedAuthController`, `_wrap`, the 800x1600 `_pumpScreen` convention, and the three assertions that must be rewritten rather than deleted)
    - mobile/test/helpers/fake_profile_api.dart (`updatePhoneNumberCallCount` and `lastPhoneNumber` — the assertions this task's tests read; the API signature itself does not change)
    - mobile/lib/features/profile/application/profile_controller.dart (`updatePhoneNumber` — unchanged by this task; the composed string is what it receives)
  </read_first>
  <behavior>
    - "restores the saved country and national number": a profile carrying `+201001234567` renders `+20` on the country button and `1001234567` in the text field.
    - "re-saving a restored number without editing sends the identical E.164 string": pumping that screen and tapping save records one call carrying exactly `+201001234567`.
    - "picking a different country recomposes the saved value": with the picker provider overridden to return the United Kingdom, tapping the country button then saving a typed national number records `+44...` — the previously selected country's dial code does not leak into the result.
    - "an unset number falls back to the default country and an empty field": a profile with no stored number renders an empty field and a country button showing the fallback dial code, and no exception is thrown.
    - "saving an empty field still clears the number regardless of selected country": one call with a value the backend treats as a clear, and the screen reports removal rather than an error (the preserved 260807-rk2 contract).
    - "a ProfileApiException message still surfaces into state.error": the existing controller-level test continues to pass unchanged.
  </behavior>
  <action>
Replace `_PhoneNumberCard`'s bare `TextField` with the `PhoneNumberField` widget from Task 2,
keeping the card's title and its caption about who can call this number intact — the visible copy
and the card chrome do not change, only the control inside it.

In `_ProfileScreenState`, add a nullable selected-country field beside the existing controllers.
Extend the one-shot `_phoneSeeded` latch so that when the profile first loads it runs the stored
value through `splitE164`: on a match, seed the country and put only the national remainder in
`_phoneController`; on a null result (no stored number, or an unparseable one), seed
`defaultPhoneCountry` from the device locale and leave the field empty. Keep the latch one-shot —
re-seeding on every rebuild would fight the user's typing.

In `_savePhoneNumber`, compose the value with `composeE164(selectedCountry.dialCode,
_phoneController.text)` and pass the result to `ProfileController.updatePhoneNumber`. Preserve
the existing behaviour exactly on both ends: an empty composition is still a deliberate removal
that reports "Phone number removed.", and a backend error still surfaces through the controller's
`state.error` into the snackbar. The API signature, the request body shape and the controller are
untouched by this task.

Pass `onCountryChanged` a `setState` that swaps the selected country without touching the typed
digits, so switching country recomposes rather than clears — a user correcting a mis-detected
country should not have to retype their number.

Rewrite `profile_phone_number_test.dart` for the new structure, overriding both providers from
Task 2's adapter (a fixture country list, and a picker returning a scripted country) alongside
the existing `profileApiProvider` and `authControllerProvider` overrides. The first existing test
asserted the text field held the whole `+1...` string; that expectation is now wrong by design —
rewrite it to assert the split across the button and the field rather than deleting it. Keep the
existing empty-save and controller-error tests passing.
  </action>
  <verify>
    <automated>cd mobile &amp;&amp; flutter test test/features/profile/profile_phone_number_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `cd mobile && flutter test test/features/profile/profile_phone_number_test.dart` passes with at least 6 tests.
    - `cd mobile && flutter test` (full suite) is green — no other screen or test regressed.
    - `cd mobile && flutter analyze` reports no new issues.
    - `grep -c 'PhoneNumberField' mobile/lib/features/profile/presentation/profile_screen.dart` returns at least 1.
    - `grep -c 'composeE164' mobile/lib/features/profile/presentation/profile_screen.dart` returns at least 1.
    - `grep -c 'splitE164' mobile/lib/features/profile/presentation/profile_screen.dart` returns at least 1.
    - `grep -c 'Phone number removed.' mobile/lib/features/profile/presentation/profile_screen.dart` returns 1 — the removal contract from 260807-rk2 is intact.
    - `git diff --stat mobile/lib/features/profile/data/profile_api.dart mobile/lib/features/profile/application/profile_controller.dart` is empty — the wire contract and controller did not change.
  </acceptance_criteria>
  <done>The profile phone card shows a country button beside a national-number field, seeds both halves from the stored E.164 value, recomposes correctly when the country is switched, sends the full E.164 number for the chosen country, and still clears the number on an empty save.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| device → `PATCH /me/phone-number` | Pre-existing boundary from 260807-rk2. This change alters what the client composes before crossing it; it adds no new field and no new endpoint. |
| build → pub.dev | A new third-party dependency enters the mobile build. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-VQC-01 | Tampering | client-composed E.164 value | medium | mitigate | The composition is a convenience only. `UpdatePhoneNumberCommandHandler` still re-parses every submitted value through `PhoneNumberNormalizer.ToE164` and persists only libphonenumber's own output, so a malformed or hostile composition is rejected with a 400 rather than stored. Task 1's third behaviour asserts this directly. |
| T-VQC-02 | Tampering | new pub dependency in the mobile build | high | mitigate | Pinned to an exact version rather than a caret range, `pubspec.lock` committed, pure Dart with no native code or platform channels, and reachable from exactly one adapter file so its blast radius is auditable by a single grep. Legitimacy evidence (MIT, 464 likes, 160/160 pub points, ~114k downloads, three transitive deps) recorded in `<investigation_findings>`. |
| T-VQC-03 | Information Disclosure | country selection state | low | accept | The selected country is derived from a number the user already stored and is never transmitted separately — no new data crosses any boundary. The device-locale fallback for an unset number stays entirely on-device. |
| T-VQC-04 | Denial of Service | a number stored under the wrong country code | medium | mitigate | This is the failure the feature exists to remove: a wrong country code produces a dial that never connects during an SOS. Mitigated by the round-trip invariant test (a restored number re-saves byte-identical) plus the backend's independent re-validation, so neither the split nor the compose step can quietly rewrite a stored number. |
</threat_model>

<verification>
1. `dotnet test backend/tests/SafePath.Application.Tests` — green, including the new multi-country theory.
2. `cd mobile && flutter analyze && flutter test` — clean and green.
3. Manual smoke on a device or emulator: open Profile, tap the country button, search "Egypt",
   select it, type a local Egyptian number, save, then pull-to-refresh and confirm the field
   comes back showing the Egyptian flag/dial code with the national digits — and that the same
   check works for a `+1` number.
</verification>

<success_criteria>
- A user can choose their own country from a searchable list instead of being assumed into one.
- The value sent to `PATCH /me/phone-number` is a full E.164 number for the selected country.
- A saved number restores into the correct country button and national field, and re-saving it
  untouched produces the identical string.
- Clearing the field still removes the number, and backend errors still surface in the snackbar.
- The backend is proven, not assumed, to accept E.164 from any country.
</success_criteria>

<output>
Create `.planning/quick/260807-vqc-add-a-country-code-picker-to-the-add-pho/260807-vqc-SUMMARY.md` when done.
</output>
