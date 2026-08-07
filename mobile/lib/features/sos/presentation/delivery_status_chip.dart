import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/sos_models.dart';

/// One (channel, status) chip — icon + caption text pair, always paired,
/// never colour alone (03-UI-SPEC.md "Delivery Status Vocabulary", D-09/
/// D-10). The exact icon/colour/copy mapping is locked by the UI spec.
class DeliveryStatusChip extends StatelessWidget {
  const DeliveryStatusChip({
    super.key,
    required this.channel,
    required this.status,
  });

  final SosChannel channel;
  final SosDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(status);
    return Semantics(
      label: '${_channelLabel(channel)} ${spec.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 14, color: spec.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            spec.label.toUpperCase(),
            style: AppTypography.caption.copyWith(color: spec.color),
          ),
        ],
      ),
    );
  }

  _StatusSpec _specFor(SosDeliveryStatus status) {
    switch (status) {
      case SosDeliveryStatus.notAttempted:
      case SosDeliveryStatus.unknown:
        return const _StatusSpec(
          icon: Icons.remove,
          color: AppColors.bodySecondary,
          label: '—',
        );
      case SosDeliveryStatus.queued:
        return const _StatusSpec(
          icon: Icons.schedule,
          color: AppColors.caution,
          label: 'Queued',
        );
      case SosDeliveryStatus.failed:
        // A failure is an amber attention state, never a second red tone —
        // red stays reserved for the emergency itself. `Failed` is a
        // terminal server-side state (no retry loop exists), so the label
        // must not imply an in-progress retry (D-09/D-10 honesty).
        return const _StatusSpec(
          icon: Icons.error_outline,
          color: AppColors.caution,
          label: 'Not delivered',
        );
      case SosDeliveryStatus.delivered:
        return const _StatusSpec(
          icon: Icons.check_circle_outline,
          color: AppColors.safe,
          label: 'Delivered',
        );
      case SosDeliveryStatus.acknowledged:
        // Strictly stronger than Delivered — only ever reached through an
        // explicit guardian Acknowledge action, never inferred.
        return const _StatusSpec(
          icon: Icons.check_circle,
          color: AppColors.safe,
          label: 'Seen',
        );
    }
  }

  String _channelLabel(SosChannel channel) {
    switch (channel) {
      case SosChannel.signalR:
        return 'App';
      case SosChannel.fcm:
        return 'Push';
      case SosChannel.sms:
        return 'SMS';
      case SosChannel.unknown:
        return 'Channel';
    }
  }
}

class _StatusSpec {
  const _StatusSpec({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

/// One recipient's row: display name + a horizontal wrap of one
/// [DeliveryStatusChip] per channel attempted for them. Never collapses to
/// a single aggregate checkmark (D-09) — every channel attempted for this
/// recipient gets its own chip.
class RecipientDeliveryRow extends StatelessWidget {
  const RecipientDeliveryRow({super.key, required this.recipient});

  final SosRecipientStatus recipient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recipient.displayName,
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final channelStatus in recipient.channels)
                  DeliveryStatusChip(
                    channel: channelStatus.channel,
                    status: channelStatus.status,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
