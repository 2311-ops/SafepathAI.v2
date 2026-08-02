import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart' as signalr;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/supabase_client_provider.dart';
import '../../../core/network/dio_client.dart';
import 'sos_models.dart';

enum SosHubConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
}

/// Client contract for the dedicated `/hubs/alert` SignalR hub
/// (`backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs`,
/// 03-03-PLAN.md). Structurally separate from `LocationHubClient` — nothing
/// in this feature ever touches the routine location hub (Core Value).
abstract class SosHubClient {
  Future<void> connect(String familyId);

  Future<void> disconnect();

  /// Invokes the hub's receipt-confirmation method — the explicit downstream
  /// signal that makes "Delivered" truthful (T-03-16/T-03-17 mitigations
  /// live on the connection itself, see [SignalRSosHubClient]).
  Future<void> confirmReceipt(String sosSessionId);

  Stream<SosSession> get sosTriggered;

  Stream<SosDeliveryStatusChange> get deliveryStatusChanges;

  Stream<SosCancellation> get sosCanceled;

  Stream<SosLocationUpdate> get liveLocationUpdates;

  SosHubConnectionState get state;

  Stream<SosHubConnectionState> get stateChanges;

  void dispose();
}

class SignalRSosHubClient implements SosHubClient {
  SignalRSosHubClient({
    required sb.SupabaseClient supabase,
    required String apiBaseUrl,
  }) : this._(supabase, apiBaseUrl);

  SignalRSosHubClient._(this._supabase, this._apiBaseUrl);

  final sb.SupabaseClient _supabase;
  final String _apiBaseUrl;

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

  signalr.HubConnection? _connection;
  StreamSubscription<signalr.HubConnectionState>? _stateSubscription;
  SosHubConnectionState _state = SosHubConnectionState.disconnected;
  int _generation = 0;

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
    await disconnect();
    // Claim this connection attempt's generation *after* disconnect() (which
    // bumps the generation for any connection it tears down) so a concurrent
    // disconnect() fired while we were awaiting the teardown above can't
    // later invalidate us too. Copied verbatim from location_hub_client.dart
    // — this is what prevents a stale reconnect race (T-03-17) from wiring a
    // superseded connection to the live streams.
    final generation = ++_generation;
    _setState(SosHubConnectionState.connecting);

    final connection = signalr.HubConnectionBuilder()
        .withUrl(
          _alertHubUrl(familyId),
          options: signalr.HttpConnectionOptions(
            accessTokenFactory: () async =>
                _supabase.auth.currentSession?.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    connection.on('SosTriggered', _handleSosTriggered);
    connection.on('DeliveryStatusChanged', _handleDeliveryStatusChanged);
    connection.on('SosCanceled', _handleSosCanceled);
    connection.on('LiveLocationWindowUpdate', _handleLiveLocationWindowUpdate);
    connection.onreconnecting(
      ({Exception? error}) =>
          _setStateIfCurrent(generation, SosHubConnectionState.reconnecting),
    );
    connection.onreconnected(
      ({String? connectionId}) =>
          _setStateIfCurrent(generation, SosHubConnectionState.connected),
    );
    connection.onclose(
      ({Exception? error}) =>
          _setStateIfCurrent(generation, SosHubConnectionState.disconnected),
    );

    if (generation != _generation) return;

    final stateSubscription = connection.stateStream.listen(
      (next) => _setStateIfCurrent(generation, _mapSignalRState(next)),
    );

    if (generation != _generation) {
      await stateSubscription.cancel();
      await connection.stop();
      return;
    }

    _stateSubscription = stateSubscription;
    _connection = connection;

    try {
      await connection.start();
      _setStateIfCurrent(generation, SosHubConnectionState.connected);
    } catch (_) {
      _setStateIfCurrent(generation, SosHubConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    final connection = _connection;
    _connection = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;

    if (connection == null ||
        connection.state == signalr.HubConnectionState.Disconnected) {
      _setState(SosHubConnectionState.disconnected);
      return;
    }

    _setState(SosHubConnectionState.disconnecting);
    await connection.stop();
    _setState(SosHubConnectionState.disconnected);
  }

  void _setStateIfCurrent(int generation, SosHubConnectionState next) {
    if (generation == _generation) {
      _setState(next);
    }
  }

  @override
  Future<void> confirmReceipt(String sosSessionId) async {
    final connection = _connection;
    if (connection == null ||
        connection.state != signalr.HubConnectionState.Connected) {
      return;
    }
    await connection.invoke('ConfirmReceipt', args: [sosSessionId]);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_sosTriggered.close());
    unawaited(_deliveryStatusChanges.close());
    unawaited(_sosCanceled.close());
    unawaited(_liveLocationUpdates.close());
    unawaited(_stateChanges.close());
  }

  String _alertHubUrl(String familyId) {
    final base = _apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    const path = '/hubs/alert';
    return '$base$path?familyId=${Uri.encodeQueryComponent(familyId)}';
  }

  void _handleSosTriggered(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _sosTriggered.add(SosSession.fromJson(json));
    } catch (_) {
      // A malformed emergency payload must never take down the connection
      // carrying the rest of the emergency (T-03-16).
    }
  }

  void _handleDeliveryStatusChanged(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _deliveryStatusChanges.add(SosDeliveryStatusChange.fromJson(json));
    } catch (_) {
      // See _handleSosTriggered.
    }
  }

  void _handleSosCanceled(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _sosCanceled.add(SosCancellation.fromJson(json));
    } catch (_) {
      // See _handleSosTriggered.
    }
  }

  void _handleLiveLocationWindowUpdate(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _liveLocationUpdates.add(SosLocationUpdate.fromJson(json));
    } catch (_) {
      // See _handleSosTriggered.
    }
  }

  Map<String, dynamic>? _firstJsonArgument(List<Object?>? arguments) {
    final first = arguments == null || arguments.isEmpty
        ? null
        : arguments.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  void _setState(SosHubConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateChanges.isClosed) {
      _stateChanges.add(next);
    }
  }

  SosHubConnectionState _mapSignalRState(signalr.HubConnectionState state) {
    switch (state) {
      case signalr.HubConnectionState.Connecting:
        return SosHubConnectionState.connecting;
      case signalr.HubConnectionState.Connected:
        return SosHubConnectionState.connected;
      case signalr.HubConnectionState.Disconnecting:
        return SosHubConnectionState.disconnecting;
      case signalr.HubConnectionState.Reconnecting:
        return SosHubConnectionState.reconnecting;
      case signalr.HubConnectionState.Disconnected:
        return SosHubConnectionState.disconnected;
    }
  }
}

final sosHubClientProvider = Provider<SosHubClient>((ref) {
  final client = SignalRSosHubClient(
    supabase: ref.watch(supabaseClientProvider),
    apiBaseUrl: apiBaseUrl,
  );
  ref.onDispose(client.dispose);
  return client;
});
