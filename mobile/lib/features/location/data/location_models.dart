class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.recordedAtUtc,
    this.batteryPercent,
  });

  final String userId;
  final double lat;
  final double lng;
  final double accuracyMeters;
  final int? batteryPercent;
  final DateTime recordedAtUtc;

  factory LiveLocation.fromJson(Map<String, dynamic> json) {
    return LiveLocation(
      userId: json['userId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
      recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String).toUtc(),
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
