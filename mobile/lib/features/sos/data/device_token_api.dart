import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

enum DeviceTokenApiIssue { forbidden, notFound, validation, network, unknown }

class DeviceTokenApiException implements Exception {
  DeviceTokenApiException(this.issue, {this.message});

  final DeviceTokenApiIssue issue;
  final String? message;

  @override
  String toString() =>
      'DeviceTokenApiException(issue: $issue, message: $message)';
}

/// The device-side half of 03-06's FCM channel: registers/removes this
/// device's push token and reports receipt of an SOS push, mirroring
/// `LocationApi`/`SosApi`'s Dio-abstract-interface convention.
abstract class DeviceTokenApi {
  /// `POST /me/device-tokens` — upserts this device's current FCM token.
  Future<void> register(String token, String platform);

  /// `DELETE /me/device-tokens` — removes this device's token (sign-out).
  Future<void> remove(String token);

  /// `POST /sos/{id}/push-receipt` — the FCM analogue of
  /// `AlertHub.ConfirmReceipt`, asserting this device actually received the
  /// push for `sosSessionId`.
  Future<void> confirmPushReceipt(String sosSessionId);
}

class DioDeviceTokenApi implements DeviceTokenApi {
  DioDeviceTokenApi(this._dio);

  final Dio _dio;

  @override
  Future<void> register(String token, String platform) async {
    try {
      await _dio.post<void>(
        '/me/device-tokens',
        data: {'token': token, 'platform': platform},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> remove(String token) async {
    try {
      await _dio.delete<void>('/me/device-tokens', data: {'token': token});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> confirmPushReceipt(String sosSessionId) async {
    try {
      await _dio.post<void>('/sos/$sosSessionId/push-receipt');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  DeviceTokenApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return DeviceTokenApiException(
        DeviceTokenApiIssue.forbidden,
        message: 'You cannot perform that action.',
      );
    }
    if (status == 404) {
      return DeviceTokenApiException(
        DeviceTokenApiIssue.notFound,
        message: 'Not found.',
      );
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return DeviceTokenApiException(
        DeviceTokenApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return DeviceTokenApiException(
        DeviceTokenApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return DeviceTokenApiException(
      DeviceTokenApiIssue.unknown,
      message: error.message,
    );
  }
}

final deviceTokenApiProvider = Provider<DeviceTokenApi>(
  (ref) => DioDeviceTokenApi(ref.watch(dioProvider)),
);
