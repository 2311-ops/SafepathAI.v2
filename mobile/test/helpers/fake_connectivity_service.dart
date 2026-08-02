import 'dart:async';

import 'package:mobile/core/network/connectivity_service.dart';

/// Hand-written [ConnectivityService] fake (matches `fake_location_api.dart`'s
/// convention — no mocking package). Exposes a public [StreamController] so a
/// test can push connectivity transitions directly, and a settable
/// [isConnected] snapshot.
class FakeConnectivityService implements ConnectivityService {
  bool _isConnected = true;

  final StreamController<bool> connectivityController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => connectivityController.stream;

  @override
  Future<bool> get isConnected async => _isConnected;

  /// Pushes a connectivity transition to any active listener (e.g.
  /// [SosController]'s subscription) and updates the one-shot snapshot to
  /// match.
  void emit(bool connected) {
    _isConnected = connected;
    connectivityController.add(connected);
  }

  Future<void> dispose() => connectivityController.close();
}
