import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'sos_models.dart';

enum SosApiIssue { forbidden, notFound, validation, network, unknown }

/// Mirrors `ReportSosLocationOutcome` on the wire. `sessionNotFound` never
/// actually appears in a parsed response body — the server returns a bare
/// 404 for that case (surfaced as [SosApiIssue.notFound] instead) — but the
/// case is kept here so this enum stays a complete mirror of the backend
/// contract rather than a partial one.
enum SosLocationWindowOutcome { accepted, windowClosed, sessionNotFound, unknown }

SosLocationWindowOutcome _parseSosLocationWindowOutcome(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'accepted':
      return SosLocationWindowOutcome.accepted;
    case 'windowclosed':
      return SosLocationWindowOutcome.windowClosed;
    case 'sessionnotfound':
      return SosLocationWindowOutcome.sessionNotFound;
    default:
      return SosLocationWindowOutcome.unknown;
  }
}

/// Mirrors `ReportSosLocationResult` — the server's authoritative window
/// state, echoed back on every `reportSosLocation` call so the client can
/// self-terminate its foreground service the moment the server says the
/// window has closed, rather than trusting its own local clock (D-21).
class SosLocationWindow {
  const SosLocationWindow({required this.outcome, this.liveWindowEndsAtUtc});

  final SosLocationWindowOutcome outcome;
  final DateTime? liveWindowEndsAtUtc;

  factory SosLocationWindow.fromJson(Map<String, dynamic> json) {
    final raw = json['liveWindowEndsAtUtc'];
    return SosLocationWindow(
      outcome: _parseSosLocationWindowOutcome(json['outcome'] as String?),
      liveWindowEndsAtUtc: raw is String && raw.isNotEmpty
          ? DateTime.tryParse(raw)?.toUtc()
          : null,
    );
  }
}

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

  /// `POST /sos/{sosSessionId}/location` — reports one position fix during
  /// an active SOS's live-location window (D-21/SOS-04). This is a
  /// structurally separate call from the routine `ReportLocation` pipeline
  /// (Location feature) — never touches it in either direction.
  Future<SosLocationWindow> reportSosLocation(
    String sosSessionId,
    double latitude,
    double longitude,
    double? accuracyMeters,
    DateTime recordedAtUtc,
  );
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

  @override
  Future<SosLocationWindow> reportSosLocation(
    String sosSessionId,
    double latitude,
    double longitude,
    double? accuracyMeters,
    DateTime recordedAtUtc,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sos/$sosSessionId/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracyMeters': accuracyMeters,
          'recordedAtUtc': recordedAtUtc.toUtc().toIso8601String(),
        },
      );
      return SosLocationWindow.fromJson(response.data ?? const {});
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
