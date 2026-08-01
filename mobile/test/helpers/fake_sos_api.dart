import 'dart:async';

import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

/// Hand-written [SosApi] fake (matches `fake_location_api.dart`'s
/// convention — no mocking package).
class FakeSosApi implements SosApi {
  /// When set, [trigger] awaits this instead of resolving — lets a test
  /// prove behaviour that must happen strictly before the network call
  /// settles (D-13/D-14).
  Completer<SosSession>? pendingTriggerCompleter;

  SosApiException? triggerError;
  SosSession Function(SosTriggerRequest request)? triggerResponseBuilder;
  final List<SosTriggerRequest> triggerCalls = [];
  int get triggerCallCount => triggerCalls.length;

  SosSession Function(String sosSessionId)? getSessionResponseBuilder;
  int getSessionCallCount = 0;

  @override
  Future<SosSession> trigger(SosTriggerRequest request) async {
    triggerCalls.add(request);
    final completer = pendingTriggerCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (triggerError != null) {
      throw triggerError!;
    }
    final builder = triggerResponseBuilder;
    if (builder != null) return builder(request);
    return SosSession(
      sosSessionId: request.sosSessionId,
      familyId: request.familyId,
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: request.triggeredAtUtc,
      receivedAtUtc: DateTime.now().toUtc(),
    );
  }

  @override
  Future<SosSession> getSession(String sosSessionId) async {
    getSessionCallCount++;
    final builder = getSessionResponseBuilder;
    if (builder != null) return builder(sosSessionId);
    return SosSession(
      sosSessionId: sosSessionId,
      familyId: 'family-1',
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: DateTime.now().toUtc(),
      receivedAtUtc: DateTime.now().toUtc(),
    );
  }
}
