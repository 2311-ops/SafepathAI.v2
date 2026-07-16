import 'package:mobile/features/location/data/location_api.dart';
import 'package:mobile/features/location/data/location_models.dart';

class FakeLocationApi implements LocationApi {
  List<LiveLocation> liveLocationsToReturn = const [];
  LocationHistory historyToReturn = const LocationHistory();
  TravelStats travelStatsToReturn = const TravelStats();
  String? lastFamilyId;
  String? lastHistoryFamilyId;
  String? lastHistoryTargetUserId;
  DateTime? lastHistoryFromUtc;
  DateTime? lastHistoryToUtc;
  int getLiveLocationsCallCount = 0;
  int getHistoryCallCount = 0;
  int getTravelStatsCallCount = 0;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) async {
    getLiveLocationsCallCount++;
    lastFamilyId = familyId;
    return liveLocationsToReturn;
  }

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
    return travelStatsToReturn;
  }
}
