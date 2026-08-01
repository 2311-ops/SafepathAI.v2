import 'package:mobile/features/sos/data/sos_local_store.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

/// Hand-written [SosLocalStore] fake (matches `fake_location_api.dart`'s
/// convention — no mocking package).
class FakeSosLocalStore implements SosLocalStore {
  String? savedSessionId;
  SosTriggerRequest? pendingTrigger;
  int clearCallCount = 0;

  @override
  Future<String?> readSessionId() async => savedSessionId;

  @override
  Future<void> writeSessionId(String id) async {
    savedSessionId = id;
  }

  @override
  Future<void> clear() async {
    clearCallCount++;
    savedSessionId = null;
    pendingTrigger = null;
  }

  @override
  Future<SosTriggerRequest?> readPendingTrigger() async => pendingTrigger;

  @override
  Future<void> writePendingTrigger(SosTriggerRequest request) async {
    pendingTrigger = request;
  }
}
