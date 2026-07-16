import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared_widgets/onboarding_scaffold.dart';
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

    await ref
        .read(authControllerProvider.notifier)
        .completePasswordReset(password: _passwordController.text);

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
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: OnboardingScaffold(
          stepLabel: 'PASSWORD RESET',
          title: 'Set a new password',
          subtitle: isRecovery
              ? 'Your recovery session is active. Choose a secure password now.'
              : 'Open the reset link from your email on this device to unlock this screen.',
          children: [
            SafePathTextField(
              label: 'New password',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline,
              obscureText: true,
              helperText: 'Use at least 8 characters.',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            SafePathTextField(
              label: 'Confirm password',
              controller: _confirmController,
              prefixIcon: Icons.verified_user_outlined,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (isRecovery && !isLoading) _onSubmit();
              },
              validator: _validateConfirm,
            ),
            const SizedBox(height: 20),
            if (errorMessage != null) ...[
              AuthMessageBanner(message: errorMessage),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: isLoading ? 'Updating...' : 'Update password',
              onPressed: isRecovery && !isLoading ? _onSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}
