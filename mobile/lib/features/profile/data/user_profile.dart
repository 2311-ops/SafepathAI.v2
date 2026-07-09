import '../../auth/data/auth_models.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String userId;
  final String? email;
  final String? fullName;
  final Role? role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'] as String?;
    return UserProfile(
      userId: (json['userId'] ?? json['subject']) as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      role: roleValue == null ? null : Role.fromWire(roleValue),
    );
  }
}
