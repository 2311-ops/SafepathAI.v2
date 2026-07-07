import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';

/// The values entered on [RegisterScreen], carried forward to
/// [RoleSelectScreen] via `GoRouterState.extra` so the final `register()`
/// call has everything it needs in one place.
class RegisterDraft {
  const RegisterDraft({
    required this.email,
    required this.password,
    required this.fullName,
  });

  final String email;
  final String password;
  final String fullName;
}

/// Register — `#ECF0EF` bg, back-arrow header, FULL NAME/EMAIL/PASSWORD
/// fields, teal "Continue" CTA (per `01-UI-SPEC.md`).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
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

  String? _validateFullName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter your full name';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) return 'Use at least 8 characters';
    return null;
  }

  void _onContinue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.push(
      '/register/role',
      extra: RegisterDraft(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create account', style: AppTypography.heading),
                const SizedBox(height: AppSpacing.xl),
                SafePathTextField(
                  label: 'Full name',
                  controller: _fullNameController,
                  validator: _validateFullName,
                ),
                const SizedBox(height: AppSpacing.md),
                SafePathTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.md),
                SafePathTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(label: 'Continue', onPressed: _onContinue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
