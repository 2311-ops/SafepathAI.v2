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
    this.profileImageUrl,
    this.profileUpdatedAt,
  });

  final String userId;
  final String? displayName;
  final double lat;
  final double lng;
  final double accuracyMeters;
  final int? batteryPercent;
  final DateTime recordedAtUtc;
  final bool isOnline;
  final String? profileImageUrl;
  final DateTime? profileUpdatedAt;

  factory LiveLocation.fromJson(Map<String, dynamic> json) {
    final profileUpdatedAtValue = json['profileUpdatedAt'] as String?;
    return LiveLocation(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
      recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String).toUtc(),
      isOnline: json['isOnline'] as bool? ?? true,
      profileImageUrl: json['profileImageUrl'] as String?,
      profileUpdatedAt: profileUpdatedAtValue == null
          ? null
          : DateTime.tryParse(profileUpdatedAtValue)?.toUtc(),
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
    String? profileImageUrl,
    DateTime? profileUpdatedAt,
    // Standard nullable-merge (?? this.x) can't express "clear this field to
    // null" — a removed profile photo (PROFILE-03/06) must actually clear the
    // marker avatar, not silently keep the previous one. Mirrors this
    // codebase's clearError/clearLowBatteryAlert boolean-flag convention.
    bool clearProfileImage = false,
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
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
      profileUpdatedAt: clearProfileImage
          ? profileUpdatedAt
          : (profileUpdatedAt ?? this.profileUpdatedAt),
    );
  }
}

class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.recordedAtUtc,
  });

  final double lat;
  final double lng;
  final DateTime recordedAtUtc;

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String).toUtc(),
    );
  }
}

class HistoryStop {
  const HistoryStop({
    required this.startUtc,
    required this.endUtc,
    required this.lat,
    required this.lng,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final double lat;
  final double lng;

  Duration get duration => endUtc.difference(startUtc);

  factory HistoryStop.fromJson(Map<String, dynamic> json) {
    return HistoryStop(
      startUtc: DateTime.parse(json['startUtc'] as String).toUtc(),
      endUtc: DateTime.parse(json['endUtc'] as String).toUtc(),
      lat: ((json['latitude'] ?? json['lat']) as num).toDouble(),
      lng: ((json['longitude'] ?? json['lng']) as num).toDouble(),
    );
  }
}

class LocationHistory {
  const LocationHistory({
    this.polylinePoints = const [],
    this.stops = const [],
  });

  final List<RoutePoint> polylinePoints;
  final List<HistoryStop> stops;

  bool get isEmpty => polylinePoints.isEmpty && stops.isEmpty;

  factory LocationHistory.fromJson(Map<String, dynamic> json) {
    final points = (json['polylinePoints'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => RoutePoint.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
    final stops = (json['stops'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => HistoryStop.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
    return LocationHistory(polylinePoints: points, stops: stops);
  }
}

class TravelStats {
  const TravelStats({
    this.distanceMeters = 0,
    this.timeAway = Duration.zero,
    this.stopCount = 0,
  });

  final double distanceMeters;
  final Duration timeAway;
  final int stopCount;

  factory TravelStats.fromJson(Map<String, dynamic> json) {
    return TravelStats(
      distanceMeters:
          ((json['totalDistanceMeters'] ?? json['distanceMeters']) as num? ?? 0)
              .toDouble(),
      timeAway: _parseTimeAway(json['timeAway']),
      stopCount: ((json['stopCount'] as num?) ?? 0).toInt(),
    );
  }
}

Duration _parseTimeAway(Object? value) {
  if (value == null) return Duration.zero;
  if (value is num) return Duration(milliseconds: value.round());
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return Duration.zero;

    final daySplit = trimmed.split('.');
    var days = 0;
    var timePart = trimmed;
    if (daySplit.length == 2 && int.tryParse(daySplit.first) != null) {
      days = int.parse(daySplit.first);
      timePart = daySplit.last;
    }

    final parts = timePart.split(':');
    if (parts.length >= 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final secondsPart = parts[2].split('.').first;
      final seconds = int.tryParse(secondsPart) ?? 0;
      return Duration(
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
      );
    }

    final iso = RegExp(
      r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
    ).firstMatch(trimmed);
    if (iso != null) {
      return Duration(
        days: int.tryParse(iso.group(1) ?? '') ?? 0,
        hours: int.tryParse(iso.group(2) ?? '') ?? 0,
        minutes: int.tryParse(iso.group(3) ?? '') ?? 0,
        seconds: int.tryParse(iso.group(4) ?? '') ?? 0,
      );
    }
  }
  return Duration.zero;
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

class ProfileUpdate {
  const ProfileUpdate({
    required this.userId,
    this.displayName,
    this.profileImageUrl,
  });

  final String userId;
  final String? displayName;
  final String? profileImageUrl;

  factory ProfileUpdate.fromJson(Map<String, dynamic> json) {
    return ProfileUpdate(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}

class LowBatteryAlert {
  const LowBatteryAlert({
    required this.userId,
    required this.name,
    required this.batteryPercent,
  });

  final String userId;
  final String name;
  final int batteryPercent;

  factory LowBatteryAlert.fromJson(Map<String, dynamic> json) {
    return LowBatteryAlert(
      userId: json['userId'] as String? ?? '',
      name:
          (json['name'] as String?) ??
          (json['displayName'] as String?) ??
          'A family member',
      batteryPercent:
          ((json['batteryPercent'] as num?) ?? (json['pct'] as num?) ?? 0)
              .toInt(),
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
