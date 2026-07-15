import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/deep_link/deep_link_service.dart';
import '../../../shared_widgets/onboarding_scaffold.dart';
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
    ref.read(resetLinkExpiredProvider.notifier).set(false);

    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _statusMessage =
            "If an account exists for that address, we've sent a link to reset your password. It expires in 24 hours.";
      });
    } on AuthApiException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'We could not send the reset email. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resetLinkExpired = ref.watch(resetLinkExpiredProvider);

    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: OnboardingScaffold(
          title: 'Reset your password.',
          subtitle: "We'll email you a secure link to get back in.",
          children: [
            SafePathTextField(
              label: 'Email',
              controller: _emailController,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendResetEmail(),
              validator: _validateEmail,
            ),
            const SizedBox(height: 20),
            if (resetLinkExpired) ...[
              const AuthMessageBanner(
                message:
                    'This link has expired. Request a new one to continue.',
              ),
              const SizedBox(height: 16),
            ],
            if (_statusMessage != null) ...[
              AuthMessageBanner(
                message: _statusMessage!,
                kind: AuthMessageKind.success,
              ),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              AuthMessageBanner(message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _isSending ? 'Sending link...' : 'Send reset link',
              onPressed: _isSending ? null : _sendResetEmail,
            ),
          ],
        ),
      ),
    );
  }
}
