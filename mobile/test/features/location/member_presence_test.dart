import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/data/location_api.dart';
import 'package:mobile/features/location/data/location_hub_client.dart';
import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/member_detail_sheet.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_location_api.dart';
import '../../helpers/fake_location_hub_client.dart';

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({required this.sessionOverride});

  sb.Session? sessionOverride;
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  void dispose() => _controller.close();

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> updateRoleMetadata(Role role) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() => throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
}

sb.Session _session({String userId = 'self-user'}) {
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

ProviderContainer _container({
  required _FakeAuthApi authApi,
  required FakeFamilyApi familyApi,
  required FakeLocationApi locationApi,
  required FakeLocationHubClient hubClient,
}) {
  return ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      familyApiProvider.overrideWithValue(familyApi),
      locationApiProvider.overrideWithValue(locationApi),
      locationHubClientProvider.overrideWithValue(hubClient),
      positionStreamProvider.overrideWithValue(const Stream<Position>.empty()),
      batteryLevelProvider.overrideWith((ref) async => 72),
    ],
  );
}

void main() {
  late _FakeAuthApi authApi;
  late FakeFamilyApi familyApi;
  late FakeLocationApi locationApi;
  late FakeLocationHubClient hubClient;
  late ProviderContainer container;

  setUp(() {
    authApi = _FakeAuthApi(sessionOverride: _session());
    familyApi = FakeFamilyApi()
      ..myFamiliesToReturn = const [
        MyFamily(
          familyId: 'fam-1',
          familyName: 'Safe circle',
          role: Role.guardian,
          permissions: PermissionLevel.fullLocation,
        ),
      ]
      ..membersByFamilyId['fam-1'] = [
        FamilyMemberView(
          memberId: 'mem-2',
          userId: 'member-2',
          role: Role.member,
          permission: PermissionLevel.fullLocation,
          joinedAt: DateTime.utc(2026, 7, 12),
        ),
      ];
    locationApi = FakeLocationApi();
    hubClient = FakeLocationHubClient();
    container = _container(
      authApi: authApi,
      familyApi: familyApi,
      locationApi: locationApi,
      hubClient: hubClient,
    );
  });

  tearDown(() {
    container.dispose();
    authApi.dispose();
    hubClient.dispose();
  });

  test(
    'presence changes flip online status without removing the last pin',
    () async {
      container.read(locationControllerProvider);
      await pumpEventQueue();

      final recordedAt = DateTime.utc(2026, 7, 12, 10);
      hubClient.emitLocation(
        LiveLocation(
          userId: 'member-2',
          displayName: 'Maya',
          lat: 29.9,
          lng: 31.1,
          accuracyMeters: 12,
          recordedAtUtc: recordedAt,
        ),
      );
      hubClient.emitPresence(
        const PresenceChange(userId: 'member-2', isOnline: false),
      );
      await pumpEventQueue();

      final state = container.read(locationControllerProvider).value!;
      expect(state.memberPresence['member-2']?.isOnline, isFalse);
      expect(state.members['member-2']?.recordedAtUtc, recordedAt);
    },
  );

  test('last seen text tracks the newest location ping', () async {
    container.read(locationControllerProvider);
    await pumpEventQueue();

    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-2',
        displayName: 'Maya',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
      ),
    );
    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-2',
        displayName: 'Maya',
        lat: 29.91,
        lng: 31.11,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 10, 10),
      ),
    );
    await pumpEventQueue();

    final location = container
        .read(locationControllerProvider)
        .value!
        .members['member-2']!;
    expect(location.recordedAtUtc, DateTime.utc(2026, 7, 12, 10, 10));
    expect(
      lastSeenText(
        location.recordedAtUtc,
        now: DateTime.utc(2026, 7, 12, 10, 14),
      ),
      'Last seen 4 min ago',
    );
  });

  testWidgets('member detail sheet shows name, status badge, and last seen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMemberDetailSheet(
              context,
              member: MemberDetail(
                name: 'Maya',
                isOnline: false,
                recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
              ),
              now: DateTime.utc(2026, 7, 12, 10, 8),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Last seen 8 min ago'), findsOneWidget);
  });
}
