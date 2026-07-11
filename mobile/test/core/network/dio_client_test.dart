import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/network/dio_client.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('default dev API URL uses Android emulator host alias on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(apiBaseUrl, 'http://10.0.2.2:5059');
  });

  test('default dev API URL keeps localhost on desktop-style platforms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(apiBaseUrl, 'http://localhost:5059');
  });
}
