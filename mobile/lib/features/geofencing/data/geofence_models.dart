/// Typed values used by the safe-zone editor. These values deliberately stay
/// separate from map widgets so validation and saves remain deterministic.
enum SafeZoneCategory {
  home('Home'),
  school('School'),
  university('University'),
  workplace('Workplace'),
  custom('Custom');

  const SafeZoneCategory(this.wireValue);
  final String wireValue;

  String get defaultName => switch (this) {
    SafeZoneCategory.home => 'Home',
    SafeZoneCategory.school => 'School',
    SafeZoneCategory.university => 'University',
    SafeZoneCategory.workplace => 'Workplace',
    SafeZoneCategory.custom => '',
  };
}

enum SafeZoneSensitivity {
  reliable('Reliable'),
  balanced('Balanced'),
  responsive('Responsive');

  const SafeZoneSensitivity(this.wireValue);
  final String wireValue;

  String get description => switch (this) {
    SafeZoneSensitivity.reliable => 'Wait for a clearer, sustained crossing',
    SafeZoneSensitivity.balanced => 'Recommended for most places',
    SafeZoneSensitivity.responsive => 'Confirm sooner near the boundary',
  };
}

enum SafeZoneActivation { active, inactive, needsLocationPermission }

class SafeZoneCenter {
  const SafeZoneCenter({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory SafeZoneCenter.fromJson(Map<String, dynamic> json) => SafeZoneCenter(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

class SafeZoneDraft {
  const SafeZoneDraft({
    this.zoneId,
    this.familyId,
    this.category = SafeZoneCategory.home,
    this.name = 'Home',
    this.center = const SafeZoneCenter(latitude: 0, longitude: 0),
    this.hasExplicitCenter = false,
    this.radiusMeters = 100,
    this.assignedMemberId,
    this.sensitivity = SafeZoneSensitivity.reliable,
    this.guardianRecipientIds = const {},
    this.notifyAssignedMember = false,
  });

  final String? zoneId;
  final String? familyId;
  final SafeZoneCategory category;
  final String name;
  final SafeZoneCenter center;
  final bool hasExplicitCenter;
  final int radiusMeters;
  final String? assignedMemberId;
  final SafeZoneSensitivity sensitivity;
  final Set<String> guardianRecipientIds;
  final bool notifyAssignedMember;

  static const radiusPresets = <int>[100, 250, 500, 1000];
  static const minRadiusMeters = 100;
  static const maxRadiusMeters = 2000;
  static const radiusStepMeters = 25;

  bool get hasValidRadius =>
      radiusMeters >= minRadiusMeters &&
      radiusMeters <= maxRadiusMeters &&
      radiusMeters % radiusStepMeters == 0;

  SafeZoneDraft copyWith({
    String? zoneId,
    String? familyId,
    SafeZoneCategory? category,
    String? name,
    SafeZoneCenter? center,
    bool? hasExplicitCenter,
    int? radiusMeters,
    String? assignedMemberId,
    bool clearAssignedMember = false,
    SafeZoneSensitivity? sensitivity,
    Set<String>? guardianRecipientIds,
    bool? notifyAssignedMember,
  }) => SafeZoneDraft(
    zoneId: zoneId ?? this.zoneId,
    familyId: familyId ?? this.familyId,
    category: category ?? this.category,
    name: name ?? this.name,
    center: center ?? this.center,
    hasExplicitCenter: hasExplicitCenter ?? this.hasExplicitCenter,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    assignedMemberId: clearAssignedMember
        ? null
        : (assignedMemberId ?? this.assignedMemberId),
    sensitivity: sensitivity ?? this.sensitivity,
    guardianRecipientIds: guardianRecipientIds ?? this.guardianRecipientIds,
    notifyAssignedMember: notifyAssignedMember ?? this.notifyAssignedMember,
  );

  /// Builds an editable draft from an existing [zone] so the edit journey
  /// reuses the same review/save path as create. Carrying [zone.id] into
  /// [zoneId] is what makes [GeofenceController.save] choose
  /// `GeofenceApi.update` over `GeofenceApi.create`.
  factory SafeZoneDraft.fromZone(SafeZone zone, {String? familyId}) =>
      SafeZoneDraft(
        zoneId: zone.id,
        familyId: familyId,
        category: zone.category,
        name: zone.name,
        center: zone.center,
        hasExplicitCenter: true,
        radiusMeters: zone.radiusMeters,
        assignedMemberId: zone.assignedMemberId,
        sensitivity: zone.sensitivity,
        guardianRecipientIds: zone.guardianRecipientIds,
        notifyAssignedMember: zone.notifyAssignedMember,
      );

  Map<String, Object?> toRequest() => {
    'category': category.wireValue,
    // The server uses null for an untouched standard category, but a guardian
    // may supply an editable name for every category.
    'customName': name.trim(),
    ...center.toJson(),
    'radiusMeters': radiusMeters,
    'assignedMemberUserId': assignedMemberId,
    'sensitivity': sensitivity.wireValue,
    'recipientUserIds': guardianRecipientIds.toList(growable: false),
    'notifyAssignedMember': notifyAssignedMember,
  };
}

class SafeZoneValidation {
  const SafeZoneValidation({
    this.name,
    this.location,
    this.member,
    this.radius,
    this.recipients,
  });

  final String? name;
  final String? location;
  final String? member;
  final String? radius;
  final String? recipients;

  bool get isValid =>
      name == null &&
      location == null &&
      member == null &&
      radius == null &&
      recipients == null;
}

class SafeZone {
  const SafeZone({
    required this.id,
    required this.name,
    required this.category,
    required this.center,
    required this.radiusMeters,
    required this.assignedMemberId,
    required this.sensitivity,
    required this.guardianRecipientIds,
    required this.notifyAssignedMember,
    this.activation = SafeZoneActivation.active,
  });

  final String id;
  final String name;
  final SafeZoneCategory category;
  final SafeZoneCenter center;
  final int radiusMeters;
  final String assignedMemberId;
  final SafeZoneSensitivity sensitivity;
  final Set<String> guardianRecipientIds;
  final bool notifyAssignedMember;
  final SafeZoneActivation activation;

  bool get isActive => activation == SafeZoneActivation.active;

  SafeZone copyWith({SafeZoneActivation? activation}) => SafeZone(
    id: id,
    name: name,
    category: category,
    center: center,
    radiusMeters: radiusMeters,
    assignedMemberId: assignedMemberId,
    sensitivity: sensitivity,
    guardianRecipientIds: guardianRecipientIds,
    notifyAssignedMember: notifyAssignedMember,
    activation: activation ?? this.activation,
  );

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    final category = _enumFromWire(
      SafeZoneCategory.values,
      json['category'] as String? ?? 'Home',
      (value) => value.wireValue,
    );
    return SafeZone(
      id: (json['zoneId'] ?? json['id']) as String,
      name: (json['customName'] as String?)?.trim().isNotEmpty == true
          ? (json['customName'] as String).trim()
          : category.defaultName,
      category: category,
      center: SafeZoneCenter(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      ),
      radiusMeters: (json['radiusMeters'] as num).round(),
      assignedMemberId: json['assignedMemberUserId'] as String,
      sensitivity: _enumFromWire(
        SafeZoneSensitivity.values,
        json['sensitivity'] as String? ?? 'Balanced',
        (value) => value.wireValue,
      ),
      guardianRecipientIds:
          ((json['recipientUserIds'] as List<dynamic>?) ?? const [])
              .whereType<String>()
              .toSet(),
      notifyAssignedMember: json['notifyAssignedMember'] as bool? ?? false,
      activation: json['needsLocationPermission'] == true
          ? SafeZoneActivation.needsLocationPermission
          : (json['active'] as bool? ?? true)
          ? SafeZoneActivation.active
          : SafeZoneActivation.inactive,
    );
  }
}

T _enumFromWire<T>(
  Iterable<T> values,
  String wireValue,
  String Function(T value) selector,
) => values.firstWhere(
  (value) => selector(value).toLowerCase() == wireValue.toLowerCase(),
  orElse: () => throw ArgumentError('Unknown wire value: $wireValue'),
);
