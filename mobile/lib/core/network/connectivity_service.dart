import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network-interface connectivity, exposed as a **hint only**.
///
/// `connectivity_plus` reports whether a network interface exists (Wi-Fi,
/// cellular, ethernet, ...) — it does not and cannot know whether the
/// SafePath API is actually reachable. A captive portal, a VPN with no
/// route to the backend, or a dead server all look identically "connected"
/// through this stream (03-RESEARCH.md "Anti-Patterns to Avoid": don't
/// treat `connectivity_plus` as ground truth for "can reach the server").
///
/// The SOS offline-retry loop in `SosController` is therefore driven by the
/// actual HTTP call's success/failure/timeout — this service is consulted
/// only as a secondary hint to retry sooner when an interface reappears,
/// never to decide whether to attempt a send at all.
abstract class ConnectivityService {
  /// Emits `true` whenever at least one network interface is reporting a
  /// connection, `false` when every interface reports none. A `true` event
  /// here means "worth retrying sooner," not "the server is reachable."
  Stream<bool> get onConnectivityChanged;

  /// A one-shot read of the current interface state, for callers that need
  /// a snapshot rather than a stream.
  Future<bool> get isConnected;
}

class ConnectivityPlusConnectivityService implements ConnectivityService {
  ConnectivityPlusConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_hasAnyInterface);

  @override
  Future<bool> get isConnected async =>
      _hasAnyInterface(await _connectivity.checkConnectivity());

  bool _hasAnyInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityPlusConnectivityService();
  ref.onDispose(() {});
  return service;
});
