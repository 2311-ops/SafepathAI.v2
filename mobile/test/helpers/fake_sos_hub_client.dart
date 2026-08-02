import 'dart:async';

import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

/// Hand-written [SosHubClient] fake (matches `fake_location_hub_client.dart`'s
/// convention — no mocking package). Public stream controllers let tests
/// push events directly; [pushRawSosTriggered] additionally exercises the
/// same defensive-parsing contract [SignalRSosHubClient] applies to a raw
/// wire payload, so the parse-valid / swallow-malformed behaviours are
/// testable without a live SignalR connection.
class FakeSosHubClient implements SosHubClient {
  final StreamController<SosSession> _sosTriggered =
      StreamController<SosSession>.broadcast();
  final StreamController<SosDeliveryStatusChange> _deliveryStatusChanges =
      StreamController<SosDeliveryStatusChange>.broadcast();
  final StreamController<SosCancellation> _sosCanceled =
      StreamController<SosCancellation>.broadcast();
  final StreamController<SosLocationUpdate> _liveLocationUpdates =
      StreamController<SosLocationUpdate>.broadcast();
  final StreamController<SosHubConnectionState> _stateChanges =
      StreamController<SosHubConnectionState>.broadcast();

  String? lastConnectedFamilyId;
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  final List<String> connectCalls = [];
  final List<String> confirmReceiptCalls = [];
  SosHubConnectionState _state = SosHubConnectionState.disconnected;

  @override
  Stream<SosSession> get sosTriggered => _sosTriggered.stream;

  @override
  Stream<SosDeliveryStatusChange> get deliveryStatusChanges =>
      _deliveryStatusChanges.stream;

  @override
  Stream<SosCancellation> get sosCanceled => _sosCanceled.stream;

  @override
  Stream<SosLocationUpdate> get liveLocationUpdates =>
      _liveLocationUpdates.stream;

  @override
  SosHubConnectionState get state => _state;

  @override
  Stream<SosHubConnectionState> get stateChanges => _stateChanges.stream;

  @override
  Future<void> connect(String familyId) async {
    connectCallCount++;
    lastConnectedFamilyId = familyId;
    connectCalls.add(familyId);
    setState(SosHubConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    setState(SosHubConnectionState.disconnected);
  }

  @override
  Future<void> confirmReceipt(String sosSessionId) async {
    confirmReceiptCalls.add(sosSessionId);
  }

  void emitSosTriggered(SosSession session) {
    _sosTriggered.add(session);
  }

  void emitDeliveryStatusChanged(SosDeliveryStatusChange change) {
    _deliveryStatusChanges.add(change);
  }

  void emitSosCanceled(SosCancellation cancellation) {
    _sosCanceled.add(cancellation);
  }

  void emitLiveLocationUpdate(SosLocationUpdate update) {
    _liveLocationUpdates.add(update);
  }

  /// Pushes a raw, unparsed JSON map through the same
  /// `SosSession.fromJson`-inside-a-try/catch pipeline the real hub client
  /// applies to a `SosTriggered` push — a malformed map must not close (or
  /// even affect) the stream (T-03-16).
  void pushRawSosTriggered(Map<String, dynamic> json) {
    try {
      _sosTriggered.add(SosSession.fromJson(json));
    } catch (_) {
      // A malformed emergency payload must never take down the connection
      // carrying the rest of the emergency.
    }
  }

  void setState(SosHubConnectionState state) {
    _state = state;
    if (!_stateChanges.isClosed) {
      _stateChanges.add(state);
    }
  }

  @override
  void dispose() {
    _sosTriggered.close();
    _deliveryStatusChanges.close();
    _sosCanceled.close();
    _liveLocationUpdates.close();
    _stateChanges.close();
  }
}
