/// Fixed family-circle role set — mirrors the backend's
/// `SafePath.Domain.Enums.Role` enum exactly (AUTH-05). [wireValue] is the
/// literal string the backend sends/expects (JSON string-enum
/// serialization, see `01-01-SUMMARY.md`).
enum Role {
  guardian('Guardian'),
  member('Member'),
  caregiver('Caregiver'),
  orgAdmin('OrgAdmin');

  const Role(this.wireValue);

  final String wireValue;

  static Role fromWire(String value) => Role.values.firstWhere(
    (role) => role.wireValue == value,
    orElse: () => throw ArgumentError('Unknown role: $value'),
  );
}

/// Request body for `POST /auth/register`.
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
  });

  final String email;
  final String password;
  final String fullName;
  final Role role;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'fullName': fullName,
    'role': role.wireValue,
  };
}

/// Request body for `POST /auth/login`.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// Success response shape shared by `/auth/register`, `/auth/login`, and
/// `/auth/refresh` (backend's `AuthResult` with `succeeded: true`).
class AuthResponse {
  const AuthResponse({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}
