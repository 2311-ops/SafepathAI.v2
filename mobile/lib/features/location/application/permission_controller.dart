import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus { unknown, denied, deniedForever, granted }

class PermissionPrimingState {
  const PermissionPrimingState({
    this.status = LocationPermissionStatus.unknown,
    this.isChecking = false,
    this.isRequesting = false,
  });

  final LocationPermissionStatus status;
  final bool isChecking;
  final bool isRequesting;

  bool get isGranted => status == LocationPermissionStatus.granted;
  bool get isDeniedForever => status == LocationPermissionStatus.deniedForever;

  PermissionPrimingState copyWith({
    LocationPermissionStatus? status,
    bool? isChecking,
    bool? isRequesting,
  }) {
    return PermissionPrimingState(
      status: status ?? this.status,
      isChecking: isChecking ?? this.isChecking,
      isRequesting: isRequesting ?? this.isRequesting,
    );
  }
}

abstract class LocationPermissionService {
  Future<LocationPermissionStatus> checkPermission();

  Future<LocationPermissionStatus> requestPermission();

  Future<bool> openAppSettings();
}

class GeolocatorLocationPermissionService implements LocationPermissionService {
  const GeolocatorLocationPermissionService();

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  LocationPermissionStatus _map(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationPermissionStatus.granted,
      LocationPermission.deniedForever =>
        LocationPermissionStatus.deniedForever,
      LocationPermission.denied => LocationPermissionStatus.denied,
      LocationPermission.unableToDetermine => LocationPermissionStatus.unknown,
    };
  }
}

final locationPermissionServiceProvider = Provider<LocationPermissionService>(
  (ref) => const GeolocatorLocationPermissionService(),
);

class PermissionController extends Notifier<PermissionPrimingState> {
  @override
  PermissionPrimingState build() {
    Future.microtask(checkPermission);
    return const PermissionPrimingState(isChecking: true);
  }

  Future<LocationPermissionStatus> checkPermission() async {
    final service = ref.read(locationPermissionServiceProvider);
    state = state.copyWith(isChecking: true);
    final status = await service.checkPermission();
    state = state.copyWith(status: status, isChecking: false);
    return status;
  }

  Future<LocationPermissionStatus> requestPermission() async {
    final service = ref.read(locationPermissionServiceProvider);
    state = state.copyWith(isRequesting: true);
    final status = await service.requestPermission();
    state = state.copyWith(status: status, isRequesting: false);
    if (status == LocationPermissionStatus.deniedForever) {
      await service.openAppSettings();
    }
    return status;
  }
}

final permissionControllerProvider =
    NotifierProvider<PermissionController, PermissionPrimingState>(
      PermissionController.new,
    );
