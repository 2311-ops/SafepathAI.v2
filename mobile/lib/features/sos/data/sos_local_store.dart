import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sos_models.dart';

const _sessionIdKey = 'sos.sessionId';
const _pendingTriggerKey = 'sos.pendingTrigger';

/// Device-local persistence for the in-progress SOS session id and, once
/// plan 03-07 lands, the last un-acknowledged trigger payload — so an
/// offline/killed-app trigger resumes as the same emergency rather than a
/// new one (D-13/D-14/D-15).
abstract class SosLocalStore {
  Future<String?> readSessionId();
  Future<void> writeSessionId(String id);
  Future<void> clear();

  /// The last trigger request that has not yet been acknowledged by the
  /// server — consumed by plan 03-07's offline-resume flow.
  Future<SosTriggerRequest?> readPendingTrigger();
  Future<void> writePendingTrigger(SosTriggerRequest request);
}

class SharedPreferencesSosLocalStore implements SosLocalStore {
  const SharedPreferencesSosLocalStore();

  @override
  Future<String?> readSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionIdKey);
  }

  @override
  Future<void> writeSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, id);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_pendingTriggerKey);
  }

  @override
  Future<SosTriggerRequest?> readPendingTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingTriggerKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SosTriggerRequest.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      // A corrupted/unreadable pending-trigger payload must never crash the
      // arm path — treat it as absent.
      return null;
    }
  }

  @override
  Future<void> writePendingTrigger(SosTriggerRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTriggerKey, jsonEncode(request.toJson()));
  }
}

final sosLocalStoreProvider = Provider<SosLocalStore>((ref) {
  const store = SharedPreferencesSosLocalStore();
  ref.onDispose(() {});
  return store;
});
