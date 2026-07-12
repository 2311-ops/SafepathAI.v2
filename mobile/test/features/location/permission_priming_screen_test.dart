import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/location/presentation/permission_priming_screen.dart';

class _FakeLocationPermissionService implements LocationPermissionService {
  int checkCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;
  LocationPermissionStatus checkResult = LocationPermissionStatus.denied;
  LocationPermissionStatus requestResult = LocationPermissionStatus.denied;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkCallCount++;
    return checkResult;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestCallCount++;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCallCount++;
    return true;
  }
}

void main() {
  testWidgets(
    'does not request OS permission until the location-sharing CTA is tapped',
    (tester) async {
      final fakePermissionService = _FakeLocationPermissionService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationPermissionServiceProvider.overrideWithValue(
              fakePermissionService,
            ),
          ],
          child: const MaterialApp(home: PermissionPrimingScreen()),
        ),
      );
      await tester.pump();

      expect(fakePermissionService.checkCallCount, 1);
      expect(fakePermissionService.requestCallCount, 0);
      expect(find.text('Turn on location sharing'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Turn on location sharing'));
      await tester.pump();

      expect(fakePermissionService.requestCallCount, 1);
    },
  );
}
