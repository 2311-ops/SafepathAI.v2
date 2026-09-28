import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/network/dio_client.dart';

import '../../helpers/fake_auth_api.dart';

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

  test('ngrok API URLs include the browser warning bypass header', () {
    expect(
      apiDefaultHeadersFor('https://exclude-driving-maternal.ngrok-free.dev'),
      containsPair('ngrok-skip-browser-warning', 'true'),
    );

    final dio = buildDio(
      'https://exclude-driving-maternal.ngrok-free.dev',
      authApi: FakeAuthApi(),
    );

    expect(dio.options.headers['ngrok-skip-browser-warning'], 'true');
  });

  test('non-ngrok API URLs do not include ngrok-specific headers', () {
    expect(
      apiDefaultHeadersFor('http://localhost:5059'),
      isNot(contains('ngrok-skip-browser-warning')),
    );

    final dio = buildDio('http://localhost:5059', authApi: FakeAuthApi());

    expect(dio.options.headers, isNot(contains('ngrok-skip-browser-warning')));
  });
}
