enum SharedDataType {
  liveLocation('LiveLocation', 'Live location'),
  history('History', 'History'),
  wellness('Wellness', 'Wellness');

  const SharedDataType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SharedDataType fromWire(String value) => SharedDataType.values.firstWhere(
        (type) => type.wireValue == value,
        orElse: () => throw ArgumentError('Unknown shared data type: $value'),
      );
}

class SharingCell {
  const SharingCell({
    this.recipientId,
    this.recipientName,
    required this.dataType,
    required this.isEnabled,
    this.expiresAtUtc,
    this.startedAtUtc,
  });

  final String? recipientId;
  final String? recipientName;
  final SharedDataType dataType;
  final bool isEnabled;
  final DateTime? expiresAtUtc;

  /// When this temporary share began, in UTC. Captured client-side at session
  /// start so the banner can show the *total* selected duration
  /// (`expiresAtUtc - startedAtUtc`) instead of guessing it from the remaining
  /// time. The backend neither stores nor returns this field, so it is null for
  /// sessions restored from the server (e.g. after an app restart); callers
  /// must fall back to the remaining time in that case.
  final DateTime? startedAtUtc;

  factory SharingCell.fromJson(Map<String, dynamic> json) => SharingCell(
        recipientId: json['recipientMemberId'] as String?,
        recipientName: json['recipientName'] as String?,
        dataType: SharedDataType.fromWire(json['dataType'] as String),
        isEnabled: json['isEnabled'] as bool,
        expiresAtUtc: json['expiresAtUtc'] == null
            ? null
            : DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
        startedAtUtc: json['startedAtUtc'] == null
            ? null
            : DateTime.parse(json['startedAtUtc'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'recipientMemberId': recipientId,
        'recipientName': recipientName,
        'dataType': dataType.wireValue,
        'isEnabled': isEnabled,
        'expiresAtUtc': expiresAtUtc?.toUtc().toIso8601String(),
        'startedAtUtc': startedAtUtc?.toUtc().toIso8601String(),
      };

  SharingCell copyWith({
    String? recipientId,
    String? recipientName,
    SharedDataType? dataType,
    bool? isEnabled,
    DateTime? expiresAtUtc,
    DateTime? startedAtUtc,
    bool clearExpiry = false,
    bool clearStarted = false,
  }) {
    return SharingCell(
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      dataType: dataType ?? this.dataType,
      isEnabled: isEnabled ?? this.isEnabled,
      expiresAtUtc: clearExpiry ? null : (expiresAtUtc ?? this.expiresAtUtc),
      startedAtUtc: clearStarted ? null : (startedAtUtc ?? this.startedAtUtc),
    );
  }

  /// Describes an *active* temporary share for the banner, or null when there is
  /// nothing to show (sharing off, no expiry, or already expired). All timing is
  /// derived from [expiresAtUtc]/[startedAtUtc] as the single source of truth —
  /// never from the dropdown/enum the user tapped — so the total and remaining
  /// labels can never disagree.
  ActiveShareView? describeActiveShare({required DateTime now}) {
    final expiresAt = expiresAtUtc;
    if (!isEnabled || expiresAt == null) return null;

    final nowUtc = now.toUtc();
    final remaining = expiresAt.difference(nowUtc);
    if (remaining <= Duration.zero) return null; // expired — clamp, don't show.

    final started = startedAtUtc;
    final total = started == null ? null : expiresAt.difference(started);
    // Total is only known when we captured the start locally; otherwise fall
    // back to the (ceil-rounded) remaining so the banner stays self-consistent.
    final totalDuration =
        (total == null || total.isNegative) ? remaining : total;

    return ActiveShareView(
      totalLabel: formatShareDuration(totalDuration),
      remainingLabel: formatShareDuration(remaining),
    );
  }
}

/// The two labels the active-sharing banner renders. Both are produced by
/// [formatShareDuration] so "Sharing for X" can never exceed or contradict the
/// "Y left" it sits next to.
class ActiveShareView {
  const ActiveShareView({
    required this.totalLabel,
    required this.remainingLabel,
  });

  final String totalLabel;
  final String remainingLabel;
}

/// Formats a sharing duration for display using **ceiling** rounding, so a
/// session with 3h59m left reads "4 hours" and one with exactly 3h left reads
/// "3 hours". Non-positive durations clamp to "0 minutes" (never negative).
String formatShareDuration(Duration duration) {
  if (duration <= Duration.zero) return '0 minutes';

  final totalMinutes = (duration.inSeconds / 60).ceil();
  if (totalMinutes < 60) {
    return '$totalMinutes ${totalMinutes == 1 ? 'minute' : 'minutes'}';
  }

  final hours = (totalMinutes / 60).ceil();
  return '$hours ${hours == 1 ? 'hour' : 'hours'}';
}

class SharingMatrix {
  const SharingMatrix({this.entries = const []});

  final List<SharingCell> entries;

  factory SharingMatrix.fromJson(Map<String, dynamic> json) => SharingMatrix(
        entries: (json['entries'] as List<dynamic>? ?? const [])
            .map((entry) => SharingCell.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );

  bool isEnabled(String? recipientId, SharedDataType dataType) =>
      cellFor(recipientId, dataType)?.isEnabled ?? false;

  SharingCell? cellFor(String? recipientId, SharedDataType dataType) {
    for (final entry in entries) {
      if (entry.recipientId == recipientId && entry.dataType == dataType) {
        return entry;
      }
    }
    return null;
  }

  Duration? timeRemaining(
    String? recipientId,
    SharedDataType dataType, {
    required DateTime now,
  }) {
    final cell = cellFor(recipientId, dataType);
    final expiresAt = cell?.expiresAtUtc;
    if (cell == null || !cell.isEnabled || expiresAt == null) return null;
    final remaining = expiresAt.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  SharingMatrix upsert(SharingCell cell) {
    var replaced = false;
    final nextEntries = [
      for (final entry in entries)
        if (entry.recipientId == cell.recipientId &&
            entry.dataType == cell.dataType)
          () {
            replaced = true;
            return cell;
          }()
        else
          entry,
    ];
    if (!replaced) nextEntries.add(cell);
    return SharingMatrix(entries: nextEntries);
  }

  SharingMatrix removeCell(String? recipientId, SharedDataType dataType) {
    return SharingMatrix(
      entries: [
        for (final entry in entries)
          if (entry.recipientId != recipientId || entry.dataType != dataType)
            entry,
      ],
    );
  }
}

class PrivacyPolicy {
  const PrivacyPolicy({
    required this.title,
    required this.noDataResaleCommitment,
    required this.dataCollected,
    required this.retention,
    required this.exportAndDeleteRights,
  });

  final String title;
  final String noDataResaleCommitment;
  final String dataCollected;
  final String retention;
  final String exportAndDeleteRights;

  factory PrivacyPolicy.fromJson(Map<String, dynamic> json) => PrivacyPolicy(
        title: json['title'] as String,
        noDataResaleCommitment: json['noDataResaleCommitment'] as String,
        dataCollected: json['dataCollected'] as String,
        retention: json['retention'] as String,
        exportAndDeleteRights: json['exportAndDeleteRights'] as String,
      );
}
