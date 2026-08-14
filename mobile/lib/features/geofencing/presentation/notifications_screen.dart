import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../family/application/family_controller.dart';
import '../application/geofence_activity_controller.dart';
import '../application/routine_notifications_controller.dart';
import '../data/geofence_api.dart';
import 'zone_activity_screen.dart';

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
          '/zone-activity?zoneId=${Uri.encodeComponent(item.safeZoneId ?? '')}',
        );
      },
      onSettings: () => context.push('/notifications/quiet-hours'),
      onRetry: () =>
          ref.read(routineNotificationsControllerProvider.notifier).refresh(),
    );
  }
}

class RoutineActivityPage extends ConsumerWidget {
  const RoutineActivityPage({super.key, required this.zoneId});

  final String? zoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider).value?.family;
    if (family == null || zoneId == null || zoneId!.isEmpty) {
      return const ZoneActivityScreen.error();
    }
    return _RoutineActivityLoader(familyId: family.id, zoneId: zoneId!);
  }
}

class _RoutineActivityLoader extends ConsumerStatefulWidget {
  const _RoutineActivityLoader({required this.familyId, required this.zoneId});

  final String familyId;
  final String zoneId;

  @override
  ConsumerState<_RoutineActivityLoader> createState() =>
      _RoutineActivityLoaderState();
}

class _RoutineActivityLoaderState
    extends ConsumerState<_RoutineActivityLoader> {
  late final GeofenceActivityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GeofenceActivityController(
      ref.read(geofenceApiProvider),
      () => DateTime.now().toUtc(),
    );
    _load();
  }

  Future<void> _load() async {
    await _controller.load(
      GeofenceActivityFilters(zoneId: widget.zoneId),
      familyId: widget.familyId,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ZoneActivityScreen(
    state: _controller.state,
    now: DateTime.now().toUtc(),
    onRetry: _load,
  );
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
      return _FeedError(message: state.error!, onRetry: onRetry);
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen == null ? null : () => onOpen!(item),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryTintBg,
                  foregroundColor: AppColors.primaryTeal,
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
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body,
                      ),
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
        Text(
          'New',
          style: AppTypography.caption.copyWith(
            color: AppColors.primaryTeal,
            letterSpacing: 0,
          ),
        ),
      ],
    ),
  );
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) => _FeedStateScaffold(
    icon: Icons.notifications_none,
    title: "You're all caught up",
    body:
        'Safe-zone alerts will appear here as soon as a family member enters or leaves a place.',
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _FeedStateScaffold(
    icon: Icons.cloud_off_outlined,
    title: "Notifications aren't available",
    body: message,
    action: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh, size: 20),
      label: const Text('Try again'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.surface,
        textStyle: AppTypography.ctaLabel,
      ),
    ),
  );
}

class _FeedStateScaffold extends StatelessWidget {
  const _FeedStateScaffold({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final topPadding = constraints.maxHeight < 560
            ? AppSpacing.lg
            : AppSpacing.xl * 2;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topPadding,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - topPadding - AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primaryTintBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Icon(
                                icon,
                                color: AppColors.primaryTeal,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(title, style: AppTypography.title),
                        const SizedBox(height: AppSpacing.xs),
                        Text(body, style: AppTypography.bodySecondary),
                        if (action != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          action!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    itemBuilder: (_, _) => const _FeedSkeletonRow(),
  );
}

class _FeedSkeletonRow extends StatelessWidget {
  const _FeedSkeletonRow();

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: AppColors.hairlineSoft),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBar(widthFactor: .72),
                SizedBox(height: AppSpacing.sm),
                _SkeletonBar(widthFactor: .42),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.hairlineSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(height: 14),
    ),
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
