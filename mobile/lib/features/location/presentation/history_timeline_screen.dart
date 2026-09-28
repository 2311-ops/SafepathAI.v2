import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/logout_action.dart';
import '../../../shared_widgets/no_circle_cta.dart';
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
        action: NoCircleCta(),
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
      appBar: AppBar(
        title: const Text('Activity'),
        actions: const [LogoutAction()],
      ),
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
                onDateSelected: (picked) =>
                    _goToDate(ref, selectedMember, picked),
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
                    icon: Icons.map_outlined,
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

  static void _goToDate(
    WidgetRef ref,
    FamilyMemberView? selectedMember,
    DateTime picked,
  ) {
    if (selectedMember == null) return;
    final range = _dayRange(picked);
    ref
        .read(historyControllerProvider.notifier)
        .load(selectedMember.userId, range.$1, range.$2);
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
    final displayName = member.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
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

const List<String> _weekdayAbbrevs = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthAbbrevs = [
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

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.members,
    required this.selectedUserId,
    required this.selectedDate,
    required this.onMemberChanged,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDateSelected,
  });

  final List<FamilyMemberView> members;
  final String? selectedUserId;
  final DateTime selectedDate;
  final ValueChanged<String> onMemberChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final selectedMember = _findMember(members, selectedUserId);
    final isToday = _isSameLocalDay(selectedDate.toLocal(), DateTime.now());

    return SafePathCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryTintBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/activity-history.png',
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity history',
                      style: AppTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Review trips, stops, and distance by family member.',
                      style: AppTypography.bodySecondary.copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MemberSelectorPill(
            members: members,
            selectedMember: selectedMember,
            onMemberChanged: onMemberChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.navyTintBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Previous day',
                    onPressed: onPreviousDay,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickDate(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: AppColors.primaryTeal,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                _dateLabel(selectedDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Next day',
                    onPressed: isToday ? null : onNextDay,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 1, now.month, now.day);
    final localSelected = selectedDate.toLocal();
    var initialDate = DateTime(
      localSelected.year,
      localSelected.month,
      localSelected.day,
    );
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onDateSelected(picked);
  }

  static FamilyMemberView? _findMember(
    List<FamilyMemberView> members,
    String? userId,
  ) {
    if (userId == null) return null;
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _memberName(FamilyMemberView member) {
    final displayName = member.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return member.role.wireValue;
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final weekday = _weekdayAbbrevs[local.weekday - 1];
    final month = _monthAbbrevs[local.month - 1];
    return '$weekday, $month ${local.day}';
  }
}

class _MemberSelectorPill extends StatelessWidget {
  const _MemberSelectorPill({
    required this.members,
    required this.selectedMember,
    required this.onMemberChanged,
  });

  final List<FamilyMemberView> members;
  final FamilyMemberView? selectedMember;
  final ValueChanged<String> onMemberChanged;

  @override
  Widget build(BuildContext context) {
    final name = selectedMember == null
        ? 'Select member'
        : _HistoryHeader._memberName(selectedMember!);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: members.isEmpty ? null : () => _openMemberSheet(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline, width: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryTeal,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.bodySecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemberSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
            ),
            child: SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: members.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, index) {
                  final member = members[index];
                  final isSelected = member.userId == selectedMember?.userId;
                  final memberName = _HistoryHeader._memberName(member);
                  final memberInitial = memberName.isNotEmpty
                      ? memberName[0].toUpperCase()
                      : '?';
                  final avatarColor = const [
                    AppColors.primaryTeal,
                    AppColors.memberViolet,
                    AppColors.memberPink,
                  ][index % 3];

                  return GestureDetector(
                    onTap: () {
                      onMemberChanged(member.userId);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: avatarColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryTeal,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: Text(
                            memberInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          memberName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodySecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
            icon: Image.asset(
              'assets/icons/activity-distance.png',
              width: 24,
              height: 24,
            ),
            backgroundColor: AppColors.primaryTintBg,
            borderColor: AppColors.hairline,
            valueColor: AppColors.primaryTeal,
            labelColor: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            value: _durationLabel(stats.timeAway),
            label: 'Time away',
            icon: Image.asset(
              'assets/icons/activity-time-away.png',
              width: 24,
              height: 24,
            ),
            backgroundColor: AppColors.cautionBg,
            borderColor: AppColors.cautionBorder,
            valueColor: AppColors.cautionText,
            labelColor: AppColors.cautionText,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            value: '${stats.stopCount}',
            label: 'Stops',
            icon: Image.asset(
              'assets/icons/activity-stops.png',
              width: 24,
              height: 24,
            ),
            backgroundColor: AppColors.memberViolet.withValues(alpha: 0.12),
            borderColor: AppColors.memberViolet.withValues(alpha: 0.3),
            valueColor: AppColors.memberViolet,
            labelColor: AppColors.memberViolet,
          ),
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
              durationLabel: nodes[i].durationLabel,
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
          durationLabel: _durationLabel(
            last.recordedAtUtc.difference(first.recordedAtUtc),
          ),
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
    this.durationLabel,
  });

  final String title;
  final String subtitle;
  final bool isTransit;
  final String? durationLabel;
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text('Activity'),
        actions: const [LogoutAction()],
      ),
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
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
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
