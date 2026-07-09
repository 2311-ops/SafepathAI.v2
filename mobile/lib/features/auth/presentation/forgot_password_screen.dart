import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/auth_controller.dart';
import '../data/auth_api.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  String? _statusMessage;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  Future<void> _sendResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).requestPasswordReset(
            email: _emailController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'If that email exists, Supabase sent a password reset link.';
      });
    } on AuthApiException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'We could not send the reset email. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset password', style: AppTypography.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter the email address on your SafePath account. We will send a reset link using Supabase Auth.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xl),
                SafePathTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_statusMessage != null) ...[
                  Text(_statusMessage!, style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: _isSending ? 'Sending link...' : 'Send reset link',
                  onPressed: _isSending ? null : _sendResetEmail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
