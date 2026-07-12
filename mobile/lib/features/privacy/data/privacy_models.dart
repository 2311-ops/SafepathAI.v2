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
  });

  final String? recipientId;
  final String? recipientName;
  final SharedDataType dataType;
  final bool isEnabled;
  final DateTime? expiresAtUtc;

  factory SharingCell.fromJson(Map<String, dynamic> json) => SharingCell(
        recipientId: json['recipientMemberId'] as String?,
        recipientName: json['recipientName'] as String?,
        dataType: SharedDataType.fromWire(json['dataType'] as String),
        isEnabled: json['isEnabled'] as bool,
        expiresAtUtc: json['expiresAtUtc'] == null
            ? null
            : DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'recipientMemberId': recipientId,
        'recipientName': recipientName,
        'dataType': dataType.wireValue,
        'isEnabled': isEnabled,
        'expiresAtUtc': expiresAtUtc?.toUtc().toIso8601String(),
      };

  SharingCell copyWith({
    String? recipientId,
    String? recipientName,
    SharedDataType? dataType,
    bool? isEnabled,
    DateTime? expiresAtUtc,
    bool clearExpiry = false,
  }) {
    return SharingCell(
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      dataType: dataType ?? this.dataType,
      isEnabled: isEnabled ?? this.isEnabled,
      expiresAtUtc: clearExpiry ? null : (expiresAtUtc ?? this.expiresAtUtc),
    );
  }
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
