import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../application/sos_reach_provider.dart';

/// A self-hiding proactive warning shown on a settings surface (currently
/// only the Privacy Center) when [sosReachProvider] resolves to
/// [SosReach.noRecipients] — an SOS triggered right now would reach nobody.
/// Renders nothing for [SosReach.hasRecipients] and [SosReach.unknown], so
/// every call site can be a bare, unconditional `const SosReachWarningCard()`
/// and can never drift from another call site's condition for showing or
/// hiding it.
///
/// This copy is distinct from, and must never be confused with, the locked
/// reactive post-press empty state in `03-UI-SPEC.md` (shown only after a
/// real arm-complete finds zero recipients) — this card is a calm,
/// forward-looking nudge shown before any emergency, on amber
/// ([AppColors.caution]), never the reserved SOS red.
class SosReachWarningCard extends ConsumerWidget {
  const SosReachWarningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reach = ref.watch(sosReachProvider);
    if (reach != SosReach.noRecipients) {
      return const SizedBox.shrink();
    }

    // The trailing bottom padding lives here (not at call sites) so a bare
    // `const SosReachWarningCard()` collapses to zero height with no
    // leftover gap when it self-hides.
    return Padding(
      key: const ValueKey('sos-reach-warning'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SafePathCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.caution,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'SOS would reach no one',
                    style: AppTypography.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Your circle has no other guardian, and you haven't added any "
              'emergency contacts. If you trigger SOS right now, nobody '
              'would be notified.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => context.push('/settings/emergency-contacts'),
              icon: const Icon(Icons.contact_phone_outlined),
              label: const Text('Add an emergency contact'),
            ),
          ],
        ),
      ),
    );
  }
}
