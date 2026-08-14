import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../application/routine_notifications_controller.dart';

class QuietHoursPage extends ConsumerStatefulWidget {
  const QuietHoursPage({super.key});

  @override
  ConsumerState<QuietHoursPage> createState() => _QuietHoursPageState();
}

class _QuietHoursPageState extends ConsumerState<QuietHoursPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(routineNotificationsControllerProvider.notifier)
          .loadQuietHours(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(routineNotificationsControllerProvider).value ??
        const RoutineNotificationsState();
    return QuietHoursScreen(
      initial: state.quietHours,
      isSaving: state.isLoading,
      serverError: state.error,
      onSave: (setting) async {
        final didSave = await ref
            .read(routineNotificationsControllerProvider.notifier)
            .saveQuietHours(setting);
        if (didSave && context.mounted) Navigator.of(context).pop();
      },
    );
  }
}

class QuietHoursScreen extends StatefulWidget {
  const QuietHoursScreen({
    super.key,
    required this.initial,
    this.onSave,
    this.isSaving = false,
    this.serverError,
  });

  final QuietHoursSetting initial;
  final Future<void> Function(QuietHoursSetting setting)? onSave;
  final bool isSaving;
  final String? serverError;

  @override
  State<QuietHoursScreen> createState() => _QuietHoursScreenState();
}

class _QuietHoursScreenState extends State<QuietHoursScreen> {
  late bool _isEnabled;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late TextEditingController _timeZone;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initial.isEnabled;
    _start = _parseTime(widget.initial.localStart);
    _end = _parseTime(widget.initial.localEnd);
    _timeZone = TextEditingController(text: widget.initial.timeZoneId);
  }

  @override
  void dispose() {
    _timeZone.dispose();
    super.dispose();
  }

  Future<void> _selectTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
      _validationError = null;
    });
  }

  Future<void> _save() async {
    final zone = _timeZone.text.trim();
    final validation = _validate(zone);
    if (validation != null) {
      setState(() => _validationError = validation);
      return;
    }
    await widget.onSave?.call(
      QuietHoursSetting(
        isEnabled: _isEnabled,
        localStart: _wireTime(_start),
        localEnd: _wireTime(_end),
        timeZoneId: zone,
      ),
    );
  }

  String? _validate(String zone) {
    if (!_ianaZone.hasMatch(zone)) {
      return 'Enter an IANA time zone such as Africa/Cairo.';
    }
    if (_isEnabled && _start == _end) {
      return 'Choose different start and end times.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBg,
    appBar: AppBar(title: const Text('Quiet hours')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Routine notifications', style: AppTypography.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Activity and your in-app feed remain immediate. Only routine push waits until quiet hours end. SOS always bypasses quiet hours.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Enable quiet hours', style: AppTypography.body),
            subtitle: const Text('Delay routine safe-zone push notifications.'),
            value: _isEnabled,
            activeThumbColor: AppColors.primaryTeal,
            onChanged: widget.isSaving
                ? null
                : (value) => setState(() {
                    _isEnabled = value;
                    _validationError = null;
                  }),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimeSelector(
            label: 'LOCAL START',
            time: _start,
            onPressed: widget.isSaving ? null : () => _selectTime(start: true),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimeSelector(
            label: 'LOCAL END',
            time: _end,
            onPressed: widget.isSaving ? null : () => _selectTime(start: false),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('TIME ZONE (IANA)', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('time-zone-id'),
            controller: _timeZone,
            enabled: !widget.isSaving,
            decoration: const InputDecoration(
              hintText: 'Africa/Cairo',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _validationError = null),
          ),
          if (_validationError != null || widget.serverError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _validationError ?? widget.serverError!,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.cautionText,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: widget.isSaving ? 'Saving…' : 'Save quiet hours',
            onPressed: widget.isSaving ? null : _save,
          ),
        ],
      ),
    ),
  );
}

class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.caption),
      const SizedBox(height: AppSpacing.xs),
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(_displayTime(time), style: AppTypography.body),
        ),
      ),
    ],
  );
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return const TimeOfDay(hour: 0, minute: 0);
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: int.tryParse(parts[1]) ?? 0,
  );
}

String _displayTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _wireTime(TimeOfDay time) => '${_displayTime(time)}:00';

final _ianaZone = RegExp(r'^[A-Za-z][A-Za-z_-]*(?:/[A-Za-z][A-Za-z_-]*)+$');
