import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
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

class _FakeLocationPermissionService implements LocationPermissionService {
  LocationPermissionStatus checkResult = LocationPermissionStatus.granted;
  LocationPermissionStatus requestResult = LocationPermissionStatus.granted;
  int checkCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkCallCount++;
    return checkResult;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestCallCount++;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCallCount++;
    return true;
  }
}

class _DelayedLiveLocationApi extends FakeLocationApi {
  _DelayedLiveLocationApi(this.completer);

  final Completer<List<LiveLocation>> completer;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) {
    getLiveLocationsCallCount++;
    lastFamilyId = familyId;
    return completer.future;
  }
}

class _FailingOnceLocationApi extends FakeLocationApi {
  bool _shouldFail = true;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) async {
    getLiveLocationsCallCount++;
    lastFamilyId = familyId;
    if (_shouldFail) {
      _shouldFail = false;
      throw LocationApiException(
        LocationApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return liveLocationsToReturn;
  }
}

class _DelayedConnectHubClient extends FakeLocationHubClient {
  _DelayedConnectHubClient(this.connectCompleter);

  final Completer<void> connectCompleter;

  @override
  Future<void> connect(String familyId) async {
    connectCallCount++;
    lastConnectedFamilyId = familyId;
    await connectCompleter.future;
    setState(LocationHubConnectionState.connected);
  }
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
  required _FakeLocationPermissionService permissionService,
  Future<int?>? batteryLevelFuture,
}) {
  return ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      familyApiProvider.overrideWithValue(familyApi),
      locationApiProvider.overrideWithValue(locationApi),
      locationHubClientProvider.overrideWithValue(hubClient),
      positionStreamProvider.overrideWithValue(positionStream),
      locationPermissionServiceProvider.overrideWithValue(permissionService),
      batteryLevelProvider.overrideWith(
        (ref) => batteryLevelFuture ?? Future.value(72),
      ),
    ],
  );
}

void main() {
  group('LiveLocation profile fields', () {
    test('fromJson parses profileImageUrl and profileUpdatedAt', () {
      final location = LiveLocation.fromJson({
        'userId': 'member-2',
        'lat': 29.9,
        'lng': 31.1,
        'accuracyMeters': 12,
        'recordedAtUtc': '2026-07-12T11:00:00Z',
        'profileImageUrl': 'https://example.com/avatar.jpg',
        'profileUpdatedAt': '2026-07-12T10:00:00Z',
      });

      expect(location.profileImageUrl, 'https://example.com/avatar.jpg');
      expect(location.profileUpdatedAt, DateTime.utc(2026, 7, 12, 10));
    });

    test('fromJson tolerates missing profile fields', () {
      final location = LiveLocation.fromJson({
        'userId': 'member-2',
        'lat': 29.9,
        'lng': 31.1,
        'accuracyMeters': 12,
        'recordedAtUtc': '2026-07-12T11:00:00Z',
      });

      expect(location.profileImageUrl, isNull);
      expect(location.profileUpdatedAt, isNull);
    });

    test('copyWith carries profileImageUrl/profileUpdatedAt forward', () {
      final base = LiveLocation(
        userId: 'member-2',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/avatar.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 10),
      );

      final moved = base.copyWith(lat: 30.0);

      expect(moved.profileImageUrl, 'https://example.com/avatar.jpg');
      expect(moved.profileUpdatedAt, DateTime.utc(2026, 7, 12, 10));
    });

    test('copyWith clearProfileImage clears both avatar fields', () {
      final base = LiveLocation(
        userId: 'member-2',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/avatar.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 10),
      );

      final cleared = base.copyWith(clearProfileImage: true);

      expect(cleared.profileImageUrl, isNull);
      expect(cleared.profileUpdatedAt, isNull);
    });
  });

  group('ProfileUpdate', () {
    test('fromJson parses userId/displayName/profileImageUrl', () {
      final update = ProfileUpdate.fromJson({
        'userId': 'member-2',
        'displayName': 'Sam Rivera',
        'profileImageUrl': 'https://example.com/avatar.jpg',
      });

      expect(update.userId, 'member-2');
      expect(update.displayName, 'Sam Rivera');
      expect(update.profileImageUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson tolerates null displayName/profileImageUrl', () {
      final update = ProfileUpdate.fromJson({'userId': 'member-2'});

      expect(update.userId, 'member-2');
      expect(update.displayName, isNull);
      expect(update.profileImageUrl, isNull);
    });
  });

  late StreamController<Position> positions;
  late _FakeAuthApi authApi;
  late FakeFamilyApi familyApi;
  late FakeLocationApi locationApi;
  late FakeLocationHubClient hubClient;
  late _FakeLocationPermissionService permissionService;
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
    permissionService = _FakeLocationPermissionService();
    container = _container(
      authApi: authApi,
      familyApi: familyApi,
      locationApi: locationApi,
      hubClient: hubClient,
      positionStream: positions.stream,
      permissionService: permissionService,
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

  // Regression for F-01: battery percent only refreshed inside
  // _reportPosition(), which only fires on new GPS fixes from
  // positionStreamProvider (distanceFilter: 10). A stationary device never
  // emits a new fix, so the periodic battery-refresh timer must be able to
  // re-trigger the same report flow using the last known position.
  test(
    'periodically refreshes battery and re-reports the last known position '
    'without a new GPS fix (F-01)',
    () {
      fakeAsync((async) {
        container.read(locationControllerProvider);
        async.flushMicrotasks();

        final recordedAt = DateTime.utc(2026, 7, 12, 10, 30);
        positions.add(
          _position(lat: 30.0444, lng: 31.2357, timestamp: recordedAt),
        );
        async.flushMicrotasks();

        expect(hubClient.reportLocationCallCount, 1);

        // Advance the fake clock past the refresh interval WITHOUT emitting
        // a new position fix — only the periodic timer should trigger this.
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();

        expect(hubClient.reportLocationCallCount, 2);
        expect(hubClient.lastReportedLocation?.latitude, 30.0444);
        expect(hubClient.lastReportedLocation?.longitude, 31.2357);
        expect(hubClient.lastReportedLocation?.batteryPercent, 72);
      });
    },
  );

  test(
    'does not fire a battery refresh before any position has ever been '
    'reported (F-01)',
    () {
      fakeAsync((async) {
        container.read(locationControllerProvider);
        async.flushMicrotasks();

        expect(hubClient.reportLocationCallCount, 0);

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();

        // No last-known position yet -> the timer callback is a no-op.
        expect(hubClient.reportLocationCallCount, 0);
      });
    },
  );

  test(
    'cancels the periodic battery-refresh timer on disconnect (no lingering '
    'callback after teardown) (F-01)',
    () {
      fakeAsync((async) {
        container.read(locationControllerProvider);
        async.flushMicrotasks();

        positions.add(
          _position(
            lat: 30.0444,
            lng: 31.2357,
            timestamp: DateTime.utc(2026, 7, 12, 10, 30),
          ),
        );
        async.flushMicrotasks();
        expect(hubClient.reportLocationCallCount, 1);

        authApi.signOut();
        async.flushMicrotasks();

        // If the timer were still alive, elapsing well past the interval
        // would produce another report.
        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();

        expect(hubClient.reportLocationCallCount, 1);
      });
    },
  );

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

  test('initial live-locations snapshot carries profileImageUrl', () async {
    locationApi.liveLocationsToReturn = [
      LiveLocation(
        userId: 'self-user',
        lat: 30.0444,
        lng: 31.2357,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
        profileImageUrl: 'https://example.com/self.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
      ),
    ];
    container.read(locationControllerProvider);
    await pumpEventQueue();

    final state = container.read(locationControllerProvider).value!;
    expect(
      state.members['self-user']?.profileImageUrl,
      'https://example.com/self.jpg',
    );
    expect(state.selfPosition?.profileImageUrl, 'https://example.com/self.jpg');
  });

  test(
    'cold-start bootstrap threads profileUpdatedAt into selfPosition and family markers',
    () async {
      locationApi.liveLocationsToReturn = [
        LiveLocation(
          userId: 'self-user',
          lat: 30.0444,
          lng: 31.2357,
          accuracyMeters: 10,
          recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
          profileImageUrl: 'https://example.com/self.jpg',
          profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
        ),
        LiveLocation(
          userId: 'member-2',
          lat: 29.9,
          lng: 31.1,
          accuracyMeters: 12,
          recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
          profileImageUrl: 'https://example.com/member-2.jpg',
          profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
        ),
      ];

      container.read(locationControllerProvider);
      await pumpEventQueue();

      final state = container.read(locationControllerProvider).value!;
      expect(
        state.selfPosition?.profileUpdatedAt,
        DateTime.utc(2026, 7, 12, 9),
      );
      expect(
        state.members['member-2']?.profileUpdatedAt,
        DateTime.utc(2026, 7, 12, 8),
      );
    },
  );

  // Regression for bug: avatar-persist-after-refresh. A routine location tick
  // (self foreground fix or a member's hub LocationUpdated) carries no
  // profile-image fields, so the _applyLocation merge must NOT null the avatar
  // that the cold-start /live-locations bootstrap just seeded — otherwise the
  // avatar "reverts to default" on the first tick after a refresh/cold start.
  test(
    'self avatar survives a foreground position tick (refresh does not null the image URL)',
    () async {
      locationApi.liveLocationsToReturn = [
        LiveLocation(
          userId: 'self-user',
          lat: 30.0444,
          lng: 31.2357,
          accuracyMeters: 10,
          recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
          profileImageUrl: 'https://example.com/self.jpg',
          profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
        ),
      ];

      container.read(locationControllerProvider);
      await pumpEventQueue();

      // A foreground fix from the position stream — no image fields, exactly
      // like the real geolocator payload built in _reportPosition.
      positions.add(
        _position(
          lat: 30.05,
          lng: 31.24,
          timestamp: DateTime.utc(2026, 7, 12, 10, 30),
        ),
      );
      await pumpEventQueue();

      final state = container.read(locationControllerProvider).value!;
      expect(state.selfPosition?.lat, 30.05); // position advanced
      expect(
        state.selfPosition?.profileImageUrl,
        'https://example.com/self.jpg',
      );
      expect(state.selfPosition?.profileUpdatedAt, DateTime.utc(2026, 7, 12, 9));
      expect(
        state.members['self-user']?.profileImageUrl,
        'https://example.com/self.jpg',
      );
    },
  );

  test('member avatar survives a hub LocationUpdated tick', () async {
    locationApi.liveLocationsToReturn = [
      LiveLocation(
        userId: 'self-user',
        lat: 30.0444,
        lng: 31.2357,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 10),
      ),
      LiveLocation(
        userId: 'member-2',
        displayName: 'Sam Rivera',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/member-2.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
      ),
    ];

    container.read(locationControllerProvider);
    await pumpEventQueue();

    // A member's routine ping carries only position/battery (LocationUpdateDto).
    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-2',
        lat: 29.95,
        lng: 31.15,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11, 5),
        batteryPercent: 60,
      ),
    );
    await pumpEventQueue();

    final member = container
        .read(locationControllerProvider)
        .value!
        .members['member-2']!;
    expect(member.lat, 29.95); // position advanced
    expect(member.batteryPercent, 60);
    expect(member.displayName, 'Sam Rivera'); // seeded name retained
    expect(member.profileImageUrl, 'https://example.com/member-2.jpg');
    expect(member.profileUpdatedAt, DateTime.utc(2026, 7, 12, 8));
  });

  test('multiple members retain their own avatars across location ticks', () async {
    locationApi.liveLocationsToReturn = [
      LiveLocation(
        userId: 'member-a',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/a.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
      ),
      LiveLocation(
        userId: 'member-b',
        lat: 29.8,
        lng: 31.0,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/b.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 7),
      ),
    ];

    container.read(locationControllerProvider);
    await pumpEventQueue();

    // Only member-a pings — member-b must keep its own distinct avatar.
    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-a',
        lat: 29.95,
        lng: 31.15,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11, 5),
      ),
    );
    await pumpEventQueue();

    final members = container.read(locationControllerProvider).value!.members;
    expect(members['member-a']?.profileImageUrl, 'https://example.com/a.jpg');
    expect(members['member-b']?.profileImageUrl, 'https://example.com/b.jpg');
  });

  test('a removed photo stays cleared across a later location tick', () async {
    locationApi.liveLocationsToReturn = [
      LiveLocation(
        userId: 'member-2',
        lat: 29.9,
        lng: 31.1,
        accuracyMeters: 12,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
        profileImageUrl: 'https://example.com/member-2.jpg',
        profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
      ),
    ];

    container.read(locationControllerProvider);
    await pumpEventQueue();

    // Photo removed via the profile channel (clearProfileImage path).
    hubClient.emitProfileUpdate(
      const ProfileUpdate(userId: 'member-2', profileImageUrl: null),
    );
    await pumpEventQueue();
    expect(
      container
          .read(locationControllerProvider)
          .value!
          .members['member-2']
          ?.profileImageUrl,
      isNull,
    );

    // A later location tick must NOT resurrect the removed photo.
    hubClient.emitLocation(
      LiveLocation(
        userId: 'member-2',
        lat: 29.95,
        lng: 31.15,
        accuracyMeters: 10,
        recordedAtUtc: DateTime.utc(2026, 7, 12, 11, 5),
      ),
    );
    await pumpEventQueue();

    expect(
      container
          .read(locationControllerProvider)
          .value!
          .members['member-2']
          ?.profileImageUrl,
      isNull,
    );
  });

  test(
    'ProfileUpdated merges name/avatar without disturbing position or presence',
    () async {
      container.read(locationControllerProvider);
      await pumpEventQueue();

      hubClient.emitLocation(
        LiveLocation(
          userId: 'member-2',
          displayName: 'Old Name',
          lat: 29.9,
          lng: 31.1,
          accuracyMeters: 12,
          recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
          batteryPercent: 51,
        ),
      );
      hubClient.emitPresence(
        PresenceChange(userId: 'member-2', isOnline: true),
      );
      await pumpEventQueue();

      hubClient.emitProfileUpdate(
        const ProfileUpdate(
          userId: 'member-2',
          displayName: 'New Name',
          profileImageUrl: 'https://example.com/member-2.jpg',
        ),
      );
      await pumpEventQueue();

      final state = container.read(locationControllerProvider).value!;
      final member = state.members['member-2']!;
      expect(member.displayName, 'New Name');
      expect(member.profileImageUrl, 'https://example.com/member-2.jpg');
      // Position/presence must be untouched by the profile-only merge.
      expect(member.lat, 29.9);
      expect(member.lng, 31.1);
      expect(state.isMemberOnline('member-2'), isTrue);
    },
  );

  test(
    'ProfileUpdated with a null profileImageUrl clears the avatar',
    () async {
      container.read(locationControllerProvider);
      await pumpEventQueue();

      hubClient.emitLocation(
        LiveLocation(
          userId: 'member-2',
          lat: 29.9,
          lng: 31.1,
          accuracyMeters: 12,
          recordedAtUtc: DateTime.utc(2026, 7, 12, 11),
          profileImageUrl: 'https://example.com/member-2.jpg',
          profileUpdatedAt: DateTime.utc(2026, 7, 12, 10),
        ),
      );
      await pumpEventQueue();
      expect(
        container
            .read(locationControllerProvider)
            .value!
            .members['member-2']
            ?.profileImageUrl,
        isNotNull,
      );

      hubClient.emitProfileUpdate(
        const ProfileUpdate(userId: 'member-2', profileImageUrl: null),
      );
      await pumpEventQueue();

      final member = container
          .read(locationControllerProvider)
          .value!
          .members['member-2']!;
      expect(member.profileImageUrl, isNull);
    },
  );

  test(
    'ProfileUpdated for a not-yet-seen member is safely ignored',
    () async {
      container.read(locationControllerProvider);
      await pumpEventQueue();

      hubClient.emitProfileUpdate(
        const ProfileUpdate(
          userId: 'unknown-member',
          displayName: 'Ghost',
          profileImageUrl: 'https://example.com/ghost.jpg',
        ),
      );
      await pumpEventQueue();

      final state = container.read(locationControllerProvider).value!;
      expect(state.members.containsKey('unknown-member'), isFalse);
    },
  );

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

  test(
    'does not connect, fetch live locations, or stream positions before permission is granted',
    () async {
      permissionService.checkResult = LocationPermissionStatus.denied;
      permissionService.requestResult = LocationPermissionStatus.granted;

      container.read(permissionControllerProvider);
      container.read(locationControllerProvider);
      await pumpEventQueue();

      final deniedAt = DateTime.utc(2026, 7, 12, 12);
      positions.add(_position(lat: 30.05, lng: 31.24, timestamp: deniedAt));
      await pumpEventQueue();

      expect(locationApi.getLiveLocationsCallCount, 0);
      expect(hubClient.connectCallCount, 0);
      expect(hubClient.reportLocationCallCount, 0);
      expect(
        container.read(locationControllerProvider).value?.members,
        isEmpty,
      );

      await container
          .read(permissionControllerProvider.notifier)
          .requestPermission();
      await pumpEventQueue();

      expect(hubClient.connectCallCount, 1);
      expect(locationApi.getLiveLocationsCallCount, 1);

      final grantedAt = DateTime.utc(2026, 7, 12, 12, 5);
      positions.add(_position(lat: 30.06, lng: 31.25, timestamp: grantedAt));
      await pumpEventQueue();

      expect(hubClient.reportLocationCallCount, 1);
      expect(hubClient.lastReportedLocation?.latitude, 30.06);
    },
  );

  test('does not connect if auth changes while live locations load', () async {
    final liveLocationsCompleter = Completer<List<LiveLocation>>();
    locationApi = _DelayedLiveLocationApi(liveLocationsCompleter);
    container.dispose();
    container = _container(
      authApi: authApi,
      familyApi: familyApi,
      locationApi: locationApi,
      hubClient: hubClient,
      positionStream: positions.stream,
      permissionService: permissionService,
    );

    container.read(permissionControllerProvider);
    container.read(locationControllerProvider);
    await pumpEventQueue();

    expect(locationApi.getLiveLocationsCallCount, 1);

    authApi.signOut();
    liveLocationsCompleter.complete(const []);
    await pumpEventQueue();

    expect(hubClient.connectCallCount, 0);
    expect(hubClient.reportLocationCallCount, 0);
    expect(container.read(locationControllerProvider).value?.members, isEmpty);
  });

  test('does not report an in-flight position after sign-out', () async {
    final batteryCompleter = Completer<int?>();
    container.dispose();
    container = _container(
      authApi: authApi,
      familyApi: familyApi,
      locationApi: locationApi,
      hubClient: hubClient,
      positionStream: positions.stream,
      permissionService: permissionService,
      batteryLevelFuture: batteryCompleter.future,
    );

    container.read(locationControllerProvider);
    await pumpEventQueue();

    expect(hubClient.connectCallCount, 1);

    positions.add(
      _position(
        lat: 30.07,
        lng: 31.26,
        timestamp: DateTime.utc(2026, 7, 12, 12, 10),
      ),
    );
    await pumpEventQueue();

    authApi.signOut();
    batteryCompleter.complete(44);
    await pumpEventQueue();

    expect(hubClient.reportLocationCallCount, 0);
  });

  test(
    'does not report an in-flight position after permission is revoked',
    () async {
      final batteryCompleter = Completer<int?>();
      container.dispose();
      container = _container(
        authApi: authApi,
        familyApi: familyApi,
        locationApi: locationApi,
        hubClient: hubClient,
        positionStream: positions.stream,
        permissionService: permissionService,
        batteryLevelFuture: batteryCompleter.future,
      );

      container.read(permissionControllerProvider);
      container.read(locationControllerProvider);
      await pumpEventQueue();

      expect(hubClient.connectCallCount, 1);

      positions.add(
        _position(
          lat: 30.08,
          lng: 31.27,
          timestamp: DateTime.utc(2026, 7, 12, 12, 15),
        ),
      );
      await pumpEventQueue();

      permissionService.checkResult = LocationPermissionStatus.denied;
      await container
          .read(permissionControllerProvider.notifier)
          .checkPermission();
      batteryCompleter.complete(44);
      await pumpEventQueue();

      expect(hubClient.reportLocationCallCount, 0);
    },
  );

  test(
    'disconnects a stale hub connect that finishes after sign-out',
    () async {
      final connectCompleter = Completer<void>();
      final delayedHubClient = _DelayedConnectHubClient(connectCompleter);
      hubClient = delayedHubClient;
      container.dispose();
      container = _container(
        authApi: authApi,
        familyApi: familyApi,
        locationApi: locationApi,
        hubClient: hubClient,
        positionStream: positions.stream,
        permissionService: permissionService,
      );

      container.read(locationControllerProvider);
      await pumpEventQueue();

      expect(hubClient.connectCallCount, 1);

      authApi.signOut();
      connectCompleter.complete();
      await pumpEventQueue();

      expect(hubClient.disconnectCallCount, greaterThanOrEqualTo(1));
      expect(hubClient.state, LocationHubConnectionState.disconnected);

      positions.add(
        _position(
          lat: 30.09,
          lng: 31.28,
          timestamp: DateTime.utc(2026, 7, 12, 12, 20),
        ),
      );
      await pumpEventQueue();

      expect(hubClient.reportLocationCallCount, 0);
    },
  );

  test(
    'retries the same family after a failed live location bootstrap',
    () async {
      final failingOnceApi = _FailingOnceLocationApi();
      locationApi = failingOnceApi;
      container.dispose();
      container = _container(
        authApi: authApi,
        familyApi: familyApi,
        locationApi: locationApi,
        hubClient: hubClient,
        positionStream: positions.stream,
        permissionService: permissionService,
      );

      container.read(permissionControllerProvider);
      container.read(locationControllerProvider);
      await pumpEventQueue();

      expect(locationApi.getLiveLocationsCallCount, 1);
      expect(hubClient.connectCallCount, 0);
      expect(
        container.read(locationControllerProvider).value?.error,
        "Couldn't connect. Check your connection and try again.",
      );

      await container
          .read(permissionControllerProvider.notifier)
          .checkPermission();
      await pumpEventQueue();

      expect(locationApi.getLiveLocationsCallCount, 2);
      expect(hubClient.connectCallCount, 1);
    },
  );
}
