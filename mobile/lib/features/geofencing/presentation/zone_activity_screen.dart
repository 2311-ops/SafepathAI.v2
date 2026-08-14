import 'package:flutter/material.dart';

import '../../../shared_widgets/timeline_node.dart';
import '../application/geofence_activity_controller.dart';
import '../data/geofence_api.dart';

class ZoneActivityScreen extends StatelessWidget {
  const ZoneActivityScreen({
    super.key,
    required this.state,
    required this.now,
    this.onFilter,
    this.onRetry,
  });

  const ZoneActivityScreen.empty({super.key})
    : state = const GeofenceActivityState(),
      now = null,
      onFilter = null,
      onRetry = null;

  const ZoneActivityScreen.error({super.key, this.onRetry})
    : state = const GeofenceActivityState(error: 'error'),
      now = null,
      onFilter = null;

  final GeofenceActivityState state;
  final DateTime? now;
  final VoidCallback? onFilter;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now().toUtc();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone activity'),
        actions: [
          Semantics(
            label: 'Filter activity',
            button: true,
            child: IconButton(
              onPressed: onFilter,
              icon: const Icon(Icons.filter_list_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterSummary(filters: state.filters),
          Expanded(child: _body(context, current)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, DateTime current) {
    if (state.isLoading) {
      return const _ActivitySkeleton();
    }
    if (state.error != null) {
      return _ErrorState(onRetry: onRetry);
    }
    if (state.activity.isEmpty) {
      return const _EmptyState();
    }
    final sorted = [...state.activity]
      ..sort((left, right) => right.occurredAtUtc.compareTo(left.occurredAtUtc));
    final groups = <String, List<GeofenceActivity>>{};
    for (final item in sorted) {
      final local = item.occurredAtUtc.toLocal();
      final heading = _dayHeading(local, current.toLocal());
      (groups[heading] ??= []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final entry in groups.entries) ...[
          Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (var index = 0; index < entry.value.length; index++)
            _ActivityRow(
              item: entry.value[index],
              showConnector: index != entry.value.length - 1,
            ),
        ],
      ],
    );
  }

  static String _dayHeading(DateTime date, DateTime current) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(current.year, current.month, current.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _date(date);
  }

  static String _date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.filters});
  final GeofenceActivityFilters filters;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      filters.memberId == null ? 'All members' : 'Selected member',
      filters.zoneId == null ? 'All zones' : 'Selected zone',
      filters.transition?.label ?? 'All transitions',
      'Last 7 days',
    ];
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Semantics(
        label: 'Activity filters: ${labels.join(', ')}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(labels.join(' · ')),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.showConnector});
  final GeofenceActivity item;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final occurred = item.occurredAtUtc.toLocal();
    final entered = item.enteredAtUtc?.toLocal();
    final exited = item.exitedAtUtc?.toLocal();
    final title = '${item.memberName} ${item.transition.label.toLowerCase()} ${item.zoneName} · ${_timestamp(entered ?? occurred)}';
    final subtitle = item.isPairedVisit && exited != null
        ? 'Left · ${_timestamp(exited)}'
        : item.isInProgress
        ? 'Visit in progress'
        : '${item.transition.label} · ${_timestamp(occurred)}';
    final supplemental = <String>[
      if (item.isPairedVisit)
        'Visit duration ${_duration(item.completedVisitDurationSeconds!)}',
    ];
    return Semantics(
      label: [title, subtitle, ...supplemental].join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimelineNode(
              title: title,
              subtitle: subtitle,
              isTransit: item.transition == GeofenceActivityTransition.left,
              showConnector: showConnector,
            ),
            for (final detail in supplemental)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 16),
                child: Text(detail),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(24),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: 16),
    itemBuilder: (_, _) => const SizedBox(height: 72, child: Card()),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline_outlined, size: 48),
          SizedBox(height: 16),
          Text('No zone activity yet'),
          SizedBox(height: 8),
          Text('Confirmed arrivals and departures from the last 7 days will appear here.'),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load zone activity. Check your connection and try again."),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _timestamp(DateTime value) =>
    '${value.day} ${_months[value.month - 1]} ${value.year}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
