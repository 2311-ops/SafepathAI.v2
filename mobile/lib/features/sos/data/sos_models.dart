/// Dart mirrors of the SOS wire DTOs defined in
/// `backend/src/SafePath.Application/Sos/SosDtos.cs` (03-01-PLAN.md).
///
/// A malformed/unknown enum string on the wire never throws — it falls back
/// to a safe default so a partially-understood payload can never crash the
/// emergency screen (D-09/D-10 correctness: the UI must always be able to
/// render *something*, even a degraded one, for a safety-critical surface).
library;

/// Delivery channel for one recipient's alert attempt. Mirrors
/// `SafePath.Domain.Enums.AlertChannel`.
enum SosChannel { signalR, fcm, sms, unknown }

SosChannel _parseSosChannel(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'signalr':
      return SosChannel.signalR;
    case 'fcm':
      return SosChannel.fcm;
    case 'sms':
      return SosChannel.sms;
    default:
      return SosChannel.unknown;
  }
}

/// Per-(recipient, channel) delivery state. Mirrors
/// `SafePath.Domain.Enums.SosDeliveryStatus` — the exact five-state
/// vocabulary 03-UI-SPEC.md's Delivery Status Vocabulary renders. Never
/// collapsed to a single "sent" boolean (D-09).
enum SosDeliveryStatus {
  notAttempted,
  queued,
  delivered,
  acknowledged,
  failed,
  unknown,
}

SosDeliveryStatus _parseSosDeliveryStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'notattempted':
      return SosDeliveryStatus.notAttempted;
    case 'queued':
      return SosDeliveryStatus.queued;
    case 'delivered':
      return SosDeliveryStatus.delivered;
    case 'acknowledged':
      return SosDeliveryStatus.acknowledged;
    case 'failed':
      return SosDeliveryStatus.failed;
    default:
      return SosDeliveryStatus.unknown;
  }
}

/// Lifecycle status of an SOS emergency. Mirrors
/// `SafePath.Domain.Enums.SosSessionStatus`.
enum SosSessionStatus { active, canceled, unknown }

SosSessionStatus _parseSosSessionStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'active':
      return SosSessionStatus.active;
    case 'canceled':
    case 'cancelled':
      return SosSessionStatus.canceled;
    default:
      return SosSessionStatus.unknown;
  }
}

/// Mirrors `SosChannelStatusDto`.
class SosChannelStatus {
  const SosChannelStatus({
    required this.channel,
    required this.status,
    this.queuedAtUtc,
    this.deliveredAtUtc,
    this.acknowledgedAtUtc,
  });

  final SosChannel channel;
  final SosDeliveryStatus status;
  final DateTime? queuedAtUtc;
  final DateTime? deliveredAtUtc;
  final DateTime? acknowledgedAtUtc;

  factory SosChannelStatus.fromJson(Map<String, dynamic> json) {
    return SosChannelStatus(
      channel: _parseSosChannel(json['channel'] as String?),
      status: _parseSosDeliveryStatus(json['status'] as String?),
      queuedAtUtc: _parseNullableDateTime(json['queuedAtUtc']),
      deliveredAtUtc: _parseNullableDateTime(json['deliveredAtUtc']),
      acknowledgedAtUtc: _parseNullableDateTime(json['acknowledgedAtUtc']),
    );
  }
}

/// Mirrors `SosRecipientStatusDto`. Carries [displayName] only — no phone
/// number or device token ever appears on the wire (threat T-03-03).
class SosRecipientStatus {
  const SosRecipientStatus({
    required this.displayName,
    required this.channels,
    this.recipientUserId,
    this.emergencyContactId,
  });

  final String? recipientUserId;
  final String? emergencyContactId;
  final String displayName;
  final List<SosChannelStatus> channels;

  factory SosRecipientStatus.fromJson(Map<String, dynamic> json) {
    final channelsJson = json['channels'] as List<dynamic>? ?? const [];
    return SosRecipientStatus(
      recipientUserId: json['recipientUserId'] as String?,
      emergencyContactId: json['emergencyContactId'] as String?,
      displayName: (json['displayName'] as String?) ?? 'A family member',
      channels: channelsJson
          .whereType<Map>()
          .map(
            (entry) =>
                SosChannelStatus.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(),
    );
  }
}

/// Mirrors `SosSessionDto`. Omits the wire's `kind` field deliberately — it
/// is backend-only forward-compat for Phase 6 Silent/Duress and has no UI
/// surface in this phase (D-29).
class SosSession {
  const SosSession({
    required this.sosSessionId,
    required this.familyId,
    required this.triggeredByUserId,
    required this.status,
    required this.triggeredAtUtc,
    required this.receivedAtUtc,
    this.liveWindowEndsAtUtc,
    this.canceledAtUtc,
    this.recipients = const [],
  });

  final String sosSessionId;
  final String familyId;
  final String triggeredByUserId;
  final SosSessionStatus status;
  final DateTime triggeredAtUtc;
  final DateTime receivedAtUtc;
  final DateTime? liveWindowEndsAtUtc;
  final DateTime? canceledAtUtc;
  final List<SosRecipientStatus> recipients;

  factory SosSession.fromJson(Map<String, dynamic> json) {
    final recipientsJson = json['recipients'] as List<dynamic>? ?? const [];
    return SosSession(
      sosSessionId: json['sosSessionId'] as String,
      familyId: json['familyId'] as String,
      triggeredByUserId: json['triggeredByUserId'] as String,
      status: _parseSosSessionStatus(json['status'] as String?),
      triggeredAtUtc: DateTime.parse(json['triggeredAtUtc'] as String).toUtc(),
      receivedAtUtc: DateTime.parse(json['receivedAtUtc'] as String).toUtc(),
      liveWindowEndsAtUtc: _parseNullableDateTime(json['liveWindowEndsAtUtc']),
      canceledAtUtc: _parseNullableDateTime(json['canceledAtUtc']),
      recipients: recipientsJson
          .whereType<Map>()
          .map(
            (entry) =>
                SosRecipientStatus.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(),
    );
  }
}

/// Mirrors `SosDeliveryStatusChangedDto` — pushed to the family alert group
/// whenever a single (recipient, channel) delivery row's status changes.
/// Lets a connected client update one row of the delivery matrix without
/// re-fetching the whole session.
class SosDeliveryStatusChange {
  const SosDeliveryStatusChange({
    required this.sosSessionId,
    this.recipientUserId,
    this.emergencyContactId,
    required this.channel,
    required this.status,
    required this.atUtc,
  });

  final String sosSessionId;
  final String? recipientUserId;
  final String? emergencyContactId;
  final SosChannel channel;
  final SosDeliveryStatus status;
  final DateTime atUtc;

  factory SosDeliveryStatusChange.fromJson(Map<String, dynamic> json) {
    return SosDeliveryStatusChange(
      sosSessionId: json['sosSessionId'] as String,
      recipientUserId: json['recipientUserId'] as String?,
      emergencyContactId: json['emergencyContactId'] as String?,
      channel: _parseSosChannel(json['channel'] as String?),
      status: _parseSosDeliveryStatus(json['status'] as String?),
      atUtc: DateTime.parse(json['atUtc'] as String).toUtc(),
    );
  }
}

/// Mirrors `SosCanceledDto` — pushed when the triggering user cancels their
/// own SOS session (D-05, D-24). A parallel follow-up notice, never a
/// retraction of the original delivery history.
class SosCancellation {
  const SosCancellation({
    required this.sosSessionId,
    required this.canceledByUserId,
    required this.canceledByDisplayName,
    required this.canceledAtUtc,
  });

  final String sosSessionId;
  final String canceledByUserId;
  final String canceledByDisplayName;
  final DateTime canceledAtUtc;

  factory SosCancellation.fromJson(Map<String, dynamic> json) {
    return SosCancellation(
      sosSessionId: json['sosSessionId'] as String,
      canceledByUserId: json['canceledByUserId'] as String,
      canceledByDisplayName:
          (json['canceledByDisplayName'] as String?) ?? 'A family member',
      canceledAtUtc: DateTime.parse(json['canceledAtUtc'] as String).toUtc(),
    );
  }
}

/// Mirrors `SosLocationUpdateDto` — a live-location window update pushed
/// during an active SOS session. Declared now so the hub client's contract
/// is stable across this plan and plan 03-08 (the first to render it).
class SosLocationUpdate {
  const SosLocationUpdate({
    required this.sosSessionId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.recordedAtUtc,
    required this.windowEndsAtUtc,
  });

  final String sosSessionId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime recordedAtUtc;
  final DateTime windowEndsAtUtc;

  factory SosLocationUpdate.fromJson(Map<String, dynamic> json) {
    return SosLocationUpdate(
      sosSessionId: json['sosSessionId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String).toUtc(),
      windowEndsAtUtc: DateTime.parse(
        json['windowEndsAtUtc'] as String,
      ).toUtc(),
    );
  }
}

/// Request body mirroring `TriggerSosRequest` — `sosSessionId` is generated
/// on-device before this is ever built (D-13/D-14).
class SosTriggerRequest {
  const SosTriggerRequest({
    required this.sosSessionId,
    required this.familyId,
    required this.triggeredAtUtc,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  final String sosSessionId;
  final String familyId;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime triggeredAtUtc;

  Map<String, dynamic> toJson() {
    return {
      'sosSessionId': sosSessionId,
      'familyId': familyId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'triggeredAtUtc': triggeredAtUtc.toUtc().toIso8601String(),
    };
  }

  factory SosTriggerRequest.fromJson(Map<String, dynamic> json) {
    return SosTriggerRequest(
      sosSessionId: json['sosSessionId'] as String,
      familyId: json['familyId'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      triggeredAtUtc: DateTime.parse(json['triggeredAtUtc'] as String).toUtc(),
    );
  }
}

DateTime? _parseNullableDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
