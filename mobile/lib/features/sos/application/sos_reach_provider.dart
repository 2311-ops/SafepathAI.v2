import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../family/application/family_controller.dart';
import 'emergency_contacts_controller.dart';

/// Three-state client-side mirror of the backend's own SOS recipient
/// resolution (`TriggerSosCommandHandler.ResolveRecipients` +
/// `TriggerSosCommandHandler.ResolveEmergencyContacts`, D-11):
///
/// - [hasRecipients]: at least one other active Guardian in the caller's
///   family, or at least one of the caller's own active emergency contacts.
/// - [noRecipients]: neither is true — an SOS triggered right now would
///   reach nobody.
/// - [unknown]: the underlying family and/or emergency-contact data is still
///   loading, errored, or there is no authenticated session yet. Every
///   ambiguous case collapses to [unknown] rather than [noRecipients] — a
///   false "nobody would be notified" during a cold start is worse than
///   showing nothing.
enum SosReach { unknown, hasRecipients, noRecipients }

/// Read-only settings-surface derivation over data the app has already
/// fetched via [familyControllerProvider] and
/// [emergencyContactsControllerProvider] — it introduces no new network
/// call and no new endpoint. It must never be read from the SOS trigger path
/// (`sos_controller.dart`, `sos_arm_button.dart`, `main_shell.dart`); that
/// boundary is enforced by a source-level negative-grep gate (see
/// `260805-uke-PLAN.md` Task 2 verification).
final sosReachProvider = Provider<SosReach>((ref) {
  final familyAsync = ref.watch(familyControllerProvider);
  final contactsAsync = ref.watch(emergencyContactsControllerProvider);
  final currentUserId = ref.watch(authApiProvider).currentSession?.user.id;

  // The family async value must have actually resolved to something.
  if (familyAsync.isLoading || familyAsync.value == null) {
    return SosReach.unknown;
  }
  final familyState = familyAsync.value!;

  // `FamilyState.isLoading` is the `GET /families/mine` bootstrap flag
  // (family_controller.dart) — distinct from `familyAsync.isLoading` above,
  // which only reflects whether the AsyncNotifier's own build/refresh cycle
  // has completed. Both must be checked: a mid-bootstrap
  // `FamilyState(isLoading: true)` is already a resolved `AsyncData`, so the
  // check above alone would not catch it.
  if (familyState.isLoading) {
    return SosReach.unknown;
  }

  // The emergency-contacts async value must be loaded, error-free, and
  // resolved.
  if (contactsAsync.isLoading ||
      contactsAsync.hasError ||
      contactsAsync.value == null) {
    return SosReach.unknown;
  }
  final contactsState = contactsAsync.value!;

  if (currentUserId == null) {
    return SosReach.unknown;
  }

  // No client-side `isActive` check is applied to family members: the
  // backend's `ListFamilyMembersQuery` already filters `member.IsActive`
  // before `FamilyController` ever sees a row (see family_controller.dart /
  // `GET /families/{id}/members`), so every member present here is already
  // active. This is the parity argument for `guardianCount`, not an
  // oversight.
  final guardianCount = familyState.members
      .where(
        (member) => member.role == Role.guardian && member.userId != currentUserId,
      )
      .length;

  // Emergency contacts carry an explicit `isActive` flag on the wire (even
  // though `GET /me/emergency-contacts` is documented as active-only), so it
  // is filtered explicitly here rather than assumed.
  final contactCount = contactsState.contacts
      .where((contact) => contact.isActive)
      .length;

  return (guardianCount == 0 && contactCount == 0)
      ? SosReach.noRecipients
      : SosReach.hasRecipients;
});
