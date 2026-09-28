import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/native_geofence_gateway.dart';

sealed class GeofenceRegistrationState {
  const GeofenceRegistrationState();
}

class GeofenceRegistrationIdle extends GeofenceRegistrationState {
  const GeofenceRegistrationIdle();
}

class GeofenceRegistrationSyncing extends GeofenceRegistrationState {
  const GeofenceRegistrationSyncing();
}

class GeofenceRegistrationReady extends GeofenceRegistrationState {
  const GeofenceRegistrationReady({this.generation});
  final int? generation;
}

class GeofenceRegistrationNeedsLocationPermission
    extends GeofenceRegistrationState {
  const GeofenceRegistrationNeedsLocationPermission();
}

class GeofenceRegistrationNeedsSync extends GeofenceRegistrationState {
  const GeofenceRegistrationNeedsSync(this.message);
  final String message;
}

/// Mirrors the authenticated server registration into Android. No permission
/// prompt runs from build: a zone-save flow explicitly calls
/// [requestBackgroundPermissionForSave] in a later UI plan.
class GeofenceRegistrationController
    extends Notifier<GeofenceRegistrationState> {
  int _syncGeneration = 0;

  @override
  GeofenceRegistrationState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        unawaited(sync());
      } else if (next is AuthUnauthenticated) {
        unawaited(clearOnLogout());
      }
    });
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      Future.microtask(sync);
    }
    return const GeofenceRegistrationIdle();
  }

  Future<void> sync() async {
    final request = ++_syncGeneration;
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;
    state = const GeofenceRegistrationSyncing();
    final gateway = ref.read(nativeGeofenceGatewayProvider);
    var stage = 'capability';
    try {
      _log('request=$request stage=$stage start');
      final capability = await gateway.getCapability();
      if (request != _syncGeneration ||
          ref.read(authControllerProvider) is! AuthAuthenticated) {
        return;
      }
      _log('request=$request capability=${capability.name}');
      if (capability != NativeGeofenceCapability.ready) {
        state =
            capability == NativeGeofenceCapability.needsLocationPermission ||
                capability == NativeGeofenceCapability.needsBackgroundPermission
            ? const GeofenceRegistrationNeedsLocationPermission()
            : const GeofenceRegistrationNeedsSync(
                'Geofencing is unavailable on this device.',
              );
        return;
      }
      stage = 'fetch';
      _log('request=$request stage=$stage start');
      final registrations = await ref
          .read(geofenceRegistrationApiProvider)
          .fetchRegistrations();
      if (request != _syncGeneration ||
          ref.read(authControllerProvider) is! AuthAuthenticated) {
        return;
      }
      final zones = registrations
          .map((registration) => registration.toNativeZone())
          .toList(growable: false);
      stage = 'native-replace';
      final generation = registrations.isEmpty
          ? null
          : registrations
                .map((registration) => registration.generation)
                .reduce((a, b) => a > b ? a : b);
      _log(
        'request=$request stage=$stage start count=${registrations.length} generation=$generation',
      );
      await gateway.replaceMonitoredZones(zones);
      if (request != _syncGeneration ||
          ref.read(authControllerProvider) is! AuthAuthenticated) {
        return;
      }
      for (final registration in registrations) {
        // Native success is intentionally ordered before the exact server
        // generation acknowledgement; stale generations are never claimed.
        stage = 'acknowledge';
        _log(
          'request=$request stage=$stage start generation=${registration.generation}',
        );
        await ref
            .read(geofenceRegistrationApiProvider)
            .acknowledgeRegistration(
              registration.zoneId,
              registration.generation,
            );
      }
      if (request == _syncGeneration) {
        _log('request=$request ready count=${registrations.length}');
        state = GeofenceRegistrationReady(generation: generation);
      }
    } catch (error) {
      // Exception messages/details can contain network credentials or coordinates.
      final code = error is PlatformException ? error.code : error.runtimeType;
      _log('request=$request stage=$stage failed code=$code');
      if (request == _syncGeneration) {
        state = GeofenceRegistrationNeedsSync(error.toString());
      }
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('GeofenceRegistration: $message');
  }

  Future<void> requestBackgroundPermissionForSave() async {
    final capability = await ref
        .read(nativeGeofenceGatewayProvider)
        .requestBackgroundCapability();
    if (capability == NativeGeofenceCapability.ready) {
      await sync();
    } else {
      state =
          capability == NativeGeofenceCapability.needsLocationPermission ||
              capability == NativeGeofenceCapability.needsBackgroundPermission
          ? const GeofenceRegistrationNeedsLocationPermission()
          : const GeofenceRegistrationNeedsSync(
              'Geofencing is unavailable on this device.',
            );
    }
  }

  Future<void> clearOnLogout() async {
    _syncGeneration++;
    try {
      await ref
          .read(nativeGeofenceGatewayProvider)
          .replaceMonitoredZones(const []);
    } catch (_) {
      // Logout must not be blocked by a routine monitoring cleanup failure.
    }
    state = const GeofenceRegistrationIdle();
  }
}

final geofenceRegistrationControllerProvider =
    NotifierProvider<GeofenceRegistrationController, GeofenceRegistrationState>(
      GeofenceRegistrationController.new,
    );
