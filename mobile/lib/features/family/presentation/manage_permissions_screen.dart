import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../auth/data/auth_api.dart';
import '../application/family_controller.dart';
import '../data/family_models.dart';

/// Manage permissions (F1-7) — per-member permission toggles + a
/// `#C42A30`-colored, confirmation-gated "Remove from circle" action. This
/// is the single flagged exception to the system's red-reservation rule
/// (see `01-UI-SPEC.md` Color section) — Remove never fires on a single tap.
class ManagePermissionsScreen extends ConsumerWidget {
  const ManagePermissionsScreen({super.key});

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    FamilyMemberView member,
    String circleName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove this member from $circleName?'),
        content: const Text(
          "They'll lose access to shared location and alerts immediately. "
          "This can't be undone from here — you'd need to invite them again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: AppColors.sosRedDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(familyControllerProvider.notifier)
        .removeMember(familyId, member.memberId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final currentUserId = ref.watch(authApiProvider).currentSession?.user.id;
    final familyId = familyState?.family?.id;
    final circleName = familyState?.family?.name ?? 'your circle';
    final otherMembers = (familyState?.members ?? const [])
        .where((m) => m.userId != currentUserId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: familyId == null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_off,
                        size: 44,
                        color: AppColors.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No circle yet',
                        style: AppTypography.heading,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Managing permissions needs an active family circle.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              )
            : otherMembers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diversity_3,
                        size: 48,
                        color: AppColors.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Just you so far',
                        style: AppTypography.title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Invite a family member to manage their permissions here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Permissions', style: AppTypography.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Control what each family member can see and do',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final member in otherMembers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SafePathCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (member.displayName?.isNotEmpty ?? false)
                                        ? member.displayName!
                                        : member.role.wireValue,
                                    style: AppTypography.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _confirmRemove(
                                    context,
                                    ref,
                                    familyId,
                                    member,
                                    circleName,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_remove,
                                          color: AppColors.sosRedDeep,
                                          size: 18,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'Remove from circle',
                                          style: AppTypography.bodySecondary
                                              .copyWith(
                                                color: AppColors.sosRedDeep,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xsMd),
                            Column(
                              children: [
                                for (final level in PermissionLevel.values)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: level == PermissionLevel.values.last
                                          ? 0
                                          : AppSpacing.sm,
                                    ),
                                    child: _PermissionLevelRow(
                                      level: level,
                                      selected: level == member.permission,
                                      onTap: () => ref
                                          .read(familyControllerProvider.notifier)
                                          .updatePermission(
                                            familyId,
                                            member.memberId,
                                            level,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Icon glyph for each [PermissionLevel], used by [_PermissionLevelRow].
IconData _iconForPermissionLevel(PermissionLevel level) {
  switch (level) {
    case PermissionLevel.viewOnly:
      return Icons.visibility_outlined;
    case PermissionLevel.fullLocation:
      return Icons.location_on_outlined;
    case PermissionLevel.notificationOnly:
      return Icons.notifications_outlined;
  }
}

/// A single, always-full-width, tappable permission-level row. Replaces the
/// previous `SegmentedButton`, which truncated its labels under
/// horizontal-scroll layout pressure.
class _PermissionLevelRow extends StatelessWidget {
  const _PermissionLevelRow({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final PermissionLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xsMd,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primaryTeal : AppColors.surface,
          border: selected ? null : Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(
              _iconForPermissionLevel(level),
              size: 20,
              color: selected ? AppColors.surface : AppColors.ink,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                level.label,
                style: AppTypography.body.copyWith(
                  color: selected ? AppColors.surface : AppColors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppColors.surface, size: 20),
          ],
        ),
      ),
    );
  }
}
