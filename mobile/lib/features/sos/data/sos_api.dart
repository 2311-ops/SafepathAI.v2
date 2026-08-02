import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'sos_models.dart';

enum SosApiIssue { forbidden, notFound, validation, network, unknown }

class SosApiException implements Exception {
  SosApiException(this.issue, {this.message});

  final SosApiIssue issue;
  final String? message;

  @override
  String toString() => 'SosApiException(issue: $issue, message: $message)';
}

abstract class SosApi {
  /// `POST /sos/trigger`. Idempotent on `request.sosSessionId` — a replayed
  /// id returns the original session rather than creating a second
  /// emergency (D-15).
  Future<SosSession> trigger(SosTriggerRequest request);

  /// `GET /sos/{sosSessionId}` — current per-recipient/per-channel delivery
  /// state for an already-triggered emergency.
  Future<SosSession> getSession(String sosSessionId);

  /// `POST /sos/{id}/acknowledge` — a guardian confirms they have seen the
  /// alert. Strictly stronger than Delivered (D-22); only the caller's own
  /// delivery rows change server-side.
  Future<SosSession> acknowledge(String sosSessionId);

  /// `POST /sos/{id}/cancel` — self-cancel only. Consumed by plan 03-09;
  /// declared here so the API surface is complete in one place.
  Future<SosSession> cancel(String sosSessionId);
}

class DioSosApi implements SosApi {
  DioSosApi(this._dio);

  final Dio _dio;

  @override
  Future<SosSession> trigger(SosTriggerRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sos/trigger',
        data: request.toJson(),
      );
      final data = response.data ?? const {};
      final sessionJson = data['session'] as Map<String, dynamic>?;
      if (sessionJson == null) {
        throw SosApiException(
          SosApiIssue.unknown,
          message: 'The server did not return a session.',
        );
      }
      return SosSession.fromJson(sessionJson);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SosSession> getSession(String sosSessionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sos/$sosSessionId',
      );
      return SosSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SosSession> acknowledge(String sosSessionId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sos/$sosSessionId/acknowledge',
      );
      return _sessionFromWrappedResponse(response.data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SosSession> cancel(String sosSessionId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sos/$sosSessionId/cancel',
      );
      return _sessionFromWrappedResponse(response.data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  SosSession _sessionFromWrappedResponse(Map<String, dynamic>? data) {
    final sessionJson = (data ?? const {})['session'] as Map<String, dynamic>?;
    if (sessionJson == null) {
      throw SosApiException(
        SosApiIssue.unknown,
        message: 'The server did not return a session.',
      );
    }
    return SosSession.fromJson(sessionJson);
  }

  SosApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return SosApiException(
        SosApiIssue.forbidden,
        message: 'You cannot trigger SOS for that family.',
      );
    }
    if (status == 404) {
      return SosApiException(
        SosApiIssue.notFound,
        message: 'That emergency session was not found.',
      );
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return SosApiException(
        SosApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return SosApiException(
        SosApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return SosApiException(SosApiIssue.unknown, message: error.message);
  }
}

final sosApiProvider = Provider<SosApi>(
  (ref) => DioSosApi(ref.watch(dioProvider)),
);
