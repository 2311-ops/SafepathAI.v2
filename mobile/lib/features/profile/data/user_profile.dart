import '../../auth/data/auth_models.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.displayName,
    this.profileImageUrl,
    this.profileUpdatedAt,
  });

  final String userId;
  final String? email;
  final String? fullName;
  final Role? role;
  final String? displayName;
  final String? profileImageUrl;
  final DateTime? profileUpdatedAt;

  String get displayNameOrFallback {
    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      return trimmedDisplayName;
    }
    return fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : 'SafePath member';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'] as String?;
    final profileUpdatedAtValue = json['profileUpdatedAt'] as String?;
    return UserProfile(
      userId: (json['userId'] ?? json['subject']) as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      role: roleValue == null ? null : Role.fromWire(roleValue),
      displayName: json['displayName'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      profileUpdatedAt: profileUpdatedAtValue == null
          ? null
          : DateTime.tryParse(profileUpdatedAtValue),
    );
  }
}
