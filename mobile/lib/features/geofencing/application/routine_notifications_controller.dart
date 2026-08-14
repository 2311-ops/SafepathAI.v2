import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

enum RoutineNotificationTransition { entered, left }

class RoutineNotification {
  const RoutineNotification({
    required this.id,
    required this.activityId,
    required this.memberUserId,
    required this.memberName,
    required this.zoneName,
    required this.transition,
    required this.occurredAtUtc,
    this.isRead = false,
  });

  final String id;
  final String activityId;
  final String memberUserId;
  final String memberName;
  final String zoneName;
  final RoutineNotificationTransition transition;
  final DateTime occurredAtUtc;
  final bool isRead;

  RoutineNotification copyWith({bool? isRead}) => RoutineNotification(
    id: id,
    activityId: activityId,
    memberUserId: memberUserId,
    memberName: memberName,
    zoneName: zoneName,
    transition: transition,
    occurredAtUtc: occurredAtUtc,
    isRead: isRead ?? this.isRead,
  );
}

class QuietHoursSetting {
  const QuietHoursSetting({
    this.isEnabled = false,
    this.localStart = '00:00:00',
    this.localEnd = '00:00:00',
    this.timeZoneId = 'Etc/UTC',
  });

  final bool isEnabled;
  final String localStart;
  final String localEnd;
  final String timeZoneId;
}

class RoutineNotificationsState {
  const RoutineNotificationsState({
    this.items = const [],
    this.quietHours = const QuietHoursSetting(),
    this.isLoading = false,
    this.error,
  });

  final List<RoutineNotification> items;
  final QuietHoursSetting quietHours;
  final bool isLoading;
  final String? error;

  RoutineNotificationsState copyWith({
    List<RoutineNotification>? items,
    QuietHoursSetting? quietHours,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => RoutineNotificationsState(
    items: items ?? this.items,
    quietHours: quietHours ?? this.quietHours,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

abstract class RoutineNotificationsApi {
  Future<List<RoutineNotification>> getFeed();
  Future<void> markRead(String id);
  Future<QuietHoursSetting> getQuietHours();
  Future<QuietHoursSetting> updateQuietHours(QuietHoursSetting setting);
}

class DioRoutineNotificationsApi implements RoutineNotificationsApi {
  DioRoutineNotificationsApi(this._dio);
  final Dio _dio;

  @override
  Future<List<RoutineNotification>> getFeed() async {
    try {
      final response = await _dio.get<List<dynamic>>('/notifications');
      return (response.data ?? const [])
          .whereType<Map>()
          .map((json) => _notification(Map<String, dynamic>.from(json)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw RoutineNotificationsException(_message(error));
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.post<void>('/notifications/$id/read');
    } on DioException catch (error) {
      throw RoutineNotificationsException(_message(error));
    }
  }

  @override
  Future<QuietHoursSetting> getQuietHours() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications/quiet-hours',
      );
      return _quietHours(response.data ?? const {});
    } on DioException catch (error) {
      throw RoutineNotificationsException(_message(error));
    }
  }

  @override
  Future<QuietHoursSetting> updateQuietHours(QuietHoursSetting setting) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/notifications/quiet-hours',
        data: {
          'isEnabled': setting.isEnabled,
          'localStart': setting.localStart,
          'localEnd': setting.localEnd,
          'timeZoneId': setting.timeZoneId,
        },
      );
      return _quietHours(response.data ?? const {});
    } on DioException catch (error) {
      throw RoutineNotificationsException(_message(error));
    }
  }

  RoutineNotification _notification(Map<String, dynamic> json) =>
      RoutineNotification(
        id: json['id'] as String,
        activityId: json['activityId'] as String,
        memberUserId: json['memberUserId'] as String,
        // The current API does not yet include a display name. Retain the
        // caller-owned id for an avatar and use a truthful generic label until
        // the endpoint supplies one.
        memberName: json['memberDisplayName'] as String? ?? 'Family member',
        zoneName: json['zoneName'] as String? ?? 'Safe zone',
        transition:
            (json['transition'] as String? ?? '').toLowerCase() == 'exit'
            ? RoutineNotificationTransition.left
            : RoutineNotificationTransition.entered,
        occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String).toUtc(),
        isRead: json['isRead'] as bool? ?? false,
      );

  QuietHoursSetting _quietHours(Map<String, dynamic> json) => QuietHoursSetting(
    isEnabled: json['isEnabled'] as bool? ?? false,
    localStart: json['localStart'] as String? ?? '00:00:00',
    localEnd: json['localEnd'] as String? ?? '00:00:00',
    timeZoneId: json['timeZoneId'] as String? ?? 'Etc/UTC',
  );

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return 'Couldn\'t update notifications. Check your connection and try again.';
  }
}

class RoutineNotificationsException implements Exception {
  const RoutineNotificationsException(this.message);
  final String message;
}

class RoutineNotificationsController
    extends AsyncNotifier<RoutineNotificationsState> {
  @override
  RoutineNotificationsState build() {
    Future.microtask(refresh);
    return const RoutineNotificationsState(isLoading: true);
  }

  RoutineNotificationsState get _current =>
      state.value ?? const RoutineNotificationsState();

  Future<void> refresh() async {
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final items = await ref.read(routineNotificationsApiProvider).getFeed();
      state = AsyncData(_current.copyWith(items: items, isLoading: false));
    } on RoutineNotificationsException catch (error) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
    }
  }

  Future<void> open(RoutineNotification item) async {
    if (item.isRead) return;
    state = AsyncData(
      _current.copyWith(
        items: [
          for (final current in _current.items)
            current.id == item.id ? current.copyWith(isRead: true) : current,
        ],
      ),
    );
    try {
      await ref.read(routineNotificationsApiProvider).markRead(item.id);
    } on RoutineNotificationsException catch (error) {
      state = AsyncData(_current.copyWith(error: error.message));
    }
  }

  Future<void> loadQuietHours() async {
    try {
      final quietHours = await ref
          .read(routineNotificationsApiProvider)
          .getQuietHours();
      state = AsyncData(_current.copyWith(quietHours: quietHours));
    } on RoutineNotificationsException catch (error) {
      state = AsyncData(_current.copyWith(error: error.message));
    }
  }

  Future<bool> saveQuietHours(QuietHoursSetting setting) async {
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final saved = await ref
          .read(routineNotificationsApiProvider)
          .updateQuietHours(setting);
      state = AsyncData(_current.copyWith(quietHours: saved, isLoading: false));
      return true;
    } on RoutineNotificationsException catch (error) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
      return false;
    }
  }
}

final routineNotificationsApiProvider = Provider<RoutineNotificationsApi>(
  (ref) => DioRoutineNotificationsApi(ref.watch(dioProvider)),
);

final routineNotificationsControllerProvider =
    AsyncNotifierProvider<
      RoutineNotificationsController,
      RoutineNotificationsState
    >(RoutineNotificationsController.new);
