import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../data/profile_api.dart';
import '../data/user_profile.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.error,
    this.isLoading = false,
    this.roleMetadataSynced = false,
  });

  final UserProfile? profile;
  final String? error;
  final bool isLoading;
  final bool roleMetadataSynced;

  ProfileState copyWith({
    UserProfile? profile,
    String? error,
    bool clearError = false,
    bool? isLoading,
    bool? roleMetadataSynced,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      roleMetadataSynced: roleMetadataSynced ?? this.roleMetadataSynced,
    );
  }
}

class ProfileController extends AsyncNotifier<ProfileState> {
  @override
  ProfileState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final wasAuthenticated = previous is AuthAuthenticated;
      if (next is AuthAuthenticated && !wasAuthenticated) {
        refresh();
      } else if (next is AuthUnauthenticated) {
        state = const AsyncData(ProfileState());
      }
    });

    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      Future.microtask(refresh);
      return const ProfileState(isLoading: true);
    }

    return const ProfileState();
  }

  ProfileState get _current => state.value ?? const ProfileState();

  Future<void> refresh() async {
    final api = ref.read(profileApiProvider);
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final profile = await api.getMe();
      state = AsyncData(
        ProfileState(
          profile: profile,
          roleMetadataSynced: _current.roleMetadataSynced,
        ),
      );
    } on ProfileApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          isLoading: false,
          error: error.message ?? 'Unable to load your profile.',
        ),
      );
    }
  }

  Future<void> updateRole(Role role) async {
    final api = ref.read(profileApiProvider);
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final profile = await api.updateRole(role);
      await ref.read(authApiProvider).updateRoleMetadata(role);
      state = AsyncData(
        ProfileState(profile: profile, roleMetadataSynced: true),
      );
    } on ProfileApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          isLoading: false,
          error: error.message ?? 'Unable to save your role.',
        ),
      );
    } on AuthApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          isLoading: false,
          error: error.message ?? 'Unable to save your role.',
        ),
      );
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileState>(
      ProfileController.new,
    );
