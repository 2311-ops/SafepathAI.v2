import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/profile_avatar.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../auth/data/auth_api.dart';
import '../application/family_controller.dart';
import '../data/family_models.dart';

/// Circle member management: guardians can invite/remove members, while each
/// member keeps ownership of live-location, history, and wellness sharing from
/// their own Privacy Center. The `#C42A30` Remove action remains
/// confirmation-gated and never fires on a single tap.
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

  /// Display-only capitalization defense — does not mutate
  /// [FamilyMemberView.displayName] or any other stored/model field.
  String _capitalized(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
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
      appBar: AppBar(title: const Text('Circle members')),
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
                        'Member management needs an active family circle.',
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
                        'Invite a family member to manage your circle here.',
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
                  Text('Circle members', style: AppTypography.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Invite or remove members. Each person controls their own live location, history, and wellness sharing.',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final (index, member) in otherMembers.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SafePathCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final resolvedName =
                                    (member.displayName?.isNotEmpty ?? false)
                                    ? member.displayName!
                                    : member.role.wireValue;
                                final capitalizedName = _capitalized(
                                  resolvedName,
                                );
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ProfileAvatar(
                                      userId: member.userId,
                                      label: capitalizedName,
                                      size: 44,
                                      identityColor: index.isEven
                                          ? AppColors.memberViolet
                                          : AppColors.memberPink,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capitalizedName,
                                            style: AppTypography.title,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            member.role.wireValue,
                                            style: AppTypography.bodySecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: AppColors.bodySecondary,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'remove') {
                                          _confirmRemove(
                                            context,
                                            ref,
                                            familyId,
                                            member,
                                            circleName,
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: SizedBox(
                                            width: 220,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_remove,
                                                  color: AppColors.sosRedDeep,
                                                  size: 18,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.xs,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Remove from circle',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTypography
                                                        .bodySecondary
                                                        .copyWith(
                                                          color: AppColors
                                                              .sosRedDeep,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.xsMd),
                            const _MemberOwnedPrivacyNotice(),
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

class _MemberOwnedPrivacyNotice extends StatelessWidget {
  const _MemberOwnedPrivacyNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primaryTintBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_person_outlined, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy controlled by member', style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'They choose who can see live location, history, and wellness from their own Privacy Center.',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
