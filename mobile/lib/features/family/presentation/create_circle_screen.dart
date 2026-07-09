import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/family_controller.dart';

/// Create circle (F1-3) — "Name your circle" heading, a `diversity_3` accent
/// avatar tile, a circle-name field, and a teal "Create circle" CTA that
/// calls [FamilyController.createCircle] then routes to `/home` (FAM-01).
class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Name your circle';
    return null;
  }

  Future<void> _onCreate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    await ref
        .read(familyControllerProvider.notifier)
        .createCircle(_nameController.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final familyState = ref.read(familyControllerProvider).value;
    if (familyState?.family != null) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyControllerProvider).value;
    final error = familyState?.error;

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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.diversity_3,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Name your circle', style: AppTypography.heading),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your circle starts with you.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xl),
                SafePathTextField(
                  label: 'Circle name',
                  controller: _nameController,
                  autofillHints: const [AutofillHints.familyName],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isSubmitting) _onCreate();
                  },
                  validator: _validateName,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorBanner(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isSubmitting ? 'Creating...' : 'Create circle',
                  onPressed: _isSubmitting ? null : _onCreate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amber (never SOS-red) inline error surface — mirrors the pattern already
/// used on `role_select_screen.dart` for the same non-SOS-error discipline.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        border: Border.all(color: AppColors.cautionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.cautionText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
