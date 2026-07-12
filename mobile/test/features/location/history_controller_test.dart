import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/history_controller.dart';
import 'package:mobile/features/location/data/location_api.dart';
import 'package:mobile/features/location/data/location_models.dart';

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'fam-1', name: 'Safe circle'),
    members: [
      FamilyMemberView(
        memberId: 'member-row-1',
        userId: 'member-1',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 7, 12),
      ),
    ],
  );
}

class _FakeLocationApi implements LocationApi {
  LocationHistory historyToReturn = const LocationHistory();
  TravelStats statsToReturn = const TravelStats();
  LocationApiException? historyError;

  String? lastHistoryFamilyId;
  String? lastHistoryTargetUserId;
  DateTime? lastHistoryFromUtc;
  DateTime? lastHistoryToUtc;
  int getHistoryCallCount = 0;
  int getTravelStatsCallCount = 0;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) async =>
      const [];

  @override
  Future<LocationHistory> getHistory(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    getHistoryCallCount++;
    lastHistoryFamilyId = familyId;
    lastHistoryTargetUserId = targetUserId;
    lastHistoryFromUtc = fromUtc;
    lastHistoryToUtc = toUtc;
    final error = historyError;
    if (error != null) throw error;
    return historyToReturn;
  }

  @override
  Future<TravelStats> getTravelStats(
    String familyId,
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    getTravelStatsCallCount++;
    return statsToReturn;
  }
}

ProviderContainer _container(_FakeLocationApi api) {
  return ProviderContainer(
    overrides: [
      locationApiProvider.overrideWithValue(api),
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
    ],
  );
}

void main() {
  test('load fetches history and travel stats into state', () async {
    final api = _FakeLocationApi()
      ..historyToReturn = LocationHistory(
        polylinePoints: [
          RoutePoint(
            lat: 30.0444,
            lng: 31.2357,
            recordedAtUtc: DateTime.utc(2026, 7, 12, 8),
          ),
        ],
        stops: [
          HistoryStop(
            startUtc: DateTime.utc(2026, 7, 12, 8),
            endUtc: DateTime.utc(2026, 7, 12, 8, 12),
            lat: 30.0444,
            lng: 31.2357,
          ),
        ],
      )
      ..statsToReturn = const TravelStats(
        distanceMeters: 3218,
        timeAway: Duration(hours: 1, minutes: 15),
        stopCount: 1,
      );
    final container = _container(api);
    addTearDown(container.dispose);

    await container
        .read(historyControllerProvider.notifier)
        .load('member-1', DateTime.utc(2026, 7, 12), DateTime.utc(2026, 7, 13));

    final state = container.read(historyControllerProvider).value!;
    expect(api.getHistoryCallCount, 1);
    expect(api.getTravelStatsCallCount, 1);
    expect(api.lastHistoryFamilyId, 'fam-1');
    expect(api.lastHistoryTargetUserId, 'member-1');
    expect(state.selectedTargetUserId, 'member-1');
    expect(state.history.polylinePoints, hasLength(1));
    expect(state.history.stops, hasLength(1));
    expect(state.stats.distanceMeters, 3218);
    expect(state.isEmpty, isFalse);
    expect(state.error, isNull);
  });

  test('history-share denied becomes a friendly error state', () async {
    final api = _FakeLocationApi()
      ..historyError = LocationApiException(
        LocationApiIssue.forbidden,
        message: 'You cannot view those locations.',
      );
    final container = _container(api);
    addTearDown(container.dispose);

    await container
        .read(historyControllerProvider.notifier)
        .load('member-1', DateTime.utc(2026, 7, 12), DateTime.utc(2026, 7, 13));

    final state = container.read(historyControllerProvider).value!;
    expect(state.error, 'You cannot view those locations.');
    expect(state.history.polylinePoints, isEmpty);
    expect(state.isLoading, isFalse);
  });

  test('empty history range is distinct from an error', () async {
    final api = _FakeLocationApi();
    final container = _container(api);
    addTearDown(container.dispose);

    await container
        .read(historyControllerProvider.notifier)
        .load('member-1', DateTime.utc(2026, 7, 12), DateTime.utc(2026, 7, 13));

    final state = container.read(historyControllerProvider).value!;
    expect(state.error, isNull);
    expect(state.isEmpty, isTrue);
    expect(state.emptyTitle, 'No history yet');
  });
}
