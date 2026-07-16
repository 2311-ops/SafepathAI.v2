import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'location_models.dart';

enum LocationApiIssue { forbidden, notFound, validation, network, unknown }

class LocationApiException implements Exception {
  LocationApiException(this.issue, {this.message});

  final LocationApiIssue issue;
  final String? message;

  @override
  String toString() => 'LocationApiException(issue: $issue, message: $message)';
}

abstract class LocationApi {
  /// `GET /families/{familyId}/live-locations`.
  Future<List<LiveLocation>> getLiveLocations(String familyId);

  /// `GET /families/{familyId}/members/{targetUserId}/history`.
  Future<LocationHistory> getHistory(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  );

  /// `GET /families/{familyId}/members/{targetUserId}/travel-stats`.
  Future<TravelStats> getTravelStats(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  );
}

class DioLocationApi implements LocationApi {
  DioLocationApi(this._dio);

  final Dio _dio;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/families/$familyId/live-locations',
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .where((entry) => entry['lat'] != null && entry['lng'] != null)
          .map(
            (entry) => LiveLocation.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<LocationHistory> getHistory(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/families/$familyId/members/$targetUserId/history',
        queryParameters: _rangeQuery(fromUtc, toUtc),
      );
      return LocationHistory.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<TravelStats> getTravelStats(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/families/$familyId/members/$targetUserId/travel-stats',
        queryParameters: _rangeQuery(fromUtc, toUtc),
      );
      return TravelStats.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, String> _rangeQuery(DateTime fromUtc, DateTime toUtc) {
    return {
      'from': fromUtc.toUtc().toIso8601String(),
      'to': toUtc.toUtc().toIso8601String(),
    };
  }

  LocationApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return LocationApiException(
        LocationApiIssue.forbidden,
        message: 'You cannot view those locations.',
      );
    }
    if (status == 404) {
      return LocationApiException(
        LocationApiIssue.notFound,
        message: 'Not found.',
      );
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return LocationApiException(
        LocationApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return LocationApiException(
        LocationApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return LocationApiException(
      LocationApiIssue.unknown,
      message: error.message,
    );
  }
}

final locationApiProvider = Provider<LocationApi>(
  (ref) => DioLocationApi(ref.watch(dioProvider)),
);
