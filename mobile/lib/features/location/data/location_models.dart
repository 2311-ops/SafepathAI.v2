class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.recordedAtUtc,
    this.displayName,
    this.batteryPercent,
    this.isOnline = true,
  });

  final String userId;
  final String? displayName;
  final double lat;
  final double lng;
  final double accuracyMeters;
  final int? batteryPercent;
  final DateTime recordedAtUtc;
  final bool isOnline;

  factory LiveLocation.fromJson(Map<String, dynamic> json) {
    return LiveLocation(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
      recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String).toUtc(),
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  LiveLocation copyWith({
    String? displayName,
    double? lat,
    double? lng,
    double? accuracyMeters,
    int? batteryPercent,
    DateTime? recordedAtUtc,
    bool? isOnline,
  }) {
    return LiveLocation(
      userId: userId,
      displayName: displayName ?? this.displayName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class PresenceChange {
  const PresenceChange({required this.userId, required this.isOnline});

  final String userId;
  final bool isOnline;

  factory PresenceChange.fromJson(Map<String, dynamic> json) {
    return PresenceChange(
      userId: json['userId'] as String,
      isOnline: json['isOnline'] as bool,
    );
  }
}

class ReportLocationPayload {
  const ReportLocationPayload({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAtUtc,
    this.batteryPercent,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int? batteryPercent;
  final DateTime recordedAtUtc;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'batteryPercent': batteryPercent,
      'recordedAtUtc': recordedAtUtc.toUtc().toIso8601String(),
    };
  }
}
