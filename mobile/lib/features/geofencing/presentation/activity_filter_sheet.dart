import 'package:flutter/material.dart';

import '../data/geofence_api.dart';

class ActivityFilterOption {
  const ActivityFilterOption({required this.id, required this.label});
  final String id;
  final String label;
}

class ActivityFilterSheet extends StatefulWidget {
  const ActivityFilterSheet({
    super.key,
    required this.initialFilters,
    required this.retainedFromUtc,
    required this.nowUtc,
    this.members = const [],
    this.zones = const [],
  });

  final GeofenceActivityFilters initialFilters;
  final DateTime retainedFromUtc;
  final DateTime nowUtc;
  final List<ActivityFilterOption> members;
  final List<ActivityFilterOption> zones;

  @override
  State<ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<ActivityFilterSheet> {
  late GeofenceActivityFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.clampToRetention(widget.nowUtc);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter activity', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Dates are limited to the retained last 7 days.'),
            const SizedBox(height: 20),
            _dropdown(
              label: 'Family member',
              value: _filters.memberId,
              options: widget.members,
              onChanged: (value) => setState(
                () => _filters = _filters.copyWith(
                  memberId: value,
                  clearMember: value == null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _dropdown(
              label: 'Zone',
              value: _filters.zoneId,
              options: widget.zones,
              onChanged: (value) => setState(
                () => _filters = _filters.copyWith(
                  zoneId: value,
                  clearZone: value == null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Transition', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                _transitionChip(null, 'All'),
                _transitionChip(GeofenceActivityTransition.entered, 'Entered'),
                _transitionChip(GeofenceActivityTransition.left, 'Left'),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: const Text('Date range'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _filters.clampToRetention(widget.nowUtc),
              ),
              child: const Text('Show activity'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<ActivityFilterOption> options,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: null, child: Text('All')),
      ...options.map(
        (option) => DropdownMenuItem(value: option.id, child: Text(option.label)),
      ),
    ],
    onChanged: onChanged,
  );

  Widget _transitionChip(GeofenceActivityTransition? value, String label) =>
      ChoiceChip(
        label: Text(label),
        selected: _filters.transition == value,
        onSelected: (_) => setState(
          () => _filters = _filters.copyWith(
            transition: value,
            clearTransition: value == null,
          ),
        ),
      );

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: widget.retainedFromUtc.toLocal(),
      lastDate: widget.nowUtc.toLocal(),
      initialDateRange: DateTimeRange(
        start: (_filters.fromUtc ?? widget.retainedFromUtc).toLocal(),
        end: (_filters.toUtc ?? widget.nowUtc).toLocal(),
      ),
    );
    if (range == null || !mounted) return;
    setState(
      () => _filters = _filters.copyWith(
        fromUtc: DateTime.utc(range.start.year, range.start.month, range.start.day),
        toUtc: DateTime.utc(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        ),
      ).clampToRetention(widget.nowUtc),
    );
  }
}
