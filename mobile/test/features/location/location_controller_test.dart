import 'dart:async';

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
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_location_api.dart';
import '../../helpers/fake_location_hub_client.dart';

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({this.sessionOverride});

  sb.Session? sessionOverride;
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  void signOut() {
    sessionOverride = null;
    _controller.add(sb.AuthState(sb.AuthChangeEvent.signedOut, null));
  }

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

Position _position({
  required double lat,
  required double lng,
  required DateTime timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
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
  required Stream<Position> positionStream,
}) {
  return ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      familyApiProvider.overrideWithValue(familyApi),
      locationApiProvider.overrideWithValue(locationApi),
      locationHubClientProvider.overrideWithValue(hubClient),
      positionStreamProvider.overrideWithValue(positionStream),
      batteryLevelProvider.overrideWith((ref) async => 72),
    ],
  );
}

void main() {
  late StreamController<Position> positions;
  late _FakeAuthApi authApi;
  late FakeFamilyApi familyApi;
  late FakeLocationApi locationApi;
  late FakeLocationHubClient hubClient;
  late ProviderContainer container;

  setUp(() {
    positions = StreamController<Position>.broadcast();
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
          memberId: 'mem-self',
          userId: 'self-user',
          role: Role.guardian,
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
      positionStream: positions.stream,
    );
  });

  tearDown(() async {
    container.dispose();
    authApi.dispose();
    hubClient.dispose();
    await positions.close();
  });

  test('reports foreground position fixes and updates the self pin', () async {
    container.read(locationControllerProvider);
    await pumpEventQueue();

    final recordedAt = DateTime.utc(2026, 7, 12, 10, 30);
    positions.add(_position(lat: 30.0444, lng: 31.2357, timestamp: recordedAt));
    await pumpEventQueue();

    expect(hubClient.reportLocationCallCount, 1);
    expect(hubClient.lastReportedLocation?.latitude, 30.0444);
    expect(hubClient.lastReportedLocation?.longitude, 31.2357);
    expect(hubClient.lastReportedLocation?.batteryPercent, 72);

    final state = container.read(locationControllerProvider).value!;
    expect(state.selfPosition?.lat, 30.0444);
    expect(state.selfPosition?.lng, 31.2357);
    expect(state.members['self-user']?.lat, 30.0444);
  });

  test('updates family member pins from hub LocationUpdated events', () async {
    container.read(locationControllerProvider);
    await pumpEventQueue();

    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-2',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        batteryPercent: 51,
      ),
    );
    await pumpEventQueue();

    final state = container.read(locationControllerProvider).value!;
    expect(state.members['member-2']?.lat, 29.9);
    expect(state.members['member-2']?.batteryPercent, 51);
  });

  test(
    'connects only for auth plus family and disconnects on sign-out',
    () async {
      container.read(locationControllerProvider);
      await pumpEventQueue();

      expect(hubClient.connectCallCount, 1);
      expect(hubClient.lastConnectedFamilyId, 'fam-1');

      authApi.signOut();
      await pumpEventQueue();

      expect(hubClient.disconnectCallCount, greaterThanOrEqualTo(1));
      expect(
        container.read(locationControllerProvider).value?.members,
        isEmpty,
      );
    },
  );
}
