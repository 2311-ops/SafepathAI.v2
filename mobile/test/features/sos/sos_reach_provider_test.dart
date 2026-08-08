// Behavior under test (260805-uke-PLAN.md Task 2):
// - hasRecipients when at least one other active Guardian exists, or at
//   least one active emergency contact exists, or both.
// - noRecipients only when both counts are zero (D-11 parity with
//   TriggerSosCommandHandler.ResolveRecipients / ResolveEmergencyContacts).
// - An inactive-only emergency contact does not count.
// - The current user's own Guardian row is excluded from guardianCount.
// - Non-Guardian family members are never counted as recipients.
// - unknown in every loading/error/no-session case, never a false
//   noRecipients during a cold start.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/sos/application/emergency_contacts_controller.dart';
import 'package:mobile/features/sos/application/sos_reach_provider.dart';
import 'package:mobile/features/sos/data/emergency_contact_api.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_emergency_contact_api.dart';

class _FixedFamilyController extends FamilyController {
  _FixedFamilyController(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

sb.Session _session({required String userId}) {
  return sb.Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: sb.User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

EmergencyContact _contact({required bool isActive, String id = 'contact-1'}) {
  return EmergencyContact(
    id: id,
    displayName: 'Contact',
    phoneNumberE164: '+15555550100',
    isActive: isActive,
  );
}

FamilyMemberView _member({
  required String memberId,
  required String userId,
  required Role role,
}) {
  return FamilyMemberView(
    memberId: memberId,
    userId: userId,
    role: role,
    permission: PermissionLevel.fullLocation,
    joinedAt: DateTime.utc(2026, 7, 12),
  );
}

ProviderContainer _container({
  required FamilyState familyState,
  required EmergencyContactApi contactApi,
  String? sessionUserId = 'self-user',
}) {
  final container = ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(
        () => _FixedFamilyController(familyState),
      ),
      emergencyContactApiProvider.overrideWithValue(contactApi),
      authApiProvider.overrideWithValue(
        FakeAuthApi(
          initialSession: sessionUserId == null
              ? null
              : _session(userId: sessionUserId),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Kicks off `EmergencyContactsController.build()` (async) and flushes the
/// event queue until it settles. Without an initial read, `pumpEventQueue`
/// has nothing in flight to flush — the notifier only starts building on
/// its first read.
Future<void> _settle(ProviderContainer container) async {
  container.read(emergencyContactsControllerProvider);
  await pumpEventQueue();
}

void main() {
  test('one other active Guardian, zero contacts -> hasRecipients', () async {
    final familyState = FamilyState(
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
        _member(memberId: 'mem-other', userId: 'other-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()..contactsToList = const [],
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.hasRecipients);
  });

  test(
    'zero other Guardians, one active emergency contact -> hasRecipients',
    () async {
      final familyState = FamilyState(
        family: const Family(id: 'fam-1'),
        members: [
          _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
        ],
      );
      final container = _container(
        familyState: familyState,
        contactApi: FakeEmergencyContactApi()
          ..contactsToList = [_contact(isActive: true)],
      );

      await _settle(container);

      expect(container.read(sosReachProvider), SosReach.hasRecipients);
    },
  );

  test('zero other Guardians, one INACTIVE contact only -> noRecipients', () async {
    final familyState = FamilyState(
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()
        ..contactsToList = [_contact(isActive: false)],
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.noRecipients);
  });

  test('zero other Guardians, zero contacts -> noRecipients', () async {
    final familyState = FamilyState(
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()..contactsToList = const [],
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.noRecipients);
  });

  test(
    "the only Guardian row is the current user's own row -> excluded, noRecipients",
    () async {
      final familyState = FamilyState(
        family: const Family(id: 'fam-1'),
        members: [
          _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
          _member(memberId: 'mem-other', userId: 'other-user', role: Role.member),
        ],
      );
      final container = _container(
        familyState: familyState,
        contactApi: FakeEmergencyContactApi()..contactsToList = const [],
      );

      await _settle(container);

      expect(container.read(sosReachProvider), SosReach.noRecipients);
    },
  );

  test(
    'two non-Guardian members, zero contacts -> noRecipients (D-11: members are not recipients)',
    () async {
      final familyState = FamilyState(
        family: const Family(id: 'fam-1'),
        members: [
          _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
          _member(memberId: 'mem-a', userId: 'a-user', role: Role.member),
          _member(memberId: 'mem-b', userId: 'b-user', role: Role.member),
        ],
      );
      final container = _container(
        familyState: familyState,
        contactApi: FakeEmergencyContactApi()..contactsToList = const [],
      );

      await _settle(container);

      expect(container.read(sosReachProvider), SosReach.noRecipients);
    },
  );

  test('no family at all, zero contacts -> noRecipients', () async {
    final container = _container(
      familyState: const FamilyState(),
      contactApi: FakeEmergencyContactApi()..contactsToList = const [],
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.noRecipients);
  });

  test('FamilyState.isLoading true -> unknown, regardless of contacts', () async {
    final familyState = FamilyState(
      isLoading: true,
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()
        ..contactsToList = [_contact(isActive: true)],
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.unknown);
  });

  test(
    'emergency contacts still AsyncLoading -> unknown, regardless of family',
    () {
      final familyState = FamilyState(
        family: const Family(id: 'fam-1'),
        members: [
          _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
        ],
      );
      final container = _container(
        familyState: familyState,
        contactApi: FakeEmergencyContactApi()..contactsToList = const [],
      );

      // Deliberately not settled: EmergencyContactsController.build() is
      // async and hits its first `await` immediately, so the very first
      // synchronous read lands while emergencyContactsControllerProvider is
      // still AsyncLoading.
      expect(container.read(sosReachProvider), SosReach.unknown);
    },
  );

  test('emergency contacts in AsyncError -> unknown, never noRecipients', () async {
    final familyState = FamilyState(
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()
        ..listError = EmergencyContactApiException(
          EmergencyContactApiIssue.unknown,
          message: 'boom',
        ),
    );

    // The controller's build() rethrows into AsyncError — flush the event
    // queue so it settles, then confirm it actually did before asserting.
    await _settle(container);
    expect(
      container.read(emergencyContactsControllerProvider).hasError,
      isTrue,
    );

    expect(container.read(sosReachProvider), SosReach.unknown);
  });

  test('no authenticated session -> unknown', () async {
    final familyState = FamilyState(
      family: const Family(id: 'fam-1'),
      members: [
        _member(memberId: 'mem-self', userId: 'self-user', role: Role.guardian),
      ],
    );
    final container = _container(
      familyState: familyState,
      contactApi: FakeEmergencyContactApi()
        ..contactsToList = [_contact(isActive: true)],
      sessionUserId: null,
    );

    await _settle(container);

    expect(container.read(sosReachProvider), SosReach.unknown);
  });
}
