import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'battery_indicator.dart';

class MemberDetail {
  const MemberDetail({
    required this.name,
    required this.isOnline,
    this.isStale = false,
    required this.lastSeenAtUtc,
    this.batteryPercent,
  });

  final String name;
  final bool isOnline;
  final bool isStale;
  final DateTime? lastSeenAtUtc;
  final int? batteryPercent;
}

Future<void> showMemberDetailSheet(
  BuildContext context, {
  required MemberDetail member,
  DateTime? now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => MemberDetailSheet(member: member, now: now),
  );
}

class MemberDetailSheet extends StatelessWidget {
  const MemberDetailSheet({super.key, required this.member, this.now});

  final MemberDetail member;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.name,
                    style: AppTypography.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(isOnline: member.isOnline, isStale: member.isStale),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lastSeenText(member.lastSeenAtUtc, now: now),
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            BatteryIndicator(percent: member.batteryPercent),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOnline, this.isStale = false});

  final bool isOnline;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final String text;
    final String semanticsLabel;
    final Color background;
    final Color border;
    final Color foreground;
    if (!isOnline) {
      text = 'OFFLINE';
      semanticsLabel = 'Offline';
      background = AppColors.hairlineSoft;
      border = AppColors.hairline;
      foreground = AppColors.bodySecondary;
    } else if (isStale) {
      // Neutral navy/slate — never SOS-red, never the caution/amber
      // low-battery palette (F-544 threat register T-544-01/02 scope).
      text = 'STALE';
      semanticsLabel = 'Stale';
      background = AppColors.navyTintBg;
      border = AppColors.hairline;
      foreground = AppColors.primaryNavy;
    } else {
      text = 'ONLINE';
      semanticsLabel = 'Online';
      background = AppColors.safeBg;
      border = AppColors.safeBgBorder;
      foreground = AppColors.safe;
    }
    return Semantics(
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: foreground,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

String lastSeenText(DateTime? recordedAtUtc, {DateTime? now}) {
  if (recordedAtUtc == null) return 'Last seen unavailable';

  final current = (now ?? DateTime.now().toUtc()).toUtc();
  final age = current.difference(recordedAtUtc.toUtc());
  final normalized = age.isNegative ? Duration.zero : age;
  if (normalized < const Duration(minutes: 1)) {
    return 'Last seen just now';
  }
  if (normalized < const Duration(hours: 1)) {
    final minutes = normalized.inMinutes;
    return 'Last seen $minutes min ago';
  }
  if (normalized < const Duration(days: 1)) {
    final hours = normalized.inHours;
    return 'Last seen $hours ${hours == 1 ? 'hr' : 'hrs'} ago';
  }

  final days = normalized.inDays;
  return 'Last seen $days ${days == 1 ? 'day' : 'days'} ago';
}
