import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

class FakeProfileApi implements ProfileApi {
  FakeProfileApi({
    this.role = Role.guardian,
    this.userId = 'fake-user-id',
    this.email = 'ada@family.com',
    this.fullName = 'Ada Guardian',
    this.displayName,
    this.profileImageUrl,
    this.profileUpdatedAt,
  });

  Role? role;
  String userId;
  String? email;
  String? fullName;
  String? displayName;
  String? profileImageUrl;
  DateTime? profileUpdatedAt;
  bool shouldThrowNetwork = false;
  int getMeCallCount = 0;
  int updateRoleCallCount = 0;
  int updateDisplayNameCallCount = 0;
  int uploadProfileImageCallCount = 0;
  int deleteProfileImageCallCount = 0;
  Role? lastUpdatedRole;
  String? lastDisplayName;
  List<int>? lastUploadBytes;
  String? lastUploadFilename;

  @override
  Future<UserProfile> getMe() async {
    getMeCallCount++;
    if (shouldThrowNetwork) {
      throw ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }

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

  @override
  Future<UserProfile> updateRole(Role role) async {
    updateRoleCallCount++;
    lastUpdatedRole = role;
    if (shouldThrowNetwork) {
      throw ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }

    this.role = role;
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

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    updateDisplayNameCallCount++;
    lastDisplayName = displayName;
    if (shouldThrowNetwork) {
      throw ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }

    this.displayName = displayName;
    profileUpdatedAt = DateTime.utc(2026, 7, 13);
    return getMe();
  }

  @override
  Future<UserProfile> uploadProfileImage(
    List<int> bytes,
    String filename,
  ) async {
    uploadProfileImageCallCount++;
    lastUploadBytes = bytes;
    lastUploadFilename = filename;
    if (shouldThrowNetwork) {
      throw ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }

    profileImageUrl = 'https://signed.example/$filename';
    profileUpdatedAt = DateTime.utc(2026, 7, 13);
    return getMe();
  }

  @override
  Future<UserProfile> deleteProfileImage() async {
    deleteProfileImageCallCount++;
    if (shouldThrowNetwork) {
      throw ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }

    profileImageUrl = null;
    profileUpdatedAt = DateTime.utc(2026, 7, 13);
    return getMe();
  }
}
