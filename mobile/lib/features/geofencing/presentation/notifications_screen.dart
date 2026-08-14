import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/routine_notifications_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(routineNotificationsControllerProvider).value ??
        const RoutineNotificationsState(isLoading: true);
    return NotificationsScreen(
      state: state,
      onOpen: (item) {
        unawaited(
          ref.read(routineNotificationsControllerProvider.notifier).open(item),
        );
        context.push(
          '/zone-activity?activityId=${Uri.encodeComponent(item.activityId)}',
        );
      },
      onSettings: () => context.push('/notifications/quiet-hours'),
      onRetry: () =>
          ref.read(routineNotificationsControllerProvider.notifier).refresh(),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.state,
    this.onOpen,
    this.onSettings,
    this.onRetry,
  });

  const NotificationsScreen.empty({super.key})
    : state = const RoutineNotificationsState(),
      onOpen = null,
      onSettings = null,
      onRetry = null;

  final RoutineNotificationsState state;
  final ValueChanged<RoutineNotification>? onOpen;
  final VoidCallback? onSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBg,
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        Semantics(
          label: 'Notification settings',
          button: true,
          child: IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
      ],
    ),
    body: _body(context),
  );

  Widget _body(BuildContext context) {
    if (state.isLoading) return const _FeedSkeleton();
    if (state.error != null && state.items.isEmpty) {
      return _FeedError(onRetry: onRetry);
    }
    if (state.items.isEmpty) return const _FeedEmpty();
    return RefreshIndicator(
      onRefresh: () async => onRetry?.call(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            _FeedRow(item: state.items[index], onOpen: onOpen),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, this.onOpen});
  final RoutineNotification item;
  final ValueChanged<RoutineNotification>? onOpen;

  @override
  Widget build(BuildContext context) {
    final direction = item.transition == RoutineNotificationTransition.entered
        ? 'entered'
        : 'left';
    final title = '${item.memberName} $direction ${item.zoneName}';
    return Semantics(
      label: 'Open activity for $title',
      button: true,
      container: true,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen == null ? null : () => onOpen!(item),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(item.memberName.characters.first.toUpperCase()),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  item.transition == RoutineNotificationTransition.entered
                      ? Icons.login_outlined
                      : Icons.logout_outlined,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.body),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _timestamp(item.occurredAtUtc.toLocal()),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                if (!item.isRead) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _UnreadStatus(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadStatus extends StatelessWidget {
  const _UnreadStatus();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'New notification',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryTeal,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 8, height: 8),
        ),
        SizedBox(width: AppSpacing.xs),
        Text('New'),
      ],
    ),
  );
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 48),
          SizedBox(height: AppSpacing.md),
          Text("You're all caught up"),
          SizedBox(height: AppSpacing.sm),
          Text('New safe-zone alerts will appear here.'),
        ],
      ),
    ),
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Couldn't load notifications. Check your connection and try again.",
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.lg),
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (_, _) => const SizedBox(height: 88, child: Card()),
  );
}

String _timestamp(DateTime value) =>
    '${value.day} ${_months[value.month - 1]} ${value.year}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
