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
            ? const Center(child: Text('No circle yet.'))
            : otherMembers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    'Just you so far',
                    style: AppTypography.title,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
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
                                    member.role.wireValue,
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
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_remove,
                                        color: AppColors.sosRedDeep,
                                        size: 18,
                                      ),
                                      SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Remove from circle',
                                        style: TextStyle(
                                          color: AppColors.sosRedDeep,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xsMd),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<PermissionLevel>(
                                segments: const [
                                  ButtonSegment(
                                    value: PermissionLevel.viewOnly,
                                    label: Text('View only'),
                                  ),
                                  ButtonSegment(
                                    value: PermissionLevel.fullLocation,
                                    label: Text('Full location'),
                                  ),
                                  ButtonSegment(
                                    value: PermissionLevel.notificationOnly,
                                    label: Text('Notifications'),
                                  ),
                                ],
                                selected: {member.permission},
                                onSelectionChanged: (selection) {
                                  ref
                                      .read(familyControllerProvider.notifier)
                                      .updatePermission(
                                        familyId,
                                        member.memberId,
                                        selection.first,
                                      );
                                },
                              ),
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
