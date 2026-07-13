import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/profile_avatar.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/secondary_button.dart';
import '../application/profile_controller.dart';
import '../data/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _nameSeeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileControllerProvider);
    final state = asyncState.value ?? const ProfileState();
    final profile = state.profile;

    if (profile != null && !_nameSeeded) {
      _nameController.text = profile.displayNameOrFallback;
      _nameSeeded = true;
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: asyncState.isLoading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : profile == null
            ? _ProfileEmptyState(error: state.error)
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(profileControllerProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _ProfileHeader(profile: profile),
                    const SizedBox(height: AppSpacing.md),
                    if (state.error != null) ...[
                      _InlineProfileError(message: state.error!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _DisplayNameCard(
                      controller: _nameController,
                      isLoading: state.isLoading,
                      onSave: () => _saveDisplayName(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PhotoCard(
                      profile: profile,
                      isLoading: state.isLoading,
                      onPick: () => _pickAndUploadPhoto(context),
                      onRemove: profile.profileImageUrl == null
                          ? null
                          : () => _confirmRemovePhoto(context),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _saveDisplayName(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(context, 'Enter a display name first.');
      return;
    }

    await ref.read(profileControllerProvider.notifier).updateDisplayName(name);
    if (!context.mounted) return;
    final error = ref.read(profileControllerProvider).value?.error;
    _showMessage(context, error ?? 'Display name saved.');
  }

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await ref
        .read(profileControllerProvider.notifier)
        .uploadProfileImage(bytes, image.name);
    if (!context.mounted) return;
    final error = ref.read(profileControllerProvider).value?.error;
    _showMessage(context, error ?? 'Profile photo updated.');
  }

  Future<void> _confirmRemovePhoto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your profile will use the default initial avatar until you add another photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Remove',
              style: AppTypography.body.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(profileControllerProvider.notifier).deleteProfileImage();
    if (!context.mounted) return;
    final error = ref.read(profileControllerProvider).value?.error;
    _showMessage(context, error ?? 'Profile photo removed.');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          ProfileAvatar(
            userId: profile.userId,
            label: profile.displayNameOrFallback,
            profileImageUrl: profile.profileImageUrl,
            profileUpdatedAt: profile.profileUpdatedAt,
            identityColor: AppColors.primaryTeal,
            size: 96,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.displayNameOrFallback,
            textAlign: TextAlign.center,
            style: AppTypography.heading,
          ),
          const SizedBox(height: AppSpacing.sm),
          _RoleChip(label: profile.role?.wireValue ?? 'Member'),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryTintBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xsMd,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.primaryTeal,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _DisplayNameCard extends StatelessWidget {
  const _DisplayNameCard({
    required this.controller,
    required this.isLoading,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit display name', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Display name'),
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Save name',
            onPressed: isLoading ? null : onSave,
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.profile,
    required this.isLoading,
    required this.onPick,
    required this.onRemove,
  });

  final UserProfile profile;
  final bool isLoading;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profile.profileImageUrl != null;
    return SafePathCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile photo', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasPhoto
                ? 'This photo appears anywhere your family can see your profile.'
                : 'Your default avatar uses the first letter of your name.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: hasPhoto ? 'Change photo' : 'Add photo',
            onPressed: isLoading ? null : onPick,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Remove photo',
            onPressed: isLoading ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

class _InlineProfileError extends StatelessWidget {
  const _InlineProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        border: Border.all(color: AppColors.cautionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.cautionText),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.cautionText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(
          error ?? 'Unable to load your profile.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
      ),
    );
  }
}
