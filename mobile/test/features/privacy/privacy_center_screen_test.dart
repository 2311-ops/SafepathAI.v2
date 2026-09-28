import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/privacy/application/privacy_controller.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import 'package:mobile/features/privacy/presentation/privacy_center_screen.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/user_profile.dart';
import 'package:mobile/features/sos/data/emergency_contact_api.dart';
import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_emergency_contact_api.dart';

/// A family controller stuck in the "no circle yet" state (family == null,
/// not loading) — the exact state a freshly-signed-in user lands in.
class _NoFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState();
}

/// Seeds a profile with a fixed role so [NoCircleCta] can pick the right
/// Guardian/Member entry point without touching auth or the network.
class _SeededProfileController extends ProfileController {
  _SeededProfileController(this.role);

  final Role? role;

  @override
  ProfileState build() => ProfileState(
    profile: UserProfile(
      userId: 'self-user',
      email: null,
      fullName: null,
      role: role,
    ),
  );
}

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'fam-1', name: 'Safe circle'),
    members: [
      FamilyMemberView(
        memberId: 'mem-self',
        userId: 'self-user',
        role: Role.guardian,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 7, 12),
      ),
      FamilyMemberView(
        memberId: 'mem-first-recipient',
        userId: 'first-recipient-user',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 7, 12),
      ),
      FamilyMemberView(
        memberId: 'mem-second-recipient',
        userId: 'second-recipient-user',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 7, 12),
      ),
    ],
  );
}

class _SpyPrivacyController extends PrivacyController {
  int toggleCallCount = 0;
  int temporaryShareCallCount = 0;
  int deleteMyDataCallCount = 0;
  String? lastRecipientId;
  SharedDataType? lastDataType;
  bool? lastEnabled;
  Duration? lastDuration;

  @override
  PrivacyState build() => PrivacyState(
    matrix: SharingMatrix(
      entries: [
        SharingCell(
          dataType: SharedDataType.liveLocation,
          isEnabled: true,
          // A 4-hour session (10:00 -> 14:00). At the fixed test clock of 10:30
          // there is 3h30m left, which ceiling-rounds to "4 hours left".
          startedAtUtc: DateTime.utc(2026, 7, 12, 10),
          expiresAtUtc: DateTime.utc(2026, 7, 12, 14),
        ),
        const SharingCell(dataType: SharedDataType.history, isEnabled: false),
        const SharingCell(dataType: SharedDataType.wellness, isEnabled: true),
      ],
    ),
  );

  @override
  Future<void> toggle({
    String? recipientId,
    required SharedDataType dataType,
    required bool enabled,
    DateTime? expiresAtUtc,
    DateTime? startedAtUtc,
  }) async {
    toggleCallCount++;
    lastRecipientId = recipientId;
    lastDataType = dataType;
    lastEnabled = enabled;
  }

  @override
  Future<void> startTemporaryShare({
    String? recipientId,
    required SharedDataType dataType,
    required Duration duration,
  }) async {
    temporaryShareCallCount++;
    lastRecipientId = recipientId;
    lastDataType = dataType;
    lastDuration = duration;
  }

  @override
  Future<void> deleteMyData() async {
    deleteMyDataCallCount++;
  }
}

/// Default emergency-contact fixture: one active contact, so the seeded
/// family (whose only Guardian is the current user) does not itself become
/// a zero-recipient scenario for tests that aren't exercising the nudge.
EmergencyContactApi _hasContactApi() =>
    FakeEmergencyContactApi()..contactsToList = [_activeContact()];

EmergencyContactApi _noContactApi() =>
    FakeEmergencyContactApi()..contactsToList = const [];

EmergencyContact _activeContact() => const EmergencyContact(
  id: 'contact-1',
  displayName: 'Alex',
  phoneNumberE164: '+15555550100',
  isActive: true,
);

Widget _app(
  _SpyPrivacyController controller, {
  EmergencyContactApi? contactApi,
}) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(
        FakeAuthApi(initialSession: _session(userId: 'self-user')),
      ),
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
      emergencyContactApiProvider.overrideWithValue(
        contactApi ?? _hasContactApi(),
      ),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(Role.guardian),
      ),
      privacyControllerProvider.overrideWith(() => controller),
      privacyNowProvider.overrideWithValue(
        () => DateTime.utc(2026, 7, 12, 10, 30),
      ),
    ],
    child: const MaterialApp(home: PrivacyCenterScreen()),
  );
}

Widget _noCircleApp(Role? role, {EmergencyContactApi? contactApi}) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(
        FakeAuthApi(initialSession: _session(userId: 'self-user')),
      ),
      familyControllerProvider.overrideWith(_NoFamilyController.new),
      emergencyContactApiProvider.overrideWithValue(
        contactApi ?? _hasContactApi(),
      ),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(role),
      ),
      privacyControllerProvider.overrideWith(_SpyPrivacyController.new),
      privacyNowProvider.overrideWithValue(
        () => DateTime.utc(2026, 7, 12, 10, 30),
      ),
    ],
    child: const MaterialApp(home: PrivacyCenterScreen()),
  );
}

/// Router-backed variant so the warning card's CTA (`context.push`) can
/// actually resolve — mirrors `live_map_screen_test.dart`'s `_routerApp`
/// convention.
Widget _routerApp(
  _SpyPrivacyController controller, {
  EmergencyContactApi? contactApi,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PrivacyCenterScreen(),
      ),
      GoRoute(
        path: '/settings/emergency-contacts',
        builder: (context, state) =>
            const Scaffold(body: Text('Emergency Contacts Screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(
        FakeAuthApi(initialSession: _session(userId: 'self-user')),
      ),
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
      emergencyContactApiProvider.overrideWithValue(
        contactApi ?? _noContactApi(),
      ),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(Role.guardian),
      ),
      privacyControllerProvider.overrideWith(() => controller),
      privacyNowProvider.overrideWithValue(
        () => DateTime.utc(2026, 7, 12, 10, 30),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders one personal privacy control surface', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));

    expect(find.text('Privacy Center'), findsOneWidget);
    expect(find.text('Your privacy'), findsOneWidget);
    expect(
      find.text(
        'You decide who can see your live location, history, and wellness. Guardians cannot change these controls for you.',
      ),
      findsOneWidget,
    );
    expect(find.text('My sharing access'), findsOneWidget);
    expect(
      find.text(
        'Choose what your family circle can see from your account. These controls affect only your data.',
      ),
      findsOneWidget,
    );
    expect(find.text('First Recipient'), findsNothing);
    expect(find.text('Second Recipient'), findsNothing);
    expect(find.text('Live location access'), findsOneWidget);
    expect(find.text('History access'), findsOneWidget);
    expect(find.text('Wellness access'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('temporary-share-circle-custom')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 hour'), findsAtLeastNWidgets(1));
    expect(find.text('4 hours'), findsAtLeastNWidgets(1));
    expect(find.text('8 hours'), findsAtLeastNWidgets(1));
    expect(find.text('Custom'), findsAtLeastNWidgets(1));
    // Regression: the banner used to derive the "total" label by bucketing the
    // *remaining* time, so a 3h30m-left session mislabelled as "Sharing for 1
    // hour". It now shows the true selected total (4 hours) alongside a
    // ceiling-rounded remaining ("4 hours left").
    expect(find.text('Sharing for 4 hours - 4 hours left'), findsOneWidget);
  });

  testWidgets('tapping a toggle calls the privacy controller', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(controller.toggleCallCount, 1);
    expect(controller.lastRecipientId, isNull);
    expect(controller.lastDataType, SharedDataType.liveLocation);
    expect(controller.lastEnabled, isFalse);
  });

  testWidgets('4-hour duration chip updates the current user default', (
    tester,
  ) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('temporary-share-circle-4h')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('temporary-share-circle-4h')));
    await tester.pump();

    expect(controller.temporaryShareCallCount, 1);
    expect(controller.lastRecipientId, isNull);
    expect(controller.lastDataType, SharedDataType.liveLocation);
    expect(controller.lastDuration, const Duration(hours: 4));
  });

  testWidgets('custom duration accepts user-entered hours', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('temporary-share-circle-custom')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('temporary-share-circle-custom')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('custom-duration-field')),
      '6',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Start sharing'));
    await tester.pumpAndSettle();

    expect(controller.temporaryShareCallCount, 1);
    expect(controller.lastRecipientId, isNull);
    expect(controller.lastDataType, SharedDataType.liveLocation);
    expect(controller.lastDuration, const Duration(hours: 6));
  });

  testWidgets('no-circle empty state shows the Guardian create-circle CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_noCircleApp(Role.guardian));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-create-cta')), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsNothing);
  });

  testWidgets('no-circle empty state shows the Member join-circle CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_noCircleApp(Role.member));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-join-cta')), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);
  });

  testWidgets('delete data is confirmation-gated', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.scrollUntilVisible(
      find.text('Delete my data'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();

    expect(find.text('Delete all your location data?'), findsOneWidget);
    expect(
      find.text(
        "This permanently removes your live location, history, and stats from SafePath. Your family won't be able to see past activity anymore. This can't be undone.",
      ),
      findsOneWidget,
    );
    expect(controller.deleteMyDataCallCount, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.deleteMyDataCallCount, 1);
  });

  testWidgets(
    'main path: warning card is absent when an active emergency contact exists',
    (tester) async {
      // _SeededFamilyController seeds the current user as the only Guardian,
      // so with an active contact present this is a has-recipients scenario.
      await tester.pumpWidget(_app(_SpyPrivacyController()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sos-reach-warning')), findsNothing);
    },
  );

  testWidgets(
    'main path: warning card appears when there are no other guardians and no active contacts',
    (tester) async {
      await tester.pumpWidget(
        _app(_SpyPrivacyController(), contactApi: _noContactApi()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sos-reach-warning')), findsOneWidget);
      expect(find.text('SOS would reach no one'), findsOneWidget);
      expect(
        find.text(
          "Your circle has no other guardian, and you haven't added any "
          'emergency contacts. If you trigger SOS right now, nobody would '
          'be notified.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add an emergency contact'), findsOneWidget);
    },
  );

  testWidgets(
    'no-circle path: warning card is absent when an active emergency contact exists',
    (tester) async {
      await tester.pumpWidget(_noCircleApp(Role.guardian));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sos-reach-warning')), findsNothing);
    },
  );

  testWidgets(
    'no-circle path: warning card appears when there are zero active contacts',
    (tester) async {
      await tester.pumpWidget(
        _noCircleApp(Role.guardian, contactApi: _noContactApi()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sos-reach-warning')), findsOneWidget);
      expect(find.text('No circle yet'), findsOneWidget);
    },
  );

  testWidgets(
    "tapping the warning card's CTA navigates to the emergency contacts route",
    (tester) async {
      await tester.pumpWidget(_routerApp(_SpyPrivacyController()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sos-reach-warning')), findsOneWidget);

      await tester.tap(find.text('Add an emergency contact'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Contacts Screen'), findsOneWidget);
    },
  );
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
