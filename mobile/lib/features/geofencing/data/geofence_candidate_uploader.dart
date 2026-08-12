import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_api.dart';
import 'native_geofence_gateway.dart';

class GeofenceCandidateDrainResult {
  const GeofenceCandidateDrainResult({required this.shouldRetry});

  final bool shouldRetry;
}

/// Drains native routine-location candidates only after Supabase restores auth.
class GeofenceCandidateUploader {
  GeofenceCandidateUploader({
    required AuthApi authApi,
    required Dio dio,
    required NativeGeofencePlatform nativePlatform,
  }) : _authApi = authApi,
       _dio = dio,
       _nativePlatform = nativePlatform;

  final AuthApi _authApi;
  final Dio _dio;
  final NativeGeofencePlatform _nativePlatform;

  Future<GeofenceCandidateDrainResult> drain() async {
    try {
      final refreshed = await _authApi.refreshSession();
      if (!refreshed.signedIn) {
        return const GeofenceCandidateDrainResult(shouldRetry: true);
      }

      var shouldRetry = false;
      for (final candidate in await _nativePlatform.drainPendingCandidates()) {
        try {
          final response = await _dio.post<void>(
            '/geofences/candidates',
            data: _CandidateRequest.fromNative(candidate).toJson(),
          );
          if (response.statusCode != 200 && response.statusCode != 202) {
            shouldRetry = true;
            continue;
          }
          await _nativePlatform.acknowledgeCandidate(candidate.eventId);
        } catch (_) {
          // Retain every candidate until the server accepts it or confirms replay.
          shouldRetry = true;
        }
      }
      return GeofenceCandidateDrainResult(shouldRetry: shouldRetry);
    } catch (_) {
      // A missing session, auth refresh failure, or offline device must leave
      // the app-private native outbox unchanged for a later retry/relaunch.
      return const GeofenceCandidateDrainResult(shouldRetry: true);
    }
  }
}

Future<GeofenceCandidateDrainResult>
drainGeofenceCandidatesAfterAuthRestoration() {
  final authApi = SupabaseAuthApi(Supabase.instance.client);
  return GeofenceCandidateUploader(
    authApi: authApi,
    dio: buildDio(apiBaseUrl, authApi: authApi),
    nativePlatform: const MethodChannelNativeGeofencePlatform(
      MethodChannel('safepath/geofencing'),
    ),
  ).drain();
}

class _CandidateRequest {
  const _CandidateRequest({
    required this.eventId,
    required this.zoneId,
    required this.registrationGeneration,
    required this.transition,
    required this.occurredAtUtc,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final String eventId;
  final String zoneId;
  final int registrationGeneration;
  final String transition;
  final DateTime occurredAtUtc;
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  factory _CandidateRequest.fromNative(NativeGeofenceCandidate candidate) {
    final separator = candidate.requestId.lastIndexOf(':');
    final generation = separator == -1
        ? null
        : int.tryParse(candidate.requestId.substring(separator + 1));
    if (separator <= 0 ||
        generation == null ||
        generation <= 0 ||
        candidate.transition == NativeGeofenceTransition.error ||
        candidate.latitude == null ||
        candidate.longitude == null ||
        candidate.accuracyMeters == null) {
      throw const FormatException(
        'Native geofence candidate cannot be submitted yet.',
      );
    }
    return _CandidateRequest(
      eventId: candidate.eventId,
      zoneId: candidate.requestId.substring(0, separator),
      registrationGeneration: generation,
      transition: candidate.transition.name,
      occurredAtUtc: candidate.occurredAtUtc,
      latitude: candidate.latitude!,
      longitude: candidate.longitude!,
      accuracyMeters: candidate.accuracyMeters!,
    );
  }

  Map<String, Object> toJson() => {
    'eventId': eventId,
    'zoneId': zoneId,
    'registrationGeneration': registrationGeneration,
    'transition': transition,
    'occurredAtUtc': occurredAtUtc.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
  };
}
