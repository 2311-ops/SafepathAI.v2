import 'package:mobile/features/location/application/permission_controller.dart';

/// A [LocationPermissionService] that always reports [status] (granted by
/// default) instead of hitting the real platform channel, which has no
/// handler registered in widget tests and throws/hangs otherwise. Use this
/// in any test that renders `/home` (wrapped in `LocationPermissionGate`)
/// but isn't itself testing location-permission behavior.
class FakeLocationPermissionService implements LocationPermissionService {
  FakeLocationPermissionService({
    this.status = LocationPermissionStatus.granted,
  });

  LocationPermissionStatus status;

  /// Number of times [openAppSettings] has been called. Additive counter for
  /// tests that need to assert the OS settings seam was actually reached.
  int openAppSettingsCalls = 0;

  @override
  Future<LocationPermissionStatus> checkPermission() async => status;

  @override
  Future<LocationPermissionStatus> requestPermission() async => status;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}
