import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authControllerProvider.notifier).completePasswordReset(
          password: _passwordController.text,
        );

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthUnauthenticated) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isRecovery = authState is AuthRecovery;
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set a new password', style: AppTypography.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isRecovery
                      ? 'Your recovery session is active. Choose a new password now.'
                      : 'Open the reset link from your email on this device to unlock this screen.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xl),
                SafePathTextField(
                  label: 'New password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.md),
                SafePathTextField(
                  label: 'Confirm password',
                  controller: _confirmController,
                  obscureText: true,
                  validator: _validateConfirm,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (errorMessage != null) ...[
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: isLoading ? 'Updating...' : 'Update password',
                  onPressed: isRecovery && !isLoading ? _onSubmit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
