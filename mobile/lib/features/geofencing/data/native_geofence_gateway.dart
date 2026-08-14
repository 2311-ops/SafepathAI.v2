import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

const int geofenceZoneLimit = 20;
const int nativeGeofenceNotAvailableErrorCode = 1000;

enum NativeGeofenceCapability {
  ready,
  needsLocationPermission,
  needsBackgroundPermission,
  unavailable,
}

enum NativeGeofenceTransition { enter, exit, error }

class GeofenceRegistrationException implements Exception {
  const GeofenceRegistrationException(this.message);
  final String message;
  @override
  String toString() => 'GeofenceRegistrationException: $message';
}

class NativeGeofenceZone {
  const NativeGeofenceZone({
    required this.zoneId,
    required this.generation,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String zoneId;
  final int generation;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  String get requestId => '$zoneId:$generation';

  Map<String, Object> toMap() => {
    'zoneId': zoneId,
    'generation': generation,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };
}

class NativeGeofenceCandidate {
  const NativeGeofenceCandidate({
    required this.eventId,
    required this.requestId,
    required this.transition,
    required this.occurredAtUtc,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.errorCode,
  });

  final String eventId;
  final String requestId;
  final NativeGeofenceTransition transition;
  final DateTime occurredAtUtc;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final int? errorCode;

  /// Android's GEOFENCE_NOT_AVAILABLE is an OS recovery signal, not a
  /// transition that the authenticated candidate API can submit. Native code
  /// records a canonical re-sync marker and waits for the normal auth restore.
  bool get requiresCanonicalResync =>
      transition == NativeGeofenceTransition.error &&
      errorCode == nativeGeofenceNotAvailableErrorCode;

  factory NativeGeofenceCandidate.fromMap(Map<Object?, Object?> map) {
    final transition = switch (map['transition']) {
      'enter' => NativeGeofenceTransition.enter,
      'exit' => NativeGeofenceTransition.exit,
      _ => NativeGeofenceTransition.error,
    };
    return NativeGeofenceCandidate(
      eventId: map['eventId']! as String,
      requestId: map['requestId']! as String,
      transition: transition,
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['occurredAtEpochMs']! as int,
        isUtc: true,
      ),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      errorCode: (map['errorCode'] as num?)?.toInt(),
    );
  }
}

abstract class NativeGeofencePlatform {
  Future<NativeGeofenceCapability> getCapability();
  Future<NativeGeofenceCapability> requestBackgroundCapability();
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> zones);
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates();
  Future<void> acknowledgeCandidate(String eventId);
}

class MethodChannelNativeGeofencePlatform implements NativeGeofencePlatform {
  const MethodChannelNativeGeofencePlatform(this._channel);
  final MethodChannel _channel;

  @override
  Future<void> acknowledgeCandidate(String eventId) =>
      _channel.invokeMethod<void>('acknowledgeCandidate', {'eventId': eventId});

  @override
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates() async {
    final raw = await _channel.invokeMethod<List<Object?>>(
      'drainPendingCandidates',
    );
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (entry) => NativeGeofenceCandidate.fromMap(
            Map<Object?, Object?>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<NativeGeofenceCapability> getCapability() =>
      _capability('getCapability');

  @override
  Future<NativeGeofenceCapability> requestBackgroundCapability() =>
      _capability('requestBackgroundCapability');

  Future<NativeGeofenceCapability> _capability(String method) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(method);
    return _parseCapability(raw?['status']);
  }

  @override
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> zones) =>
      _channel.invokeMethod<void>('replaceMonitoredZones', {
        'zones': zones.map((zone) => zone.toMap()).toList(growable: false),
      });

  NativeGeofenceCapability _parseCapability(Object? value) => switch (value) {
    'ready' => NativeGeofenceCapability.ready,
    'needsLocationPermission' =>
      NativeGeofenceCapability.needsLocationPermission,
    'needsBackgroundPermission' =>
      NativeGeofenceCapability.needsBackgroundPermission,
    _ => NativeGeofenceCapability.unavailable,
  };
}

final nativeGeofencePlatformProvider = Provider<NativeGeofencePlatform>(
  (ref) => const MethodChannelNativeGeofencePlatform(
    MethodChannel('safepath/geofencing'),
  ),
);

class NativeGeofenceGateway implements NativeGeofencePlatform {
  NativeGeofenceGateway(this._platform);
  final NativeGeofencePlatform _platform;

  @override
  Future<void> acknowledgeCandidate(String eventId) =>
      _platform.acknowledgeCandidate(eventId);

  @override
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates() =>
      _platform.drainPendingCandidates();

  @override
  Future<NativeGeofenceCapability> getCapability() => _platform.getCapability();

  @override
  Future<NativeGeofenceCapability> requestBackgroundCapability() =>
      _platform.requestBackgroundCapability();

  @override
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> zones) async {
    if (zones.length > geofenceZoneLimit) {
      throw const GeofenceRegistrationException(
        'A device can monitor at most 20 safe zones.',
      );
    }
    await _platform.replaceMonitoredZones(zones);
  }
}

final nativeGeofenceGatewayProvider = Provider<NativeGeofenceGateway>(
  (ref) => NativeGeofenceGateway(ref.watch(nativeGeofencePlatformProvider)),
);

class GeofenceRegistration {
  const GeofenceRegistration({
    required this.zoneId,
    required this.generation,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String zoneId;
  final int generation;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  NativeGeofenceZone toNativeZone() => NativeGeofenceZone(
    zoneId: zoneId,
    generation: generation,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );

  factory GeofenceRegistration.fromJson(Map<String, dynamic> json) =>
      GeofenceRegistration(
        zoneId: json['zoneId'] as String,
        generation: json['generation'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radiusMeters'] as num).toDouble(),
      );
}

abstract class GeofenceRegistrationApi {
  Future<GeofenceRegistration?> fetchRegistration();
  Future<void> acknowledgeRegistration(String zoneId, int generation);
}

class DioGeofenceRegistrationApi implements GeofenceRegistrationApi {
  DioGeofenceRegistrationApi(this._dio);
  final Dio _dio;

  @override
  Future<void> acknowledgeRegistration(String zoneId, int generation) async {
    await _dio.post<void>(
      '/geofences/$zoneId/registrations/$generation/acknowledgements',
    );
  }

  @override
  Future<GeofenceRegistration?> fetchRegistration() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geofences/registration',
      );
      final data = response.data;
      return data == null ? null : GeofenceRegistration.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final geofenceRegistrationApiProvider = Provider<GeofenceRegistrationApi>(
  (ref) => DioGeofenceRegistrationApi(ref.watch(dioProvider)),
);
