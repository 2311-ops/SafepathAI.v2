import 'package:mobile/features/sos/data/device_token_api.dart';

/// Hand-written [DeviceTokenApi] fake (no mocking package — matches
/// `fake_sos_api.dart`/`fake_location_api.dart`'s convention). Records every
/// call so tests can assert exact call counts/arguments.
class FakeDeviceTokenApi implements DeviceTokenApi {
  final List<({String token, String platform})> registerCalls = [];
  final List<String> removeCalls = [];
  final List<String> confirmPushReceiptCalls = [];

  @override
  Future<void> register(String token, String platform) async {
    registerCalls.add((token: token, platform: platform));
  }

  @override
  Future<void> remove(String token) async {
    removeCalls.add(token);
  }

  @override
  Future<void> confirmPushReceipt(String sosSessionId) async {
    confirmPushReceiptCalls.add(sosSessionId);
  }
}
