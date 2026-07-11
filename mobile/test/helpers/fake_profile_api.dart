import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

class FakeProfileApi implements ProfileApi {
  FakeProfileApi({
    this.role = Role.guardian,
    this.userId = 'fake-user-id',
    this.email = 'ada@family.com',
    this.fullName = 'Ada Guardian',
  });

  Role? role;
  String userId;
  String? email;
  String? fullName;
  bool shouldThrowNetwork = false;
  int getMeCallCount = 0;
  int updateRoleCallCount = 0;
  Role? lastUpdatedRole;

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
    );
  }
}
