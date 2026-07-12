import 'dart:async';

import 'package:mobile/features/location/data/location_hub_client.dart';
import 'package:mobile/features/location/data/location_models.dart';

class FakeLocationHubClient implements LocationHubClient {
  final StreamController<LiveLocation> _locationUpdates =
      StreamController<LiveLocation>.broadcast();
  final StreamController<PresenceChange> _presenceChanges =
      StreamController<PresenceChange>.broadcast();
  final StreamController<LocationHubConnectionState> _stateChanges =
      StreamController<LocationHubConnectionState>.broadcast();

  String? lastConnectedFamilyId;
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  int reportLocationCallCount = 0;
  ReportLocationPayload? lastReportedLocation;
  LocationHubConnectionState _state = LocationHubConnectionState.disconnected;

  @override
  Stream<LiveLocation> get locationUpdates => _locationUpdates.stream;

  @override
  Stream<PresenceChange> get presenceChanges => _presenceChanges.stream;

  @override
  LocationHubConnectionState get state => _state;

  @override
  Stream<LocationHubConnectionState> get stateChanges => _stateChanges.stream;

  @override
  Future<void> connect(String familyId) async {
    connectCallCount++;
    lastConnectedFamilyId = familyId;
    setState(LocationHubConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    setState(LocationHubConnectionState.disconnected);
  }

  @override
  Future<void> reportLocation(ReportLocationPayload location) async {
    reportLocationCallCount++;
    lastReportedLocation = location;
  }

  void emitLocation(LiveLocation location) {
    _locationUpdates.add(location);
  }

  void emitPresence(PresenceChange change) {
    _presenceChanges.add(change);
  }

  void setState(LocationHubConnectionState state) {
    _state = state;
    if (!_stateChanges.isClosed) {
      _stateChanges.add(state);
    }
  }

  @override
  void dispose() {
    _locationUpdates.close();
    _presenceChanges.close();
    _stateChanges.close();
  }
}
