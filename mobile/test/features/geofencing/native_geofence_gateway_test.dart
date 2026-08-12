import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/data/native_geofence_gateway.dart';

class _FakePlatform implements NativeGeofencePlatform {
  NativeGeofenceCapability capability = NativeGeofenceCapability.ready;
  List<NativeGeofenceZone> replacedWith = const [];
  final pending = <NativeGeofenceCandidate>[];
  String? acknowledgedEventId;

  @override
  Future<void> acknowledgeCandidate(String eventId) async {
    acknowledgedEventId = eventId;
    pending.removeWhere((candidate) => candidate.eventId == eventId);
  }

  @override
  Future<NativeGeofenceCapability> getCapability() async => capability;

  @override
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates() async =>
      List.unmodifiable(pending);

  @override
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> zones) async {
    replacedWith = List.unmodifiable(zones);
  }

  @override
  Future<NativeGeofenceCapability> requestBackgroundCapability() async =>
      capability;
}

void main() {
  test('replaces the canonical set and drains only durable candidates', () async {
    final platform = _FakePlatform()
      ..pending.add(
        NativeGeofenceCandidate(
          eventId: 'event-1',
          requestId: 'zone-1:7',
          transition: NativeGeofenceTransition.enter,
          occurredAtUtc: DateTime.utc(2026, 8, 12),
          latitude: 30.0444,
          longitude: 31.2357,
          accuracyMeters: 12,
        ),
      );
    final gateway = NativeGeofenceGateway(platform);

    await gateway.replaceMonitoredZones([
      const NativeGeofenceZone(
        zoneId: 'zone-1',
        generation: 7,
        latitude: 30.0444,
        longitude: 31.2357,
        radiusMeters: 120,
      ),
    ]);

    expect(platform.replacedWith, hasLength(1));
    expect((await gateway.drainPendingCandidates()).single.eventId, 'event-1');
    await gateway.acknowledgeCandidate('event-1');
    expect(platform.acknowledgedEventId, 'event-1');
    expect(await gateway.drainPendingCandidates(), isEmpty);
  });

  test('enforces the cross-platform 20-zone registration budget', () async {
    final gateway = NativeGeofenceGateway(_FakePlatform());
    final zones = List.generate(
      21,
      (index) => NativeGeofenceZone(
        zoneId: 'zone-$index',
        generation: 1,
        latitude: 30,
        longitude: 31,
        radiusMeters: 100,
      ),
    );

    await expectLater(
      gateway.replaceMonitoredZones(zones),
      throwsA(isA<GeofenceRegistrationException>()),
    );
  });
}
