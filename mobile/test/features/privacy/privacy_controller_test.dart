import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/privacy/application/privacy_controller.dart';
import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_privacy_api.dart';

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({required this.session});

  sb.Session? session;
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => session;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  void dispose() => _controller.close();

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> updateRoleMetadata(Role role) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() => throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
}

sb.Session _session() {
  return sb.Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: sb.User(
      id: 'self-user',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

ProviderContainer _container({
  required _FakeAuthApi authApi,
  required FakeFamilyApi familyApi,
  required FakePrivacyApi privacyApi,
  DateTime? now,
}) {
  return ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(authApi),
      familyApiProvider.overrideWithValue(familyApi),
      privacyApiProvider.overrideWithValue(privacyApi),
      if (now != null) privacyNowProvider.overrideWithValue(() => now),
    ],
  );
}

void main() {
  late _FakeAuthApi authApi;
  late FakeFamilyApi familyApi;
  late FakePrivacyApi privacyApi;
  late ProviderContainer container;

  setUp(() {
    authApi = _FakeAuthApi(session: _session());
    familyApi = FakeFamilyApi()
      ..myFamiliesToReturn = const [
        MyFamily(
          familyId: 'fam-1',
          familyName: 'Safe circle',
          role: Role.guardian,
          permissions: PermissionLevel.fullLocation,
        ),
      ]
      ..membersByFamilyId['fam-1'] = [
        FamilyMemberView(
          memberId: 'mem-self',
          userId: 'self-user',
          role: Role.guardian,
          permission: PermissionLevel.fullLocation,
          joinedAt: DateTime.utc(2026, 7, 12),
        ),
        FamilyMemberView(
          memberId: 'mem-recipient',
          userId: 'recipient-user',
          role: Role.member,
          permission: PermissionLevel.fullLocation,
          joinedAt: DateTime.utc(2026, 7, 12),
        ),
      ];
    privacyApi = FakePrivacyApi()
      ..matrixToReturn = const SharingMatrix(
        entries: [
          SharingCell(
            recipientId: 'mem-recipient',
            recipientName: 'Recipient',
            dataType: SharedDataType.liveLocation,
            isEnabled: true,
          ),
        ],
      );
    container = _container(
      authApi: authApi,
      familyApi: familyApi,
      privacyApi: privacyApi,
      now: DateTime.utc(2026, 7, 12, 10),
    );
  });

  tearDown(() {
    container.dispose();
    authApi.dispose();
  });

  test('loads the sharing matrix when auth and family are available', () async {
    container.read(familyControllerProvider);
    await pumpEventQueue();

    container.read(privacyControllerProvider);
    await pumpEventQueue();

    final state = container.read(privacyControllerProvider).value!;
    expect(privacyApi.getSharingMatrixCallCount, 1);
    expect(privacyApi.lastFamilyId, 'fam-1');
    expect(
      state.matrix.isEnabled('mem-recipient', SharedDataType.liveLocation),
      isTrue,
    );
  });

  test('toggle failure reverts optimistic state and surfaces UI copy', () async {
    container.read(familyControllerProvider);
    await pumpEventQueue();
    container.read(privacyControllerProvider);
    await pumpEventQueue();

    privacyApi.updateError = PrivacyApiException(
      PrivacyApiIssue.network,
      message: "Couldn't save that setting. Check your connection and try again.",
    );

    await container.read(privacyControllerProvider.notifier).toggle(
      recipientId: 'mem-recipient',
      dataType: SharedDataType.liveLocation,
      enabled: false,
    );

    final state = container.read(privacyControllerProvider).value!;
    expect(
      state.matrix.isEnabled('mem-recipient', SharedDataType.liveLocation),
      isTrue,
    );
    expect(
      state.error,
      "Couldn't save that setting. Check your connection and try again.",
    );
  });

  test('temporary share sets expiry and exposes remaining time', () async {
    container.read(familyControllerProvider);
    await pumpEventQueue();
    container.read(privacyControllerProvider);
    await pumpEventQueue();

    await container.read(privacyControllerProvider.notifier).startTemporaryShare(
      recipientId: 'mem-recipient',
      dataType: SharedDataType.history,
      duration: const Duration(hours: 4),
    );

    final state = container.read(privacyControllerProvider).value!;
    expect(privacyApi.lastExpiresAtUtc, DateTime.utc(2026, 7, 12, 14));
    expect(
      state.timeRemaining(
        'mem-recipient',
        SharedDataType.history,
        now: DateTime.utc(2026, 7, 12, 10, 30),
      ),
      const Duration(hours: 3, minutes: 30),
    );
  });
}
