import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared_widgets/google_sign_in_button.dart';
import '../../../shared_widgets/onboarding_scaffold.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';

/// The values entered on [RegisterScreen], carried forward to
/// [RoleSelectScreen] via [registerDraftProvider] so the final `register()`
/// call has everything it needs in one place.
///
/// Held in a Riverpod provider (not `GoRouterState.extra`): the router's
/// `refreshListenable` re-evaluates the current route on every auth-state
/// change (loading -> pending-verification/error), and `extra` was observed
/// to be dropped on that re-evaluation, bouncing the user back to this
/// screen with all entered data lost. A provider survives that rebuild.
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

class RegisterDraftNotifier extends Notifier<RegisterDraft?> {
  @override
  RegisterDraft? build() => null;

  void set(RegisterDraft draft) => state = draft;
}

final registerDraftProvider =
    NotifierProvider<RegisterDraftNotifier, RegisterDraft?>(
      RegisterDraftNotifier.new,
    );

/// Register — `#ECF0EF` bg, back-arrow header, FULL NAME/EMAIL/PASSWORD
/// fields, teal "Continue" CTA (per `01-UI-SPEC.md`).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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

    ref
        .read(registerDraftProvider.notifier)
        .set(
          RegisterDraft(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
          ),
        );
    context.push('/register/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: OnboardingScaffold(
            stepLabel: 'STEP 1 / 2',
            title: 'Create account',
            subtitle:
                'Start with the essentials. You will choose your role next.',
            children: [
              SafePathTextField(
                label: 'Full name',
                controller: _fullNameController,
                prefixIcon: Icons.person_outline,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: _validateFullName,
              ),
              const SizedBox(height: 16),
              SafePathTextField(
                label: 'Email',
                controller: _emailController,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              SafePathTextField(
                label: 'Password',
                controller: _passwordController,
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                helperText: 'Use at least 8 characters.',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onContinue(),
                validator: _validatePassword,
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Continue', onPressed: _onContinue),
              const SizedBox(height: 12),
              const GoogleSignInButton(),
            ],
          ),
        ),
      ),
    );
  }
}
