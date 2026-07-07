import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'auth_state.dart';

/// Riverpod controller driving register/login/logout against [AuthApi] +
/// `TokenStorage` (D1: Riverpod, not Bloc).
///
/// TODO(RED): not yet implemented — GREEN commit wires this up.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnknown();

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    // Intentionally incomplete for the RED commit.
  }

  Future<void> login({required String email, required String password}) async {
    // Intentionally incomplete for the RED commit.
  }

  Future<void> logout() async {
    // Intentionally incomplete for the RED commit.
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
