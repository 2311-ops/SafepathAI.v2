import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/stat_tile.dart';
import '../../../shared_widgets/timeline_node.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../application/history_controller.dart';
import '../data/location_models.dart';
import 'route_stats_sheet.dart';

class HistoryTimelineScreen extends ConsumerWidget {
  const HistoryTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final asyncHistory = ref.watch(historyControllerProvider);
    final historyState = asyncHistory.value ?? const HistoryState();
    final members = familyState?.members ?? const <FamilyMemberView>[];
    final selectedMember = _selectedMember(members, historyState);

    if ((familyState?.isLoading ?? false) || asyncHistory.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.appBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (familyState?.family == null) {
      return const _HistoryMessage(
        icon: Icons.group_off,
        title: 'No circle yet',
        body: 'Create or join a family circle to see activity history.',
      );
    }

    if (members.isEmpty) {
      return const _HistoryMessage(
        icon: Icons.history,
        title: 'No history yet',
        body:
            "Once location tracking starts, your stays and trips will show up here.",
      );
    }

    if (selectedMember != null &&
        historyState.selectedTargetUserId == null &&
        !historyState.isLoading) {
      final range = _dayRange(DateTime.now().toUtc());
      Future.microtask(
        () => ref
            .read(historyControllerProvider.notifier)
            .load(selectedMember.userId, range.$1, range.$2),
      );
    }

    final memberName = _memberName(selectedMember);

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _reload(ref, historyState, selectedMember),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              112,
            ),
            children: [
              _HistoryHeader(
                members: members,
                selectedUserId: selectedMember?.userId,
                selectedDate: historyState.fromUtc ?? DateTime.now().toUtc(),
                onMemberChanged: (userId) {
                  final range = _dayRange(
                    historyState.fromUtc ?? DateTime.now().toUtc(),
                  );
                  ref
                      .read(historyControllerProvider.notifier)
                      .load(userId, range.$1, range.$2);
                },
                onPreviousDay: () =>
                    _moveDay(ref, historyState, selectedMember, -1),
                onNextDay: () => _moveDay(ref, historyState, selectedMember, 1),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (historyState.error != null)
                SafePathCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Couldn't load history", style: AppTypography.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        historyState.error!,
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Try again',
                        onPressed: selectedMember == null
                            ? null
                            : () => _reload(ref, historyState, selectedMember),
                      ),
                    ],
                  ),
                )
              else ...[
                _StatsRow(stats: historyState.stats),
                const SizedBox(height: AppSpacing.lg),
                if (historyState.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (historyState.isEmpty)
                  _EmptyHistory(memberName: memberName)
                else ...[
                  PrimaryButton(
                    label: 'View route',
                    onPressed: () => showRouteStatsSheet(
                      context: context,
                      history: historyState.history,
                      stats: historyState.stats,
                      memberName: memberName,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _TimelineList(history: historyState.history),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static FamilyMemberView? _selectedMember(
    List<FamilyMemberView> members,
    HistoryState historyState,
  ) {
    if (members.isEmpty) return null;
    final selectedId = historyState.selectedTargetUserId;
    if (selectedId == null) return members.first;
    for (final member in members) {
      if (member.userId == selectedId) return member;
    }
    return members.first;
  }

  static String _memberName(FamilyMemberView? member) {
    if (member == null) return 'your family member';
    return member.role.wireValue;
  }

  static (DateTime, DateTime) _dayRange(DateTime dateUtc) {
    final start = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
    return (start, start.add(const Duration(days: 1)));
  }

  static Future<void> _reload(
    WidgetRef ref,
    HistoryState historyState,
    FamilyMemberView? selectedMember,
  ) async {
    if (selectedMember == null) return;
    final range = _dayRange(historyState.fromUtc ?? DateTime.now().toUtc());
    await ref
        .read(historyControllerProvider.notifier)
        .load(selectedMember.userId, range.$1, range.$2);
  }

  static void _moveDay(
    WidgetRef ref,
    HistoryState historyState,
    FamilyMemberView? selectedMember,
    int days,
  ) {
    if (selectedMember == null) return;
    final current = historyState.fromUtc ?? DateTime.now().toUtc();
    final range = _dayRange(current.add(Duration(days: days)));
    ref
        .read(historyControllerProvider.notifier)
        .load(selectedMember.userId, range.$1, range.$2);
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.members,
    required this.selectedUserId,
    required this.selectedDate,
    required this.onMemberChanged,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final List<FamilyMemberView> members;
  final String? selectedUserId;
  final DateTime selectedDate;
  final ValueChanged<String> onMemberChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: AppTypography.heading),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: selectedUserId,
            decoration: const InputDecoration(labelText: 'Family member'),
            items: [
              for (final member in members)
                DropdownMenuItem(
                  value: member.userId,
                  child: Text(member.role.wireValue),
                ),
            ],
            onChanged: (value) {
              if (value != null) onMemberChanged(value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: onPreviousDay,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _dateLabel(selectedDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed: onNextDay,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final TravelStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: _distanceLabel(stats.distanceMeters),
            label: 'Distance',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            value: _durationLabel(stats.timeAway),
            label: 'Time away',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(value: '${stats.stopCount}', label: 'Stops'),
        ),
      ],
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.history});

  final LocationHistory history;

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes(history);
    return SafePathCard(
      child: Column(
        children: [
          for (var i = 0; i < nodes.length; i++)
            TimelineNode(
              title: nodes[i].title,
              subtitle: nodes[i].subtitle,
              isTransit: nodes[i].isTransit,
              showConnector: i != nodes.length - 1,
            ),
        ],
      ),
    );
  }

  static List<_TimelineEntry> _nodes(LocationHistory history) {
    if (history.stops.isEmpty) {
      final first = history.polylinePoints.first;
      final last = history.polylinePoints.last;
      return [
        _TimelineEntry(
          title: 'On the move',
          subtitle:
              '${_timeLabel(first.recordedAtUtc)} - ${_timeLabel(last.recordedAtUtc)}',
          isTransit: true,
        ),
      ];
    }

    final entries = <_TimelineEntry>[];
    for (var i = 0; i < history.stops.length; i++) {
      final stop = history.stops[i];
      entries.add(
        _TimelineEntry(
          title: 'Stop ${i + 1}',
          subtitle:
              '${_timeLabel(stop.startUtc)} - ${_timeLabel(stop.endUtc)} - ${_durationLabel(stop.duration)}',
          isTransit: false,
        ),
      );
      if (i != history.stops.length - 1) {
        entries.add(
          const _TimelineEntry(
            title: 'On the move',
            subtitle: 'Travel between stops',
            isTransit: true,
          ),
        );
      }
    }
    return entries;
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.title,
    required this.subtitle,
    required this.isTransit,
  });

  final String title;
  final String subtitle;
  final bool isTransit;
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Column(
        children: [
          const Icon(Icons.history, color: AppColors.bodySecondary, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text('No history yet', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Once location tracking starts, $memberName's stays and trips will show up here.",
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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

String _distanceLabel(double meters) {
  final miles = meters / 1609.344;
  if (miles < 10) return '${miles.toStringAsFixed(1)} mi';
  return '${miles.round()} mi';
}

String _durationLabel(Duration duration) {
  if (duration.inMinutes < 60) return '${duration.inMinutes}m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
