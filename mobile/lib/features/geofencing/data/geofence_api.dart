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
  Future<List<GeofenceActivity>> activity(
    String familyId,
    GeofenceActivityFilters filters,
  ) => Future<List<GeofenceActivity>>.error(UnimplementedError());
  Future<SafeZone> create(SafeZoneDraft draft);
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft);
  Future<SafeZoneActivation> setActive(
    String familyId,
    String zoneId,
    bool active,
  );
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
  Future<List<GeofenceActivity>> activity(
    String familyId,
    GeofenceActivityFilters filters,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/families/$familyId/geofences/activity',
        queryParameters: filters.toQueryParameters(),
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map(
            (entry) =>
                GeofenceActivity.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw const GeofenceApiException(
          'Only Guardians can view safe-zone activity.',
        );
      }
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
  Future<SafeZoneActivation> setActive(
    String familyId,
    String zoneId,
    bool active,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/families/$familyId/geofences/$zoneId/${active ? 'enable' : 'disable'}',
      );
      return _activationFromMutation(response.data);
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
      activation: _activationFromMutation(response),
    );
  }

  SafeZoneActivation _activationFromMutation(Map<String, dynamic>? response) {
    if (response?['needsLocationPermission'] == true) {
      return SafeZoneActivation.needsLocationPermission;
    }
    return response?['active'] == false
        ? SafeZoneActivation.inactive
        : SafeZoneActivation.active;
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

enum GeofenceActivityTransition {
  entered('Enter', 'Entered'),
  left('Exit', 'Left');

  const GeofenceActivityTransition(this.queryValue, this.label);
  final String queryValue;
  final String label;

  factory GeofenceActivityTransition.fromJson(String? value) =>
      switch (value?.toLowerCase()) {
        'exit' => GeofenceActivityTransition.left,
        _ => GeofenceActivityTransition.entered,
      };
}

class GeofenceActivityFilters {
  const GeofenceActivityFilters({
    this.memberId,
    this.zoneId,
    this.transition,
    this.fromUtc,
    this.toUtc,
  });

  final String? memberId;
  final String? zoneId;
  final GeofenceActivityTransition? transition;
  final DateTime? fromUtc;
  final DateTime? toUtc;

  GeofenceActivityFilters copyWith({
    String? memberId,
    bool clearMember = false,
    String? zoneId,
    bool clearZone = false,
    GeofenceActivityTransition? transition,
    bool clearTransition = false,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) => GeofenceActivityFilters(
    memberId: clearMember ? null : (memberId ?? this.memberId),
    zoneId: clearZone ? null : (zoneId ?? this.zoneId),
    transition: clearTransition ? null : (transition ?? this.transition),
    fromUtc: fromUtc ?? this.fromUtc,
    toUtc: toUtc ?? this.toUtc,
  );

  GeofenceActivityFilters clampToRetention(DateTime nowUtc) {
    final end = nowUtc.toUtc();
    final retainedStart = end.subtract(const Duration(days: 7));
    final requestedFrom = fromUtc?.toUtc() ?? retainedStart;
    final requestedTo = toUtc?.toUtc() ?? end;
    final clampedFrom = requestedFrom.isBefore(retainedStart)
        ? retainedStart
        : requestedFrom.isAfter(end)
        ? end
        : requestedFrom;
    final clampedTo = requestedTo.isAfter(end)
        ? end
        : requestedTo.isBefore(retainedStart)
        ? retainedStart
        : requestedTo;
    return copyWith(
      fromUtc: clampedFrom.isAfter(clampedTo) ? clampedTo : clampedFrom,
      toUtc: clampedTo,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
    if (memberId != null) 'memberUserId': memberId,
    if (zoneId != null) 'zoneId': zoneId,
    if (transition != null) 'transition': transition!.queryValue,
    if (fromUtc != null) 'fromUtc': fromUtc!.toUtc().toIso8601String(),
    if (toUtc != null) 'toUtc': toUtc!.toUtc().toIso8601String(),
  };
}

class GeofenceActivity {
  const GeofenceActivity({
    required this.memberId,
    required this.memberName,
    required this.zoneId,
    required this.zoneName,
    required this.transition,
    required this.occurredAtUtc,
    this.enteredAtUtc,
    this.exitedAtUtc,
    this.completedVisitDurationSeconds,
    this.isInProgress = false,
  });

  final String memberId;
  final String memberName;
  final String? zoneId;
  final String zoneName;
  final GeofenceActivityTransition transition;
  final DateTime occurredAtUtc;
  final DateTime? enteredAtUtc;
  final DateTime? exitedAtUtc;
  final int? completedVisitDurationSeconds;
  final bool isInProgress;

  bool get isPairedVisit =>
      enteredAtUtc != null &&
      exitedAtUtc != null &&
      completedVisitDurationSeconds != null;

  factory GeofenceActivity.fromJson(Map<String, dynamic> json) =>
      GeofenceActivity(
        memberId: json['memberUserId'] as String,
        memberName: json['memberDisplayName'] as String? ?? 'Family member',
        zoneId: json['safeZoneId'] as String?,
        zoneName: json['safeZoneDisplayName'] as String? ?? 'Safe zone',
        transition: GeofenceActivityTransition.fromJson(
          json['transition'] as String?,
        ),
        occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String).toUtc(),
        enteredAtUtc: _parseUtc(json['enteredAtUtc']),
        exitedAtUtc: _parseUtc(json['exitedAtUtc']),
        completedVisitDurationSeconds:
            (json['completedVisitDurationSeconds'] as num?)?.round(),
        isInProgress: json['isInProgress'] as bool? ?? false,
      );

  static DateTime? _parseUtc(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;
}

final geofenceApiProvider = Provider<GeofenceApi>(
  (ref) => DioGeofenceApi(ref.watch(dioProvider)),
);
