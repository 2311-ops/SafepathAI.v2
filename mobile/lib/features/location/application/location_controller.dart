import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/auth_api.dart';
import '../../family/application/family_controller.dart';
import 'permission_controller.dart';
import '../data/location_api.dart';
import '../data/location_hub_client.dart';
import '../data/location_models.dart';

class MemberPresence {
  const MemberPresence({required this.isOnline});

  final bool isOnline;
}

class LocationState {
  const LocationState({
    this.selfPosition,
    this.members = const {},
    this.memberPresence = const {},
    this.lowBatteryAlert,
    this.isLoading = false,
    this.error,
  });

  final LiveLocation? selfPosition;
  final Map<String, LiveLocation> members;
  final Map<String, MemberPresence> memberPresence;
  final LowBatteryAlert? lowBatteryAlert;
  final bool isLoading;
  final String? error;

  LocationState copyWith({
    LiveLocation? selfPosition,
    Map<String, LiveLocation>? members,
    Map<String, MemberPresence>? memberPresence,
    LowBatteryAlert? lowBatteryAlert,
    bool clearLowBatteryAlert = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LocationState(
      selfPosition: selfPosition ?? this.selfPosition,
      members: members ?? this.members,
      memberPresence: memberPresence ?? this.memberPresence,
      lowBatteryAlert: clearLowBatteryAlert
          ? null
          : (lowBatteryAlert ?? this.lowBatteryAlert),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool isMemberOnline(String userId) =>
      memberPresence[userId]?.isOnline ?? members[userId]?.isOnline ?? false;
}

final positionStreamProvider = Provider<Stream<Position>>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
});

final batteryLevelProvider = FutureProvider.autoDispose<int?>((ref) async {
  return Battery().batteryLevel;
});

class LocationController extends AsyncNotifier<LocationState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<LiveLocation>? _locationSubscription;
  StreamSubscription<PresenceChange>? _presenceSubscription;
  StreamSubscription<LowBatteryAlert>? _lowBatterySubscription;
  LocationHubClient? _hubClient;
  String? _connectedFamilyId;
  int _generation = 0;
  int _bootstrapToken = 0;
  int? _hubOwnerToken;

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
    ref.listen<PermissionPrimingState>(permissionControllerProvider, (
      previous,
      next,
    ) {
      if (next.isGranted) {
        _bootstrap();
      } else {
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
    final permission = ref.read(permissionControllerProvider);
    if (!permission.isGranted) {
      await _stop(clearState: true);
      return;
    }

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

    final bootstrapToken = ++_bootstrapToken;
    await _stop(clearState: false, invalidateBootstrap: false);
    final generation = _generation;
    if (!_ownsBootstrap(familyId, bootstrapToken, generation)) return;

    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));

    try {
      final initialLocations = await ref
          .read(locationApiProvider)
          .getLiveLocations(familyId);
      if (!_ownsBootstrap(familyId, bootstrapToken, generation)) return;

      final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
      final initialMembers = {
        for (final location in initialLocations) location.userId: location,
      };
      final initialPresence = {
        for (final location in initialLocations)
          location.userId: MemberPresence(isOnline: location.isOnline),
      };
      final selfPosition = currentUserId == null
          ? null
          : initialMembers[currentUserId];
      state = AsyncData(
        LocationState(
          selfPosition: selfPosition,
          members: initialMembers,
          memberPresence: initialPresence,
          isLoading: false,
        ),
      );

      final hubClient = ref.read(locationHubClientProvider);
      _hubClient = hubClient;
      _hubOwnerToken = bootstrapToken;
      await hubClient.connect(familyId);
      if (!_ownsBootstrap(familyId, bootstrapToken, generation)) {
        if (_hubOwnerToken == null || _hubOwnerToken == bootstrapToken) {
          await hubClient.disconnect();
          if (_hubClient == hubClient) {
            _hubClient = null;
            _hubOwnerToken = null;
          }
        }
        return;
      }

      final locationSubscription = hubClient.locationUpdates.listen(
        _applyLocation,
      );
      final presenceSubscription = hubClient.presenceChanges.listen(
        _applyPresence,
      );
      final lowBatterySubscription = hubClient.lowBatteryAlerts.listen(
        _applyLowBatteryAlert,
      );
      final positionSubscription = ref
          .read(positionStreamProvider)
          .listen(_reportPosition, onError: (_) {});
      if (!_ownsBootstrap(familyId, bootstrapToken, generation)) {
        await locationSubscription.cancel();
        await presenceSubscription.cancel();
        await lowBatterySubscription.cancel();
        await positionSubscription.cancel();
        return;
      }

      _connectedFamilyId = familyId;
      _locationSubscription = locationSubscription;
      _presenceSubscription = presenceSubscription;
      _lowBatterySubscription = lowBatterySubscription;
      _positionSubscription = positionSubscription;
    } on LocationApiException catch (error) {
      if (bootstrapToken != _bootstrapToken || generation != _generation) {
        return;
      }
      _connectedFamilyId = null;
      if (_hubOwnerToken == bootstrapToken) {
        _hubClient = null;
        _hubOwnerToken = null;
      }
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
    } catch (_) {
      if (bootstrapToken != _bootstrapToken || generation != _generation) {
        return;
      }
      _connectedFamilyId = null;
      if (_hubOwnerToken == bootstrapToken) {
        _hubClient = null;
        _hubOwnerToken = null;
      }
      state = AsyncData(
        _current.copyWith(
          isLoading: false,
          error: "Couldn't connect. Check your connection and try again.",
        ),
      );
    }
  }

  Future<void> _stop({
    bool clearState = true,
    bool invalidateBootstrap = true,
  }) async {
    if (invalidateBootstrap) {
      _bootstrapToken++;
    }
    _generation++;
    _connectedFamilyId = null;
    final hubClient = _hubClient;
    _hubClient = null;
    _hubOwnerToken = null;
    await _positionSubscription?.cancel();
    await _locationSubscription?.cancel();
    await _presenceSubscription?.cancel();
    await _lowBatterySubscription?.cancel();
    _positionSubscription = null;
    _locationSubscription = null;
    _presenceSubscription = null;
    _lowBatterySubscription = null;
    await hubClient?.disconnect();
    if (clearState) {
      state = const AsyncData(LocationState());
    }
  }

  Future<void> _reportPosition(Position position) async {
    final familyId = _connectedFamilyId;
    final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
    if (familyId == null ||
        currentUserId == null ||
        !_canReport(familyId, currentUserId)) {
      return;
    }

    int? batteryPercent;
    try {
      ref.invalidate(batteryLevelProvider);
      batteryPercent = await ref.read(batteryLevelProvider.future);
    } catch (_) {
      batteryPercent = null;
    }

    if (!_canReport(familyId, currentUserId)) return;

    final payload = ReportLocationPayload(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      batteryPercent: batteryPercent,
      recordedAtUtc: position.timestamp.toUtc(),
    );
    final hubClient = _hubClient;
    if (hubClient == null) return;

    await hubClient.reportLocation(payload);
    if (!_canReport(familyId, currentUserId)) return;

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

  bool _ownsBootstrap(String familyId, int bootstrapToken, int generation) {
    return bootstrapToken == _bootstrapToken &&
        _canStream(familyId, generation);
  }

  bool _canStream(String familyId, int generation) {
    return generation == _generation && _canUseLocationPipeline(familyId);
  }

  bool _canReport(String familyId, String userId) {
    return ref.read(authApiProvider).currentSession?.user.id == userId &&
        _connectedFamilyId == familyId &&
        _canUseLocationPipeline(familyId);
  }

  bool _canUseLocationPipeline(String familyId) {
    final authState = ref.read(authControllerProvider);
    final currentFamilyId = ref
        .read(familyControllerProvider)
        .value
        ?.family
        ?.id;
    return ref.read(permissionControllerProvider).isGranted &&
        authState is AuthAuthenticated &&
        currentFamilyId == familyId;
  }

  void _applyLocation(LiveLocation location) {
    final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
    final existing = _current.members[location.userId];
    final mergedLocation = existing == null
        ? location
        : location.copyWith(
            displayName: location.displayName ?? existing.displayName,
            isOnline:
                _current.memberPresence[location.userId]?.isOnline ??
                location.isOnline,
          );
    final nextMembers = Map<String, LiveLocation>.from(_current.members)
      ..[location.userId] = mergedLocation;
    final nextPresence =
        Map<String, MemberPresence>.from(_current.memberPresence)..putIfAbsent(
          location.userId,
          () => MemberPresence(isOnline: location.isOnline),
        );
    state = AsyncData(
      _current.copyWith(
        selfPosition: location.userId == currentUserId
            ? mergedLocation
            : _current.selfPosition,
        members: nextMembers,
        memberPresence: nextPresence,
        isLoading: false,
        clearError: true,
      ),
    );
  }

  void _applyPresence(PresenceChange change) {
    final nextPresence = Map<String, MemberPresence>.from(
      _current.memberPresence,
    )..[change.userId] = MemberPresence(isOnline: change.isOnline);
    state = AsyncData(
      _current.copyWith(memberPresence: nextPresence, clearError: true),
    );
  }

  void _applyLowBatteryAlert(LowBatteryAlert alert) {
    state = AsyncData(
      _current.copyWith(lowBatteryAlert: alert, clearError: true),
    );
  }

  void dismissLowBatteryAlert() {
    state = AsyncData(_current.copyWith(clearLowBatteryAlert: true));
  }
}

final locationControllerProvider =
    AsyncNotifierProvider<LocationController, LocationState>(
      LocationController.new,
    );
