import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/auth_api.dart';
import '../../family/application/family_controller.dart';
import '../data/location_api.dart';
import '../data/location_hub_client.dart';
import '../data/location_models.dart';

class LocationState {
  const LocationState({
    this.selfPosition,
    this.members = const {},
    this.isLoading = false,
    this.error,
  });

  final LiveLocation? selfPosition;
  final Map<String, LiveLocation> members;
  final bool isLoading;
  final String? error;

  LocationState copyWith({
    LiveLocation? selfPosition,
    Map<String, LiveLocation>? members,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LocationState(
      selfPosition: selfPosition ?? this.selfPosition,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final positionStreamProvider = Provider<Stream<Position>>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
});

final batteryLevelProvider = FutureProvider<int?>((ref) async {
  return Battery().batteryLevel;
});

class LocationController extends AsyncNotifier<LocationState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<LiveLocation>? _locationSubscription;
  StreamSubscription<PresenceChange>? _presenceSubscription;
  LocationHubClient? _hubClient;
  String? _connectedFamilyId;

  @override
  LocationState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        _bootstrap();
      } else if (next is AuthUnauthenticated) {
        unawaited(_stop());
      }
    });
    ref.listen<AsyncValue<FamilyState>>(familyControllerProvider, (
      previous,
      next,
    ) {
      if (next.value?.family != null) {
        _bootstrap();
      } else if (!(next.value?.isLoading ?? false)) {
        unawaited(_stop(clearState: true));
      }
    });
    ref.onDispose(() {
      unawaited(_stop(clearState: false));
    });

    Future.microtask(_bootstrap);
    return const LocationState(isLoading: true);
  }

  LocationState get _current => state.value ?? const LocationState();

  Future<void> _bootstrap() async {
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      await _stop();
      return;
    }

    final familyState = ref.read(familyControllerProvider).value;
    final familyId = familyState?.family?.id;
    if (familyId == null || familyId.isEmpty) {
      state = const AsyncData(LocationState());
      return;
    }

    if (_connectedFamilyId == familyId) return;

    await _stop(clearState: false);
    _connectedFamilyId = familyId;
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));

    try {
      final initialLocations = await ref
          .read(locationApiProvider)
          .getLiveLocations(familyId);
      final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
      final initialMembers = {
        for (final location in initialLocations) location.userId: location,
      };
      final selfPosition = currentUserId == null
          ? null
          : initialMembers[currentUserId];
      state = AsyncData(
        LocationState(
          selfPosition: selfPosition,
          members: initialMembers,
          isLoading: false,
        ),
      );

      final hubClient = ref.read(locationHubClientProvider);
      _hubClient = hubClient;
      await hubClient.connect(familyId);
      _locationSubscription = hubClient.locationUpdates.listen(_applyLocation);
      _presenceSubscription = hubClient.presenceChanges.listen((change) {});
      _positionSubscription = ref
          .read(positionStreamProvider)
          .listen(_reportPosition, onError: (_) {});
    } on LocationApiException catch (error) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(
          isLoading: false,
          error: "Couldn't connect. Check your connection and try again.",
        ),
      );
    }
  }

  Future<void> _stop({bool clearState = true}) async {
    _connectedFamilyId = null;
    await _positionSubscription?.cancel();
    await _locationSubscription?.cancel();
    await _presenceSubscription?.cancel();
    _positionSubscription = null;
    _locationSubscription = null;
    _presenceSubscription = null;
    await _hubClient?.disconnect();
    _hubClient = null;
    if (clearState) {
      state = const AsyncData(LocationState());
    }
  }

  Future<void> _reportPosition(Position position) async {
    final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
    if (currentUserId == null) return;

    int? batteryPercent;
    try {
      batteryPercent = await ref.read(batteryLevelProvider.future);
    } catch (_) {
      batteryPercent = null;
    }

    final payload = ReportLocationPayload(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      batteryPercent: batteryPercent,
      recordedAtUtc: position.timestamp.toUtc(),
    );
    await ref.read(locationHubClientProvider).reportLocation(payload);

    _applyLocation(
      LiveLocation(
        userId: currentUserId,
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
        batteryPercent: batteryPercent,
        recordedAtUtc: position.timestamp.toUtc(),
      ),
    );
  }

  void _applyLocation(LiveLocation location) {
    final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
    final nextMembers = Map<String, LiveLocation>.from(_current.members)
      ..[location.userId] = location;
    state = AsyncData(
      _current.copyWith(
        selfPosition: location.userId == currentUserId
            ? location
            : _current.selfPosition,
        members: nextMembers,
        isLoading: false,
        clearError: true,
      ),
    );
  }
}

final locationControllerProvider =
    AsyncNotifierProvider<LocationController, LocationState>(
      LocationController.new,
    );
