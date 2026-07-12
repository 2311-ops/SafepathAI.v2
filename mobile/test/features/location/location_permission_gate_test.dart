import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/location/data/location_api.dart';
import 'package:mobile/features/location/data/location_hub_client.dart';
import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/profile/data/profile_api.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_location_api.dart';
import '../../helpers/fake_location_hub_client.dart';
import '../../helpers/fake_privacy_api.dart';
import '../../helpers/fake_profile_api.dart';

class _FakeLocationPermissionService implements LocationPermissionService {
  _FakeLocationPermissionService({required this.status});

  LocationPermissionStatus status;
  int checkCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkCallCount++;
    return status;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestCallCount++;
    return status;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCallCount++;
    return true;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'cold signed-in /home with unknown permission reaches priming before MainShell',
    (tester) async {
      final permissionService = _FakeLocationPermissionService(
        status: LocationPermissionStatus.unknown,
      );
      final harness = _RouterHarness(permissionService: permissionService);
      addTearDown(harness.dispose);

      await harness.pump(tester);
      harness.router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('Let your family see you are safe'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Your family, live'), findsNothing);
      expect(permissionService.requestCallCount, 0);
      expect(harness.hubClient.connectCallCount, 0);
      expect(harness.locationApi.getLiveLocationsCallCount, 0);
    },
  );

  testWidgets(
    'cold signed-in /home with denied permission reaches priming before MainShell',
    (tester) async {
      final permissionService = _FakeLocationPermissionService(
        status: LocationPermissionStatus.denied,
      );
      final harness = _RouterHarness(permissionService: permissionService);
      addTearDown(harness.dispose);

      await harness.pump(tester);
      harness.router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('Let your family see you are safe'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Your family, live'), findsNothing);
      expect(permissionService.requestCallCount, 0);
      expect(harness.hubClient.connectCallCount, 0);
      expect(harness.locationApi.getLiveLocationsCallCount, 0);
    },
  );

  testWidgets('cold signed-in /home with granted permission renders MainShell', (
    tester,
  ) async {
    final permissionService = _FakeLocationPermissionService(
      status: LocationPermissionStatus.granted,
    );
    final harness = _RouterHarness(permissionService: permissionService);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    harness.router.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Let your family see you are safe'), findsNothing);
  });
}

class _RouterHarness {
  _RouterHarness({required this.permissionService})
    : authApi = FakeAuthApi(initialSession: _session()),
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
            joinedAt: DateTime.utc(2026, 7, 13),
          ),
        ];

  final _FakeLocationPermissionService permissionService;
  final FakeAuthApi authApi;
  final FakeFamilyApi familyApi;
  final FakeProfileApi profileApi = FakeProfileApi(userId: 'self-user');
  final FakeLocationApi locationApi = FakeLocationApi();
  final FakeLocationHubClient hubClient = FakeLocationHubClient();
  final FakePrivacyApi privacyApi = FakePrivacyApi();
  final StreamController<Position> positions =
      StreamController<Position>.broadcast();

  late final ProviderContainer container = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      familyApiProvider.overrideWithValue(familyApi),
      profileApiProvider.overrideWithValue(profileApi),
      locationPermissionServiceProvider.overrideWithValue(permissionService),
      locationApiProvider.overrideWithValue(locationApi),
      locationHubClientProvider.overrideWithValue(hubClient),
      positionStreamProvider.overrideWithValue(positions.stream),
      batteryLevelProvider.overrideWith((ref) async => 72),
      privacyApiProvider.overrideWithValue(privacyApi),
    ],
  );

  late final router = container.read(routerProvider);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  void dispose() {
    container.dispose();
    authApi.dispose();
    hubClient.dispose();
    positions.close();
  }
}

sb.Session _session() => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: 'self-user',
    appMetadata: const {},
    userMetadata: const {'role': 'guardian'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);
