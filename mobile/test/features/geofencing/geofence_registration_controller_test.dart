import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/geofencing/application/geofence_registration_controller.dart';
import 'package:mobile/features/geofencing/data/native_geofence_gateway.dart';

class _FakeGateway implements NativeGeofencePlatform {
  _FakeGateway(this.capability);
  NativeGeofenceCapability capability;
  int replaceCallCount = 0;
  List<NativeGeofenceZone> zones = const [];
  Object? capabilityError;
  Object? replacementError;
  @override
  Future<void> acknowledgeCandidate(String eventId) async {}
  @override
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates() async =>
      const [];
  @override
  Future<NativeGeofenceCapability> getCapability() async {
    if (capabilityError case final error?) throw error;
    return capability;
  }

  @override
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> next) async {
    replaceCallCount++;
    if (replacementError case final error?) throw error;
    zones = next;
  }

  @override
  Future<NativeGeofenceCapability> requestBackgroundCapability() async =>
      capability;
}

class _FakeApi implements GeofenceRegistrationApi {
  GeofenceRegistration? registration;
  String? acknowledgedZoneId;
  int? acknowledgedGeneration;
  Object? acknowledgementError;
  @override
  Future<void> acknowledgeRegistration(String zoneId, int generation) async {
    if (acknowledgementError case final error?) throw error;
    acknowledgedZoneId = zoneId;
    acknowledgedGeneration = generation;
  }

  @override
  Future<GeofenceRegistration?> fetchRegistration() async => registration;
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.initial);
  final AuthState initial;
  @override
  AuthState build() => initial;
}

void main() {
  for (final stage in ['capability', 'native-replace', 'acknowledge']) {
    test(
      '$stage failure is contained and diagnostic excludes sensitive details',
      () async {
        final logs = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        addTearDown(() => debugPrint = originalPrint);
        final failure = PlatformException(
          code: 'registration_failed',
          message: 'private-token-and-coordinate',
          details: {'private': 'private-error-details'},
        );
        final platform = _FakeGateway(NativeGeofenceCapability.ready);
        final api = _FakeApi()
          ..registration = const GeofenceRegistration(
            zoneId: 'private-zone-id',
            generation: 2,
            latitude: 30.0444,
            longitude: 31.2357,
            radiusMeters: 100,
          );
        switch (stage) {
          case 'capability':
            platform.capabilityError = failure;
          case 'native-replace':
            platform.replacementError = failure;
          case 'acknowledge':
            api.acknowledgementError = failure;
        }
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthController(const AuthAuthenticated()),
            ),
            nativeGeofencePlatformProvider.overrideWithValue(platform),
            geofenceRegistrationApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        container.read(geofenceRegistrationControllerProvider);
        await _pump();
        expect(
          container.read(geofenceRegistrationControllerProvider),
          isA<GeofenceRegistrationNeedsSync>(),
        );
        expect(api.acknowledgedGeneration, isNull);
        expect(
          logs.join('\n'),
          contains('stage=$stage failed code=registration_failed'),
        );
        for (final sensitive in [
          'private-token-and-coordinate',
          'private-error-details',
          'private-zone-id',
          '30.0444',
          '31.2357',
        ]) {
          expect(logs.join('\n'), isNot(contains(sensitive)));
        }
      },
    );
  }

  test('acknowledges only after native replacement succeeds', () async {
    final platform = _FakeGateway(NativeGeofenceCapability.ready);
    final api = _FakeApi()
      ..registration = const GeofenceRegistration(
        zoneId: 'zone-1',
        generation: 3,
        latitude: 30.0444,
        longitude: 31.2357,
        radiusMeters: 120,
      );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthController(const AuthAuthenticated()),
        ),
        nativeGeofencePlatformProvider.overrideWithValue(platform),
        geofenceRegistrationApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.read(geofenceRegistrationControllerProvider);
    await _pump();
    expect(platform.replaceCallCount, 1);
    expect(api.acknowledgedZoneId, 'zone-1');
    expect(api.acknowledgedGeneration, 3);
    expect(
      container.read(geofenceRegistrationControllerProvider),
      isA<GeofenceRegistrationReady>(),
    );
  });

  test(
    'permission-limited capability never acknowledges the generation',
    () async {
      final platform = _FakeGateway(
        NativeGeofenceCapability.needsLocationPermission,
      );
      final api = _FakeApi()
        ..registration = const GeofenceRegistration(
          zoneId: 'zone-1',
          generation: 3,
          latitude: 30.0444,
          longitude: 31.2357,
          radiusMeters: 120,
        );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(const AuthAuthenticated()),
          ),
          nativeGeofencePlatformProvider.overrideWithValue(platform),
          geofenceRegistrationApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      container.read(geofenceRegistrationControllerProvider);
      await _pump();
      expect(platform.replaceCallCount, 0);
      expect(api.acknowledgedZoneId, isNull);
      expect(
        container.read(geofenceRegistrationControllerProvider),
        isA<GeofenceRegistrationNeedsLocationPermission>(),
      );
    },
  );

  test(
    'logout removes routine monitored zones without SOS integration',
    () async {
      final platform = _FakeGateway(NativeGeofenceCapability.ready);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(const AuthUnauthenticated()),
          ),
          nativeGeofencePlatformProvider.overrideWithValue(platform),
          geofenceRegistrationApiProvider.overrideWithValue(_FakeApi()),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(geofenceRegistrationControllerProvider.notifier)
          .clearOnLogout();
      expect(platform.zones, isEmpty);
      expect(platform.replaceCallCount, 1);
    },
  );
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
