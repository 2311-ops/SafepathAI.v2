import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

class _FakeAuthApi implements AuthApi {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => null;

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

class _FakeProfileApi implements ProfileApi {
  UserProfile profileToReturn = _profile(displayName: 'Youssef');
  ProfileApiException? exceptionToThrow;

  String? lastDisplayName;
  List<int>? lastUploadBytes;
  String? lastUploadFilename;
  int deleteCallCount = 0;

  @override
  Future<UserProfile> getMe() async => profileToReturn;

  @override
  Future<UserProfile> updateRole(Role role) async => profileToReturn;

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    lastDisplayName = displayName;
    if (exceptionToThrow case final error?) {
      throw error;
    }
    return profileToReturn;
  }

  @override
  Future<UserProfile> uploadProfileImage(
    List<int> bytes,
    String filename,
  ) async {
    lastUploadBytes = bytes;
    lastUploadFilename = filename;
    if (exceptionToThrow case final error?) {
      throw error;
    }
    return profileToReturn;
  }

  @override
  Future<UserProfile> deleteProfileImage() async {
    deleteCallCount++;
    if (exceptionToThrow case final error?) {
      throw error;
    }
    return profileToReturn;
  }
}

UserProfile _profile({
  String userId = 'user-1',
  String? email = 'youssef@example.com',
  String? fullName = 'Youssef Hassan',
  Role role = Role.guardian,
  String? displayName,
  String? profileImageUrl,
  DateTime? profileUpdatedAt,
}) {
  return UserProfile(
    userId: userId,
    email: email,
    fullName: fullName,
    role: role,
    displayName: displayName,
    profileImageUrl: profileImageUrl,
    profileUpdatedAt: profileUpdatedAt,
  );
}

void main() {
  late _FakeProfileApi fakeApi;
  late _FakeAuthApi fakeAuthApi;
  late ProviderContainer container;

  setUp(() {
    fakeApi = _FakeProfileApi();
    fakeAuthApi = _FakeAuthApi();
    container = ProviderContainer(
      overrides: [
        profileApiProvider.overrideWithValue(fakeApi),
        authApiProvider.overrideWithValue(fakeAuthApi),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeAuthApi.dispose();
  });

  test('UserProfile parses profile image fields and display-name fallback', () {
    final updatedAt = DateTime.utc(2026, 7, 13, 15);
    final profile = UserProfile.fromJson({
      'userId': 'user-1',
      'email': 'youssef@example.com',
      'fullName': 'Youssef Hassan',
      'role': 'Guardian',
      'displayName': 'Youssef',
      'profileImageUrl': 'https://signed.example/avatar.jpg',
      'profileUpdatedAt': updatedAt.toIso8601String(),
    });

    expect(profile.displayName, 'Youssef');
    expect(profile.displayNameOrFallback, 'Youssef');
    expect(profile.profileImageUrl, 'https://signed.example/avatar.jpg');
    expect(profile.profileUpdatedAt, updatedAt);

    final fallback = UserProfile.fromJson({
      'userId': 'user-1',
      'fullName': 'Youssef Hassan',
      'displayName': '   ',
    });
    expect(fallback.displayNameOrFallback, 'Youssef Hassan');
  });

  test('updateDisplayName replaces profile from API response', () async {
    fakeApi.profileToReturn = _profile(displayName: 'YH');

    await container
        .read(profileControllerProvider.notifier)
        .updateDisplayName('YH');

    final state = container.read(profileControllerProvider).value!;
    expect(fakeApi.lastDisplayName, 'YH');
    expect(state.profile?.displayName, 'YH');
    expect(state.error, isNull);
    expect(state.isLoading, isFalse);
  });

  test('uploadProfileImage sends bytes and replaces profile', () async {
    final updatedAt = DateTime.utc(2026, 7, 13, 16);
    fakeApi.profileToReturn = _profile(
      displayName: 'Youssef',
      profileImageUrl: 'https://signed.example/new-avatar.jpg',
      profileUpdatedAt: updatedAt,
    );

    await container.read(profileControllerProvider.notifier).uploadProfileImage(
      [1, 2, 3],
      'avatar.jpg',
    );

    final state = container.read(profileControllerProvider).value!;
    expect(fakeApi.lastUploadBytes, [1, 2, 3]);
    expect(fakeApi.lastUploadFilename, 'avatar.jpg');
    expect(state.profile?.profileImageUrl, contains('new-avatar'));
    expect(state.profile?.profileUpdatedAt, updatedAt);
    expect(state.error, isNull);
  });

  test('deleteProfileImage clears avatar from returned profile', () async {
    fakeApi.profileToReturn = _profile(displayName: 'Youssef');

    await container
        .read(profileControllerProvider.notifier)
        .deleteProfileImage();

    final state = container.read(profileControllerProvider).value!;
    expect(fakeApi.deleteCallCount, 1);
    expect(state.profile?.profileImageUrl, isNull);
    expect(state.error, isNull);
  });

  test(
    'profile mutations surface API errors without dropping prior profile',
    () async {
      final initial = _profile(displayName: 'Before');
      fakeApi.profileToReturn = initial;
      await container.read(profileControllerProvider.notifier).refresh();

      fakeApi.exceptionToThrow = ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );

      await container
          .read(profileControllerProvider.notifier)
          .updateDisplayName('After');

      final state = container.read(profileControllerProvider).value!;
      expect(state.profile, initial);
      expect(
        state.error,
        "Couldn't connect. Check your connection and try again.",
      );
      expect(state.isLoading, isFalse);
    },
  );
}
