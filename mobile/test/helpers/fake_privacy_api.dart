import 'dart:convert';

import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';

class FakePrivacyApi implements PrivacyApi {
  SharingMatrix matrixToReturn = const SharingMatrix(entries: []);
  PrivacyApiException? updateError;
  PrivacyApiException? exportError;
  PrivacyPolicy policyToReturn = const PrivacyPolicy(
    title: 'SafePath Privacy Commitment',
    noDataResaleCommitment: 'SafePath does not sell, rent, or resell data.',
    dataCollected: 'Location data powers family safety features.',
    retention: 'Location data is retained until you delete it.',
    exportAndDeleteRights: 'You can export or delete your data anytime.',
  );

  int getSharingMatrixCallCount = 0;
  int updateSharingPreferenceCallCount = 0;
  int exportMyDataCallCount = 0;
  int deleteMyDataCallCount = 0;
  int getPolicyCallCount = 0;

  String? lastFamilyId;
  String? lastUpdateFamilyId;
  String? lastRecipientMemberId;
  SharedDataType? lastDataType;
  bool? lastIsEnabled;
  DateTime? lastExpiresAtUtc;

  @override
  Future<SharingMatrix> getSharingMatrix(String familyId) async {
    getSharingMatrixCallCount++;
    lastFamilyId = familyId;
    return matrixToReturn;
  }

  @override
  Future<SharingCell> updateSharingPreference(
    String familyId, {
    String? recipientMemberId,
    required SharedDataType dataType,
    required bool isEnabled,
    DateTime? expiresAtUtc,
  }) async {
    updateSharingPreferenceCallCount++;
    lastUpdateFamilyId = familyId;
    lastRecipientMemberId = recipientMemberId;
    lastDataType = dataType;
    lastIsEnabled = isEnabled;
    lastExpiresAtUtc = expiresAtUtc;
    final error = updateError;
    if (error != null) throw error;
    return SharingCell(
      recipientId: recipientMemberId,
      dataType: dataType,
      isEnabled: isEnabled,
      expiresAtUtc: expiresAtUtc,
    );
  }

  @override
  Future<String> exportMyData() async {
    exportMyDataCallCount++;
    final error = exportError;
    if (error != null) throw error;
    return jsonEncode({'locationPings': [], 'sharingPreferences': []});
  }

  @override
  Future<void> deleteMyData() async {
    deleteMyDataCallCount++;
  }

  @override
  Future<PrivacyPolicy> getPolicy() async {
    getPolicyCallCount++;
    return policyToReturn;
  }
}
