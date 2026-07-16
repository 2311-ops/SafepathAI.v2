import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart' as signalr;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/supabase_client_provider.dart';
import '../../../core/network/dio_client.dart';
import 'location_models.dart';

enum LocationHubConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
}

abstract class LocationHubClient {
  Future<void> connect(String familyId);

  Future<void> disconnect();

  Future<void> reportLocation(ReportLocationPayload location);

  Stream<LiveLocation> get locationUpdates;

  Stream<PresenceChange> get presenceChanges;

  Stream<LowBatteryAlert> get lowBatteryAlerts;

  Stream<ProfileUpdate> get profileUpdates;

  LocationHubConnectionState get state;

  Stream<LocationHubConnectionState> get stateChanges;

  void dispose();
}

class SignalRLocationHubClient implements LocationHubClient {
  SignalRLocationHubClient({
    required sb.SupabaseClient supabase,
    required String apiBaseUrl,
  }) : this._(supabase, apiBaseUrl);

  SignalRLocationHubClient._(this._supabase, this._apiBaseUrl);

  final sb.SupabaseClient _supabase;
  final String _apiBaseUrl;
  final StreamController<LiveLocation> _locationUpdates =
      StreamController<LiveLocation>.broadcast();
  final StreamController<PresenceChange> _presenceChanges =
      StreamController<PresenceChange>.broadcast();
  final StreamController<LowBatteryAlert> _lowBatteryAlerts =
      StreamController<LowBatteryAlert>.broadcast();
  final StreamController<ProfileUpdate> _profileUpdates =
      StreamController<ProfileUpdate>.broadcast();
  final StreamController<LocationHubConnectionState> _stateChanges =
      StreamController<LocationHubConnectionState>.broadcast();

  signalr.HubConnection? _connection;
  StreamSubscription<signalr.HubConnectionState>? _stateSubscription;
  LocationHubConnectionState _state = LocationHubConnectionState.disconnected;
  int _generation = 0;

  @override
  Stream<LiveLocation> get locationUpdates => _locationUpdates.stream;

  @override
  Stream<PresenceChange> get presenceChanges => _presenceChanges.stream;

  @override
  Stream<LowBatteryAlert> get lowBatteryAlerts => _lowBatteryAlerts.stream;

  @override
  Stream<ProfileUpdate> get profileUpdates => _profileUpdates.stream;

  @override
  LocationHubConnectionState get state => _state;

  @override
  Stream<LocationHubConnectionState> get stateChanges => _stateChanges.stream;

  @override
  Future<void> connect(String familyId) async {
    await disconnect();
    // Claim this connection attempt's generation *after* disconnect() (which bumps
    // the generation for any connection it tears down) so a concurrent disconnect()
    // fired while we were awaiting the teardown above can't later invalidate us too.
    final generation = ++_generation;
    _setState(LocationHubConnectionState.connecting);

    final connection = signalr.HubConnectionBuilder()
        .withUrl(
          _locationHubUrl(familyId),
          options: signalr.HttpConnectionOptions(
            accessTokenFactory: () async =>
                _supabase.auth.currentSession?.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    connection.on('LocationUpdated', _handleLocationUpdated);
    connection.on('PresenceChanged', _handlePresenceChanged);
    connection.on('LowBattery', _handleLowBattery);
    connection.on('ProfileUpdated', _handleProfileUpdated);
    connection.onreconnecting(
      ({Exception? error}) => _setStateIfCurrent(
        generation,
        LocationHubConnectionState.reconnecting,
      ),
    );
    connection.onreconnected(
      ({String? connectionId}) => _setStateIfCurrent(
        generation,
        LocationHubConnectionState.connected,
      ),
    );
    connection.onclose(
      ({Exception? error}) => _setStateIfCurrent(
        generation,
        LocationHubConnectionState.disconnected,
      ),
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
      _setStateIfCurrent(generation, LocationHubConnectionState.connected);
    } catch (_) {
      _setStateIfCurrent(generation, LocationHubConnectionState.disconnected);
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
      _setState(LocationHubConnectionState.disconnected);
      return;
    }

    _setState(LocationHubConnectionState.disconnecting);
    await connection.stop();
    _setState(LocationHubConnectionState.disconnected);
  }

  void _setStateIfCurrent(int generation, LocationHubConnectionState next) {
    if (generation == _generation) {
      _setState(next);
    }
  }

  @override
  Future<void> reportLocation(ReportLocationPayload location) async {
    final connection = _connection;
    if (connection == null ||
        connection.state != signalr.HubConnectionState.Connected) {
      return;
    }
    await connection.invoke('ReportLocation', args: [location.toJson()]);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_locationUpdates.close());
    unawaited(_presenceChanges.close());
    unawaited(_lowBatteryAlerts.close());
    unawaited(_profileUpdates.close());
    unawaited(_stateChanges.close());
  }

  String _locationHubUrl(String familyId) {
    final base = _apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base/hubs/location?familyId=${Uri.encodeQueryComponent(familyId)}';
  }

  void _handleLocationUpdated(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _locationUpdates.add(LiveLocation.fromJson(json));
    } catch (_) {
      // A malformed push must not take down the hub connection's event delivery.
    }
  }

  void _handlePresenceChanged(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _presenceChanges.add(PresenceChange.fromJson(json));
    } catch (_) {
      // A malformed push must not take down the hub connection's event delivery.
    }
  }

  void _handleLowBattery(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _lowBatteryAlerts.add(LowBatteryAlert.fromJson(json));
    } catch (_) {
      // A malformed push must not take down the hub connection's event delivery.
    }
  }

  void _handleProfileUpdated(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);
    if (json == null) return;
    try {
      _profileUpdates.add(ProfileUpdate.fromJson(json));
    } catch (_) {
      // A malformed push must not take down the hub connection's event delivery.
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

  void _setState(LocationHubConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateChanges.isClosed) {
      _stateChanges.add(next);
    }
  }

  LocationHubConnectionState _mapSignalRState(
    signalr.HubConnectionState state,
  ) {
    switch (state) {
      case signalr.HubConnectionState.Connecting:
        return LocationHubConnectionState.connecting;
      case signalr.HubConnectionState.Connected:
        return LocationHubConnectionState.connected;
      case signalr.HubConnectionState.Disconnecting:
        return LocationHubConnectionState.disconnecting;
      case signalr.HubConnectionState.Reconnecting:
        return LocationHubConnectionState.reconnecting;
      case signalr.HubConnectionState.Disconnected:
        return LocationHubConnectionState.disconnected;
    }
  }
}

final locationHubClientProvider = Provider<LocationHubClient>((ref) {
  final client = SignalRLocationHubClient(
    supabase: ref.watch(supabaseClientProvider),
    apiBaseUrl: apiBaseUrl,
  );
  ref.onDispose(client.dispose);
  return client;
});
