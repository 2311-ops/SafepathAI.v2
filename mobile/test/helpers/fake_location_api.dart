import 'package:mobile/features/location/data/location_api.dart';
import 'package:mobile/features/location/data/location_models.dart';

class FakeLocationApi implements LocationApi {
  List<LiveLocation> liveLocationsToReturn = const [];
  String? lastFamilyId;
  int getLiveLocationsCallCount = 0;

  @override
  Future<List<LiveLocation>> getLiveLocations(String familyId) async {
    getLiveLocationsCallCount++;
    lastFamilyId = familyId;
    return liveLocationsToReturn;
  }
}
