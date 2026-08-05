---
type: quick
slug: 260805-uke-add-a-proactive-zero-sos-recipient-nudge
title: Proactive zero-SOS-recipient nudge in the Privacy Center, plus a Guardian-role SOS access audit
autonomous: false
files_modified:
  - mobile/lib/features/sos/application/sos_reach_provider.dart
  - mobile/lib/features/sos/presentation/sos_reach_warning_card.dart
  - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
  - mobile/test/features/sos/sos_reach_provider_test.dart
  - mobile/test/features/privacy/privacy_center_screen_test.dart
requirements: [QUICK-SOS-ZERO-RECIPIENT-NUDGE, QUICK-SOS-GUARDIAN-ACCESS-AUDIT]
must_haves:
  truths:
    - A user whose SOS would currently reach nobody sees a warning on a settings surface BEFORE they ever press the button, not only after.
    - The warning's zero-recipient condition is exactly the client-side mirror of the backend's own recipient resolution - active Guardians in the family excluding self, plus the caller's own active emergency contacts - and nothing else.
    - The warning never fires while either data source is still loading or errored, so a slow network can never produce a false "nobody will be alerted" claim.
    - The SOS button is reachable and armable by a Guardian-role user exactly as it is by any other role - there is no role-based gate anywhere on the mobile SOS trigger surface, and a source-level gate keeps it that way.
    - Nothing on the SOS trigger/dispatch hot path is modified, and no new network call is introduced anywhere on that path.
    - The warning's wording is a distinct proactive settings-surface warning, not a copy of the locked reactive post-press empty state from 03-UI-SPEC.md.
  artifacts:
    - mobile/lib/features/sos/application/sos_reach_provider.dart (three-state SosReach computation)
    - mobile/lib/features/sos/presentation/sos_reach_warning_card.dart (self-hiding warning card)
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart (two render call sites)
    - mobile/test/features/sos/sos_reach_provider_test.dart (recipient-resolution parity + loading-safety unit tests)
    - .planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/screenshots/ (device capture evidence)
  key_links:
    - sosReachProvider reads familyControllerProvider and emergencyContactsControllerProvider only - both already loaded by the running app, so the nudge adds zero new backend endpoints.
    - The Guardian filter (role == Role.guardian, userId != current user) mirrors TriggerSosCommandHandler.ResolveRecipients; the active-contact filter mirrors ResolveEmergencyContacts.
    - No file on the SOS trigger path (sos_arm_button.dart, sos_controller.dart, main_shell.dart) imports the new provider - enforced by a negative grep gate.
---

<objective>
Warn a user, on a settings surface and ahead of any emergency, when their SOS would currently
reach nobody: no other active Guardian in their circle AND no emergency contacts configured.
Separately, audit and lock in that a Guardian-role family member can trigger SOS exactly like
any other role.

Purpose: The reactive "nowhere to send help" state specified in `03-UI-SPEC.md` only appears
*after* a user has already held the button for three seconds during a real emergency. That is
the worst possible moment to learn your alert has no destination. This task moves that
discovery to a calm moment on a settings screen.

Output: A `SosReach` provider, a self-hiding warning card rendered in the Privacy Center (both
its normal and its no-circle states), unit + widget tests, a source-level regression gate proving
no role-based SOS gating exists, and device screenshots of both the zero-recipient and the
has-recipients states.
</objective>

<current_state>
Confirmed by reading the source, not assumed.

**Recipient resolution (the thing the nudge must mirror):**
`backend/src/SafePath.Application/Sos/TriggerSosCommand.cs`

- `ResolveRecipients` (line 164): `_db.FamilyMembers.Where(m => m.FamilyId == familyId && m.IsActive
  && m.Role == Role.Guardian && m.UserId != callerUserId)`.
- `ResolveEmergencyContacts` (line 184): `_db.EmergencyContacts.Where(c => c.OwnerUserId == callerUserId
  && c.IsActive)`.
- D-11 is enforced here: recipients are active Guardians plus the caller's own emergency contacts,
  never all family members. Both bypass `ISharingAuthorizationService` deliberately.

**Client-side data already available - no new endpoint is needed:**

- `familyControllerProvider` (`mobile/lib/features/family/application/family_controller.dart`)
  holds `FamilyState.members` as `List<FamilyMemberView>`, populated from
  `GET /families/{id}/members`. `FamilyMemberView` (`family_models.dart` line 44) carries
  `userId`, `role` (`Role` enum with `Role.guardian`), `memberId`, `permission`, `joinedAt`.
- `FamilyMemberView` has **no** `isActive` field, and does not need one: the backend's
  `ListFamilyMembersQuery.cs` line 39 already filters `where member.FamilyId == query.FamilyId
  && member.IsActive`, so every row the client ever sees is already an active member. This is
  the equivalence that makes `IsActive` parity hold client-side.
- `emergencyContactsControllerProvider`
  (`mobile/lib/features/sos/application/emergency_contacts_controller.dart`) holds
  `EmergencyContactsState.contacts` as `List<EmergencyContact>`, each carrying an explicit
  `isActive` bool (`emergency_contact_api.dart` line 34). `GET /me/emergency-contacts` is
  documented as returning active contacts only, but the flag is on the wire, so filter on it.
- Current user id is read as `ref.watch(authApiProvider).currentSession?.user.id` - existing
  precedent at `privacy_center_screen.dart` line 164.

**Guardian-role SOS access - the audit's starting evidence:**

- `mobile/lib/features/sos/presentation/sos_arm_button.dart` takes exactly one parameter,
  `onArmComplete`. It contains no `Role` reference, no profile/family read, and no Riverpod
  dependency at all - it is a plain `StatefulWidget`.
- `mobile/lib/features/home/main_shell.dart` line 124-127 mounts it unconditionally:
  `Positioned(top: 0, child: SosArmButton(onArmComplete: _onArmComplete))`. There is no
  surrounding conditional of any kind.
- A repo-wide grep for `Role\.guardian|role ==|isGuardian|role !=` across `mobile/lib` returns
  hits only in `no_circle_cta.dart`, `landing_stub_screen.dart`, `role_select_screen.dart`, and
  `app_router.dart` (role *onboarding* redirects only - `needsRoleOnboarding` at lines 118-122
  and 172-177). None of these sit on the SOS trigger path, and `/home` is never gated by role.
- **Conclusion: there is no gap to fix.** Task 1 is therefore an audit plus a permanent
  source-level regression gate, not a code change. Per the task constraint, do NOT add
  speculative role-check code.

**Privacy Center render structure (`privacy_center_screen.dart`):**

- `build` computes `familyState`, `privacyState`, `currentUserId`, `familyId`, `recipients`.
- Early return 1 (line 171): both-loading -> `CircularProgressIndicator`.
- Early return 2 (line 178): `familyId == null` -> `const _PrivacyMessage(icon: Icons.group_off,
  title: 'No circle yet', ..., action: NoCircleCta())`. `_PrivacyMessage` (line 549) renders a
  centered `Column(mainAxisSize: min)` with icon, title, body, optional action.
- Main path: a `ListView` whose first children are the heading, subtitle, `AppSpacing.lg` gap,
  then a conditional `_ErrorCard`, then the recipient matrices, then `_PrivacyActionsSection`
  (which already contains the `'Emergency contacts'` entry pushing `/settings/emergency-contacts`,
  the precedent for adding SOS-adjacent entries here).

**Existing test scaffolding that this task depends on:**

- `mobile/test/features/privacy/privacy_center_screen_test.dart` already builds two containers:
  `_app(...)` (line 162, seeded family) and `_noCircleApp(...)` (line 178, no family). Both
  already override `authApiProvider` with `FakeAuthApi(initialSession: _session(userId: 'self-user'))`.
- Its `_SeededFamilyController` (line 43) seeds `mem-self` as the ONLY `Role.guardian`, with two
  `Role.member` rows. Under the new provider that seeded family is itself a zero-other-Guardian
  scenario - which makes it a convenient positive fixture, but also means every existing test in
  that file will start rendering the nudge once wiring lands unless emergency contacts are seeded.
- `mobile/test/helpers/fake_emergency_contact_api.dart` exists (`FakeEmergencyContactApi` with a
  settable `contactsToList`), so no new fake is needed.
</current_state>

<design_direction>
**Surface choice: Privacy Center only.** It is a permanent bottom-nav destination (index 3 of
`MainShell`), it is where the user already goes to reason about who can see what, and it already
hosts the `'Emergency contacts'` entry point added by 03-07 - so the nudge's remedy is one tap
away from the nudge itself. The Family Circle screens (`/circle/*`) are pushed routes visited
rarely, so a warning parked there would frequently go unseen. One surface, two render states.

**Colour: amber, never red.** `03-UI-SPEC.md`'s Colour section reaffirms that `AppColors.sosRed`
is reserved exclusively for SOS/emergency surfaces, and that non-SOS attention states use
`AppColors.caution` (`#C98A2B`) - "never a second red". A settings-screen warning about a
*potential future* emergency is an attention state, not an emergency. Use `AppColors.caution`
with `Icons.warning_amber_rounded`, inside the existing `SafePathCard` shell so it sits in the
same visual family as the rest of the screen.

**Copy: proactive and conditional, not the locked reactive copy.** `03-UI-SPEC.md` line 263 locks
a reactive post-press empty state that is shown only after the arm-complete callback finds zero
recipients. That copy is past-tense and remedial. This nudge must be forward-looking and
conditional, consistent in tone but verbatim-distinct:

- Heading: `SOS would reach no one`
- Body: `Your circle has no other guardian, and you haven't added any emergency contacts. If you trigger SOS right now, nobody would be notified.`
- Action: `Add an emergency contact` -> `context.push('/settings/emergency-contacts')`

The single CTA is deliberately the emergency-contact one in both render states: adding a contact
is the one remedy that works regardless of whether the user has a circle yet, and the no-circle
state already carries `NoCircleCta` for the create/join path.

**Three-state, not boolean.** `SosReach` must distinguish `unknown` from `hasRecipients` and
`noRecipients`. A boolean collapses "still loading" into "nobody will be notified", which would
flash a false alarm on every cold start. Only `noRecipients` renders anything.
</design_direction>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@.planning/phases/03-sos-fast-path/03-UI-SPEC.md
@backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
@mobile/lib/features/family/data/family_models.dart
@mobile/lib/features/family/application/family_controller.dart
@mobile/lib/features/sos/application/emergency_contacts_controller.dart
@mobile/lib/features/sos/data/emergency_contact_api.dart
@mobile/lib/features/privacy/presentation/privacy_center_screen.dart
@mobile/lib/features/home/main_shell.dart
@mobile/lib/features/sos/presentation/sos_arm_button.dart
@mobile/lib/core/theme/app_colors.dart
@mobile/lib/core/theme/app_spacing.dart
@mobile/lib/core/theme/app_typography.dart
@mobile/test/features/privacy/privacy_center_screen_test.dart
@mobile/test/helpers/fake_emergency_contact_api.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Audit Guardian-role SOS access and install a permanent source-level regression gate</name>
  <files>.planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/260805-uke-SUMMARY.md</files>
  <action>
This is an audit task. Produce no production code change unless the audit finds a real gate.

Run the audit across the three files that make up the entire mobile SOS trigger surface:
`mobile/lib/features/sos/presentation/sos_arm_button.dart`,
`mobile/lib/features/sos/application/sos_controller.dart`, and
`mobile/lib/features/home/main_shell.dart`. For each, confirm:

1. The button widget is constructed and mounted unconditionally, with no surrounding conditional
   that reads the current user's family role or profile role.
2. `arm()` and every method it calls contain no branch on the caller's role - the only
   authorization that exists is server-side `RequireMembership`, which is membership, not role.
3. The router never redirects away from the home shell based on role. The only role-driven
   redirect in `app_router.dart` is the onboarding redirect for a user who has not yet picked a
   role at all, which applies identically to every role and is not a capability gate.

Also confirm at the backend boundary that `TriggerSosCommandHandler.Handle` calls
`_authorization.RequireMembership(...)` and never `RequireRole(...)` - so the server is not
gating either. Record this as read-only evidence; do not modify any backend file.

Install the regression gate. Record it verbatim in the SUMMARY's "Verification" section as the
command that must keep passing, so a future change that wraps the button in a role conditional
is caught. The gate greps only those three trigger-path files, deliberately narrow: the nudge
work in Task 2 legitimately needs `Role.guardian` and lives in other files, so a repo-wide gate
would be self-invalidating.

In the SUMMARY, state the audit outcome explicitly as either "no gate found, no fix required"
or, if the audit genuinely surfaces one, describe the exact conditional found and remove it
(and only it). Do not add defensive role-permitting code to prove a negative.
  </action>
  <verify>
    <automated>cd mobile && grep -nE 'Role\.(guardian|member|caregiver|orgAdmin)|isGuardian|\.role\b' lib/features/sos/presentation/sos_arm_button.dart lib/features/sos/application/sos_controller.dart lib/features/home/main_shell.dart; test $? -eq 1</automated>
    <automated>cd backend && grep -n 'RequireRole' src/SafePath.Application/Sos/TriggerSosCommand.cs; test $? -eq 1</automated>
  </verify>
  <done>The three SOS trigger-path files contain zero role references; the backend trigger handler contains zero RequireRole calls; the SUMMARY records the audit outcome and the verbatim regression-gate command. No production file was modified by this task unless a real gate was found and removed.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add the SosReach computation, the warning card, and wire it into both Privacy Center render states</name>
  <files>mobile/lib/features/sos/application/sos_reach_provider.dart, mobile/lib/features/sos/presentation/sos_reach_warning_card.dart, mobile/lib/features/privacy/presentation/privacy_center_screen.dart, mobile/test/features/sos/sos_reach_provider_test.dart, mobile/test/features/privacy/privacy_center_screen_test.dart</files>
  <behavior>
    - Family loaded with one other active Guardian, zero emergency contacts -> hasRecipients.
    - Family loaded with zero other Guardians, one active emergency contact -> hasRecipients.
    - Family loaded with zero other Guardians, one INACTIVE emergency contact only -> noRecipients.
    - Family loaded with zero other Guardians, zero emergency contacts -> noRecipients.
    - Family loaded where the ONLY Guardian row is the current user's own row -> that row is excluded, so with no contacts the result is noRecipients.
    - Family loaded with two non-Guardian members and zero contacts -> noRecipients (members are not recipients, D-11).
    - No family at all (family == null, members empty) and zero contacts -> noRecipients.
    - FamilyState.isLoading true -> unknown, regardless of contacts.
    - Emergency contacts still AsyncLoading -> unknown, regardless of family.
    - Emergency contacts in AsyncError -> unknown, never noRecipients.
    - No authenticated session (currentSession null) -> unknown.
    - Card renders nothing at all for hasRecipients and for unknown; renders heading, body and CTA only for noRecipients.
    - Tapping the card's CTA navigates to the emergency contacts route.
  </behavior>
  <action>
<!-- planner-discipline-allow: sos_reach -->

**Step 1 - the computation.** Create `mobile/lib/features/sos/application/sos_reach_provider.dart`.

Declare `enum SosReach { unknown, hasRecipients, noRecipients }` and a
`final sosReachProvider = Provider<SosReach>((ref) { ... })`.

Inside, watch `familyControllerProvider` and `emergencyContactsControllerProvider` and read the
current user id via `ref.watch(authApiProvider).currentSession?.user.id` (the same expression
`privacy_center_screen.dart` already uses at line 164 - do not introduce a second, divergent way
to identify the current user).

Return `SosReach.unknown` immediately if ANY of these hold, before computing anything:
the family async value is still loading or its `.value` is null; the resolved `FamilyState.isLoading`
is true (this is the `GET /families/mine` bootstrap flag, distinct from the AsyncValue's own
loading state - both must be checked); the emergency-contacts async value is loading, has an
error, or its `.value` is null; the current user id is null. Loading-safety is the point of the
third state - a false "nobody would be notified" during a cold start is worse than showing nothing.

Then compute, mirroring the backend exactly:

- `guardianCount` = count of `FamilyState.members` where `m.role == Role.guardian && m.userId != currentUserId`.
  Document in a doc comment that no client-side active check is applied here because
  `ListFamilyMembersQuery` already filters `member.IsActive` server-side, so every row present is
  active - and that this is the parity argument, not an oversight.
- `contactCount` = count of `EmergencyContactsState.contacts` where `c.isActive`. The flag is on
  the wire, so filter it explicitly even though the endpoint is documented as active-only.

Return `noRecipients` when both counts are zero, `hasRecipients` otherwise.

Write a class-level doc comment stating that this provider mirrors
`TriggerSosCommandHandler.ResolveRecipients` and `ResolveEmergencyContacts` (D-11), that it is a
read-only settings-surface derivation over data the app has already fetched, and that it must
never be read from the SOS trigger path.

**Step 2 - the card.** Create `mobile/lib/features/sos/presentation/sos_reach_warning_card.dart`
holding a `SosReachWarningCard extends ConsumerWidget` with a `const` constructor and no required
parameters.

It watches `sosReachProvider` itself and returns `const SizedBox.shrink()` unless the value is
`SosReach.noRecipients` - self-hiding, so both call sites are unconditional one-liners and neither
can drift from the other's condition.

For the visible state, render a `SafePathCard` containing a `Column(crossAxisAlignment: start)`:
a `Row` with `Icon(Icons.warning_amber_rounded, color: AppColors.caution)` plus `AppSpacing.sm`
gap plus an `Expanded` heading styled with `AppTypography.title`; then `AppSpacing.sm`; then the
body styled with `AppTypography.bodySecondary`; then `AppSpacing.sm`; then a
`TextButton.icon(icon: Icon(Icons.contact_phone_outlined), label: Text('Add an emergency contact'))`
whose `onPressed` calls `context.push('/settings/emergency-contacts')` (matching the route already
used by `_PrivacyActionsSection.onEmergencyContacts`).

Use the exact copy from this plan's `<design_direction>` section for the heading and body. Do not
reuse, paraphrase into near-identity, or quote the locked reactive post-press empty-state strings
from `03-UI-SPEC.md` line 263 - that copy belongs to a different moment (after a press, during a
real emergency) and this card must read as a calm forward-looking warning. Colour: use
`AppColors.caution` for the icon; do not reach for the reserved SOS emergency red token, per the
colour reservation contract in `03-UI-SPEC.md`.

Give the card's root a `const ValueKey('sos-reach-warning')` so widget tests can target it without
matching on copy strings.

**Step 3 - wire both render states in `privacy_center_screen.dart`.**

Call site A (main path): insert `const SosReachWarningCard()` followed by
`const SizedBox(height: AppSpacing.md)` into the `ListView` children immediately after the
`SizedBox(height: AppSpacing.lg)` that follows the subtitle, i.e. above the `_ErrorCard` block and
above the recipient matrices. When the card self-hides it collapses to zero height, so guard the
trailing spacer by rendering both together via a spread of a single-element list only when the
watched `sosReachProvider` equals `noRecipients`, OR simpler and preferred: give the card itself
the trailing bottom padding internally so the call site stays a bare `const SosReachWarningCard()`
with no leftover gap when hidden. Pick the second approach.

Call site B (no-circle path): add an optional `final Widget? banner;` field to the private
`_PrivacyMessage` widget and render it as the first child of its centred `Column`, followed by a
`SizedBox(height: AppSpacing.lg)`, both only when `banner != null`. Then pass
`banner: const SosReachWarningCard()` at the `familyId == null` return site. That return is
currently `const` - drop the `const` on the `_PrivacyMessage` construction as required. A user with
no circle has zero Guardians by definition, so this is a genuine zero-recipient state and must not
be silently skipped.

Make no other change to this screen: do not reorder the actions section, do not touch the
temporary-sharing or export/delete logic.

**Step 4 - tests.** Create `mobile/test/features/sos/sos_reach_provider_test.dart` driving
`sosReachProvider` through a bare `ProviderContainer` (matching this project's controller-test
convention - no widget pumping needed). Override `familyControllerProvider` with small seeded
subclasses of `FamilyController` (mirroring `_SeededFamilyController`/`_NoFamilyController` in
`privacy_center_screen_test.dart`), override `emergencyContactApiProvider` with
`FakeEmergencyContactApi` and its `contactsToList`/`listError` knobs, and override
`authApiProvider` with `FakeAuthApi(initialSession: ...)`. Cover every case in this task's
`<behavior>` list.

Then update `mobile/test/features/privacy/privacy_center_screen_test.dart`. Both `_app(...)` and
`_noCircleApp(...)` must gain an `emergencyContactApiProvider.overrideWithValue(...)` entry -
without it, `EmergencyContactsController.build()` reaches for the real Dio client and every
existing test in the file breaks the moment the screen starts watching the new provider. Note that
the existing `_SeededFamilyController` seeds the current user as the only Guardian, so with an
empty contact list the seeded fixture is itself a zero-recipient scenario; seed at least one active
contact in the default fixture so existing assertions keep exercising the has-recipients path, and
add explicit new cases that assert the card is absent with recipients present and present with
none, on both the main and the no-circle render paths.

**Hard boundaries for this task.** Do not touch any file under `backend/`. Do not touch
`sos_controller.dart`, `sos_arm_button.dart`, `sos_api.dart`, `sos_hub_client.dart`,
`sos_local_store.dart`, or `sender_emergency_session_screen.dart`. Do not add a backend endpoint -
both data sources are already fetched by the running app, so the nudge introduces no new request on
any path, and certainly none on the trigger path. The one incidental effect is that the emergency
contacts list is now fetched when the Privacy tab first builds (it is an eager child of
`MainShell`'s `IndexedStack`), which happens at home-screen mount, asynchronously, and is entirely
off the SOS hot path - note this in the SUMMARY.
  </action>
  <verify>
    <automated>cd mobile && flutter analyze --no-pub lib/features/sos lib/features/privacy</automated>
    <automated>cd mobile && flutter test test/features/sos/sos_reach_provider_test.dart test/features/privacy/privacy_center_screen_test.dart</automated>
    <automated>cd mobile && grep -n 'AppColors.caution' lib/features/sos/presentation/sos_reach_warning_card.dart</automated>
    <automated>cd mobile && grep -rn 'No one to alert yet' lib/features/sos/presentation/sos_reach_warning_card.dart lib/features/privacy/presentation/privacy_center_screen.dart; test $? -eq 1</automated>
    <automated>cd mobile && grep -rn 'sos_reach' lib/features/sos/application/sos_controller.dart lib/features/sos/presentation/sos_arm_button.dart lib/features/home/main_shell.dart; test $? -eq 1</automated>
    <automated>git diff --name-only -- backend/ | grep . ; test $? -eq 1</automated>
    <automated>cd mobile && flutter test</automated>
  </verify>
  <done>sosReachProvider returns noRecipients only when zero other active Guardians AND zero active emergency contacts are both confirmed loaded, and unknown in every loading/error/no-session case. The card renders in the Privacy Center's main and no-circle states and hides itself otherwise. The full mobile test suite passes. No backend file and no SOS trigger-path file was modified.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    A proactive zero-SOS-recipient warning card in the Privacy Center, computed client-side from
    the already-loaded family member list and emergency contact list, mirroring the backend's own
    recipient resolution. Plus a source-level gate proving the SOS button is not role-gated.
  </what-built>
  <how-to-verify>
1. Confirm a device or emulator is attached: `cd mobile && flutter devices`.
2. Launch the app: `cd mobile && flutter run -d <deviceId>`. Sign in as a user whose circle has
   no second Guardian.
3. **Zero-recipient state.** If the signed-in account has any emergency contacts, open
   Privacy -> "Emergency contacts" and delete them first (this uses the real soft-delete endpoint;
   do not fabricate state by editing code or stubbing a response). Return to the Privacy tab.
   Confirm the amber warning card appears above the sharing controls, showing the heading, the
   body sentence, and the "Add an emergency contact" button. Confirm the card uses amber, not the
   SOS red used by the bottom-nav button.
4. Capture a screenshot: `flutter screenshot --out ../.planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/screenshots/zero-recipient.png`
5. Tap "Add an emergency contact" and confirm it opens the emergency contacts screen.
6. **Has-recipients state.** Add one real emergency contact, then return to the Privacy tab.
   Confirm the warning card is now completely gone with no leftover blank gap where it was.
7. Capture a screenshot: `flutter screenshot --out ../.planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/screenshots/has-recipients.png`
   If a second Guardian account is available, also confirm the card stays hidden with a Guardian
   present and zero contacts; if not, say so rather than fabricating that scenario.
8. **Guardian SOS access.** While signed in as a Guardian-role account, confirm the SOS button is
   visible in the bottom nav and that a full three-second hold arms it and opens the emergency
   session screen exactly as it does for a Member account. Cancel/close the session afterward.
9. **Cold-start no-false-alarm check.** Force-quit and relaunch the app, then go straight to the
   Privacy tab and watch it settle. The warning card must not flash on screen before the family
   and contact data finish loading.
  </how-to-verify>
  <resume-signal>Type "approved" once both screenshots are saved and the Guardian SOS hold has been confirmed on-device, or describe what rendered incorrectly.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| device -> settings UI | Data rendered is already resident on the device and already owned by the signed-in caller; no new boundary is crossed. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QUICK-UKE-01 | Information disclosure | sosReachProvider | low | accept | The provider derives only a three-state enum from `GET /families/{id}/members` and `GET /me/emergency-contacts`, both already authorized to and already fetched by this caller. It exposes no new field, no phone number, and no other user's data. |
| T-QUICK-UKE-02 | Denial of service | SOS trigger path | high | mitigate | The nudge adds no call, import, or await on the trigger path. Enforced by the Task 2 negative-grep gate over `sos_controller.dart`, `sos_arm_button.dart`, and `main_shell.dart`, and by the no-backend-diff gate. |
| T-QUICK-UKE-03 | Spoofing | client-side recipient mirror | medium | accept | The client computation is advisory only. Real recipient resolution stays server-side in `TriggerSosCommandHandler`; a tampered client can suppress its own warning but cannot change who an SOS actually reaches. |

No new package is installed by this task, so no package legitimacy gate applies.
</threat_model>

<verification>
- `cd mobile && flutter analyze --no-pub` reports no new issues.
- `cd mobile && flutter test` passes in full, including the pre-existing privacy and SOS suites.
- The Task 1 regression gate returns no matches across the three SOS trigger-path files.
- `git diff --name-only` lists no path under `backend/`.
- Both device screenshots exist under `.planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/screenshots/`.
</verification>

<success_criteria>
- A user with no other active Guardian and no active emergency contacts sees the amber warning on
  the Privacy tab, in both the normal and the no-circle render states, before ever pressing SOS.
- Adding a single active emergency contact, or gaining a second active Guardian, hides the warning
  entirely with no leftover layout gap.
- The warning never appears while family or contact data is still loading or has errored.
- The nudge's condition is provably the client mirror of `ResolveRecipients` +
  `ResolveEmergencyContacts` (D-11), verified by the provider unit tests.
- The Guardian-role SOS audit is recorded with an explicit outcome and a permanent gate command.
- Zero files changed under `backend/`, and zero files changed on the SOS trigger/dispatch path.
</success_criteria>

<output>
Create `.planning/quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/260805-uke-SUMMARY.md` when done.
</output>
