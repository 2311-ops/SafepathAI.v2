import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/toggle_row.dart';
import '../../auth/data/auth_api.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_models.dart';

class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  Future<void> _exportMyData(BuildContext context, WidgetRef ref) async {
    final json = await ref
        .read(privacyControllerProvider.notifier)
        .exportMyData();
    if (json == null) return;
    await SharePlus.instance.share(
      ShareParams(subject: 'SafePath data export', text: json),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all your location data?'),
        content: const Text(
          "This permanently removes your live location, history, and stats from SafePath. Your family won't be able to see past activity anymore. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(privacyControllerProvider.notifier).deleteMyData();
  }

  Future<void> _startCustomTemporaryShare(
    BuildContext context,
    WidgetRef ref, {
    required String recipientId,
  }) async {
    final duration = await _showCustomDurationDialog(context);
    if (duration == null || !context.mounted) return;

    await ref
        .read(privacyControllerProvider.notifier)
        .startTemporaryShare(
          recipientId: recipientId,
          dataType: SharedDataType.liveLocation,
          duration: duration,
        );
  }

  Future<Duration?> _showCustomDurationDialog(BuildContext context) async {
    var durationText = '';
    var unit = _CustomDurationUnit.hours;
    String? errorText;

    return showDialog<Duration>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final amount = int.tryParse(durationText.trim());
            if (amount == null) {
              setDialogState(() => errorText = 'Enter a whole number.');
              return;
            }
            if (amount <= 0) {
              setDialogState(() => errorText = 'Duration must be positive.');
              return;
            }

            final duration = unit.toDuration(amount);
            if (duration > const Duration(days: 7)) {
              setDialogState(() => errorText = 'Choose 7 days or less.');
              return;
            }

            Navigator.of(dialogContext).pop(duration);
          }

          return AlertDialog(
            title: const Text('Custom duration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('custom-duration-field'),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    errorText: errorText,
                  ),
                  onChanged: (value) => durationText = value,
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<_CustomDurationUnit>(
                  key: const ValueKey('custom-duration-unit'),
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(
                      value: _CustomDurationUnit.minutes,
                      child: Text('Minutes'),
                    ),
                    DropdownMenuItem(
                      value: _CustomDurationUnit.hours,
                      child: Text('Hours'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => unit = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(onPressed: submit, child: const Text('Start sharing')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final privacyState =
        ref.watch(privacyControllerProvider).value ?? const PrivacyState();
    final currentUserId = ref.watch(authApiProvider).currentSession?.user.id;
    final familyId = familyState?.family?.id;
    final recipients = (familyState?.members ?? const <FamilyMemberView>[])
        .where((member) => member.userId != currentUserId)
        .toList();
    final now = ref.watch(privacyNowProvider)();

    if ((familyState?.isLoading ?? false) || privacyState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.appBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (familyId == null) {
      return const _PrivacyMessage(
        icon: Icons.group_off,
        title: 'No circle yet',
        body: 'Create or join a family circle to manage privacy controls.',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Privacy Center')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(privacyControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              112,
            ),
            children: [
              Text('Privacy Center', style: AppTypography.heading),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose exactly what each family member can see.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (privacyState.error != null) ...[
                _ErrorCard(message: privacyState.error!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (recipients.isEmpty)
                const _EmptySharingCard()
              else ...[
                if (!_hasAnyEnabledShare(privacyState.matrix))
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: _EmptySharingCard(),
                  ),
                for (final recipient in recipients) ...[
                  _RecipientMatrix(
                    recipient: recipient,
                    matrix: privacyState.matrix,
                    onChanged: (dataType, enabled) => ref
                        .read(privacyControllerProvider.notifier)
                        .toggle(
                          recipientId: recipient.memberId,
                          dataType: dataType,
                          enabled: enabled,
                        ),
                    activeShare: _activeShare(
                      privacyState.matrix,
                      recipient.memberId,
                      now,
                    ),
                    onPresetSelected: (duration) => ref
                        .read(privacyControllerProvider.notifier)
                        .startTemporaryShare(
                          recipientId: recipient.memberId,
                          dataType: SharedDataType.liveLocation,
                          duration: duration,
                        ),
                    onCustomSelected: () => _startCustomTemporaryShare(
                      context,
                      ref,
                      recipientId: recipient.memberId,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              _PrivacyActionsSection(
                isExporting: privacyState.isExporting,
                isDeleting: privacyState.isDeleting,
                onExport: () => _exportMyData(context, ref),
                onDelete: () => _confirmDelete(context, ref),
                onPolicy: () => context.go('/privacy/policy'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasAnyEnabledShare(SharingMatrix matrix) =>
      matrix.entries.any((entry) => entry.isEnabled);

  static _ActiveShare? _activeShare(
    SharingMatrix matrix,
    String recipientId,
    DateTime now,
  ) {
    final entry = matrix.cellFor(recipientId, SharedDataType.liveLocation);
    final expiresAt = entry?.expiresAtUtc;
    if (entry == null ||
        !entry.isEnabled ||
        expiresAt == null ||
        !expiresAt.isAfter(now)) {
      return null;
    }
    final remaining = expiresAt.difference(now);
    return _ActiveShare(
      durationLabel: _durationFromNowLabel(remaining),
      remainingLabel: _remainingLabel(remaining),
    );
  }
}

class _PrivacyActionsSection extends StatelessWidget {
  const _PrivacyActionsSection({
    required this.isExporting,
    required this.isDeleting,
    required this.onExport,
    required this.onDelete,
    required this.onPolicy,
  });

  final bool isExporting;
  final bool isDeleting;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onPolicy;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your data', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: isExporting ? null : onExport,
            icon: isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: const Text('Export my data'),
          ),
          TextButton.icon(
            onPressed: onPolicy,
            icon: const Icon(Icons.policy_outlined),
            label: const Text('Privacy policy'),
          ),
          TextButton.icon(
            onPressed: isDeleting ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.ink),
            label: const Text(
              'Delete my data',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientMatrix extends StatelessWidget {
  const _RecipientMatrix({
    required this.recipient,
    required this.matrix,
    required this.onChanged,
    required this.activeShare,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final FamilyMemberView recipient;
  final SharingMatrix matrix;
  final void Function(SharedDataType dataType, bool enabled) onChanged;
  final _ActiveShare? activeShare;
  final ValueChanged<Duration> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    final name = _recipientLabel(recipient, matrix);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        for (final dataType in SharedDataType.values) ...[
          ToggleRow(
            label: dataType.label,
            subtitle: _subtitle(dataType),
            value: matrix.isEnabled(recipient.memberId, dataType),
            onChanged: (enabled) => onChanged(dataType, enabled),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _TemporarySharingSection(
          recipientId: recipient.memberId,
          activeShare: activeShare,
          onPresetSelected: onPresetSelected,
          onCustomSelected: onCustomSelected,
        ),
      ],
    );
  }

  static String _recipientLabel(
    FamilyMemberView recipient,
    SharingMatrix matrix,
  ) {
    for (final entry in matrix.entries) {
      if (entry.recipientId == recipient.memberId &&
          (entry.recipientName?.isNotEmpty ?? false)) {
        return entry.recipientName!;
      }
    }
    return recipient.role.wireValue;
  }

  static String _subtitle(SharedDataType dataType) => switch (dataType) {
    SharedDataType.liveLocation => 'Current map pin and last-seen status',
    SharedDataType.history => 'Timeline, route, and travel stats',
    SharedDataType.wellness => 'Health and wellness summaries',
  };
}

class _TemporarySharingSection extends StatelessWidget {
  const _TemporarySharingSection({
    required this.recipientId,
    required this.activeShare,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final String recipientId;
  final _ActiveShare? activeShare;
  final ValueChanged<Duration> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Temporary sharing', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _DurationChip(
              key: ValueKey('temporary-share-$recipientId-1h'),
              label: '1 hour',
              duration: const Duration(hours: 1),
              onSelected: onPresetSelected,
            ),
            _DurationChip(
              key: ValueKey('temporary-share-$recipientId-4h'),
              label: '4 hours',
              duration: const Duration(hours: 4),
              onSelected: onPresetSelected,
            ),
            _DurationChip(
              key: ValueKey('temporary-share-$recipientId-8h'),
              label: '8 hours',
              duration: const Duration(hours: 8),
              onSelected: onPresetSelected,
            ),
            ActionChip(
              key: ValueKey('temporary-share-$recipientId-custom'),
              label: const Text('Custom'),
              backgroundColor: AppColors.primaryTintBg,
              onPressed: onCustomSelected,
            ),
          ],
        ),
        if (activeShare != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.deepTeal,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Sharing for ${activeShare!.durationLabel} - ${activeShare!.remainingLabel} left',
              style: AppTypography.body.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    super.key,
    required this.label,
    required this.duration,
    required this.onSelected,
  });

  final String label;
  final Duration duration;
  final ValueChanged<Duration> onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.primaryTintBg,
      onPressed: () => onSelected(duration),
    );
  }
}

enum _CustomDurationUnit {
  minutes,
  hours;

  Duration toDuration(int amount) => switch (this) {
    _CustomDurationUnit.minutes => Duration(minutes: amount),
    _CustomDurationUnit.hours => Duration(hours: amount),
  };
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.caution),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.bodySecondary)),
        ],
      ),
    );
  }
}

class _EmptySharingCard extends StatelessWidget {
  const _EmptySharingCard();

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Text(
        'No one can see your location right now. Your guardians will still get your location immediately if you ever trigger SOS.',
        style: AppTypography.bodySecondary,
      ),
    );
  }
}

class _PrivacyMessage extends StatelessWidget {
  const _PrivacyMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppColors.bodySecondary),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: AppTypography.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveShare {
  const _ActiveShare({
    required this.durationLabel,
    required this.remainingLabel,
  });

  final String durationLabel;
  final String remainingLabel;
}

String _durationFromNowLabel(Duration duration) {
  if (duration.inHours >= 8) return '8 hours';
  if (duration.inHours >= 4) return '4 hours';
  if (duration.inHours >= 1) return '1 hour';
  return '${duration.inMinutes} minutes';
}

String _remainingLabel(Duration duration) {
  if (duration.inMinutes < 60) return '${duration.inMinutes}m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
