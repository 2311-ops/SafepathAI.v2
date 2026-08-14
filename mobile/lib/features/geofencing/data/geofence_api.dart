import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'geofence_models.dart';

class GeofenceApiException implements Exception {
  const GeofenceApiException(this.message);
  final String message;
  @override
  String toString() => 'GeofenceApiException: $message';
}

abstract class GeofenceApi {
  Future<List<SafeZone>> list(String familyId);
  Future<SafeZone> get(String familyId, String zoneId);
  Future<SafeZone> create(SafeZoneDraft draft);
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft);
  Future<void> delete(String familyId, String zoneId);
}

class DioGeofenceApi implements GeofenceApi {
  DioGeofenceApi(this._dio);
  final Dio _dio;

  @override
  Future<List<SafeZone>> list(String familyId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/families/$familyId/geofences',
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map((entry) => SafeZone.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SafeZone> get(String familyId, String zoneId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/families/$familyId/geofences/$zoneId',
      );
      return SafeZone.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SafeZone> create(SafeZoneDraft draft) async {
    final familyId = draft.familyId;
    if (familyId == null) {
      throw const GeofenceApiException('Choose a family before saving.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/families/$familyId/geofences',
        data: draft.toRequest(),
      );
      return _fromMutation(response.data, draft);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft) async {
    final familyId = draft.familyId;
    if (familyId == null) {
      throw const GeofenceApiException('Choose a family before saving.');
    }
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/families/$familyId/geofences/$zoneId',
        data: draft.toRequest(),
      );
      return _fromMutation(response.data, draft, zoneId: zoneId);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> delete(String familyId, String zoneId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/families/$familyId/geofences/$zoneId',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  SafeZone _fromMutation(
    Map<String, dynamic>? response,
    SafeZoneDraft draft, {
    String? zoneId,
  }) {
    final id = response?['zoneId'] as String? ?? zoneId ?? draft.zoneId ?? '';
    return SafeZone(
      id: id,
      name: draft.name.trim(),
      category: draft.category,
      center: draft.center,
      radiusMeters: draft.radiusMeters,
      assignedMemberId: draft.assignedMemberId!,
      sensitivity: draft.sensitivity,
      guardianRecipientIds: draft.guardianRecipientIds,
      notifyAssignedMember: draft.notifyAssignedMember,
    );
  }

  GeofenceApiException _mapError(DioException error) {
    final data = error.response?.data;
    final serverMessage = data is Map ? data['error'] as String? : null;
    if (error.response?.statusCode == 403) {
      return const GeofenceApiException(
        'Only Guardians can manage safe zones.',
      );
    }
    if (error.response?.statusCode == 400 ||
        error.response?.statusCode == 409) {
      return GeofenceApiException(
        serverMessage ?? 'That safe zone could not be saved.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const GeofenceApiException(
        "Couldn't connect. Check your connection and try again.",
      );
    }
    return GeofenceApiException(
      error.message ?? 'That safe zone could not be saved.',
    );
  }
}

final geofenceApiProvider = Provider<GeofenceApi>(
  (ref) => DioGeofenceApi(ref.watch(dioProvider)),
);
