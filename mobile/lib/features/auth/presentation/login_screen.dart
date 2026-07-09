import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/google_sign_in_button.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_logo.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Login - same shell as Register (`#ECF0EF` bg, back-arrow header). It now
/// signs users in directly with Supabase Auth and keeps the existing
/// enumeration-safe error surface.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _onLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SafePathLogo(size: 44),
                  const SizedBox(height: AppSpacing.md),
                  Text('Welcome back.', style: AppTypography.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Good to see you again.',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SafePathTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SafePathTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    errorText: errorMessage,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isLoading) _onLogin();
                    },
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: isLoading ? 'Logging in...' : 'Log in',
                    onPressed: isLoading ? null : _onLogin,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const GoogleSignInButton(),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.bodySecondary,
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(
                        "Don't have an account? Create one",
                        style: AppTypography.bodySecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
