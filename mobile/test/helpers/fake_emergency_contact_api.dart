import 'package:mobile/features/sos/data/emergency_contact_api.dart';

/// Hand-written [EmergencyContactApi] fake (matches `fake_location_api.dart`'s
/// convention — no mocking package).
class FakeEmergencyContactApi implements EmergencyContactApi {
  List<EmergencyContact> contactsToList = const [];
  EmergencyContactApiException? listError;

  EmergencyContactApiException? addError;
  EmergencyContact Function(String name, String phoneNumber, String? region)?
  addResponseBuilder;
  final List<({String name, String phoneNumber, String? region})> addCalls = [];

  EmergencyContactApiException? updateError;
  EmergencyContact Function(
    String contactId,
    String name,
    String phoneNumber,
    String? region,
  )?
  updateResponseBuilder;
  final List<({String contactId, String name, String phoneNumber, String? region})>
  updateCalls = [];

  EmergencyContactApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<List<EmergencyContact>> list() async {
    if (listError != null) throw listError!;
    return contactsToList;
  }

  @override
  Future<EmergencyContact> add(
    String name,
    String phoneNumber,
    String? region,
  ) async {
    addCalls.add((name: name, phoneNumber: phoneNumber, region: region));
    if (addError != null) throw addError!;
    final builder = addResponseBuilder;
    if (builder != null) return builder(name, phoneNumber, region);
    return EmergencyContact(
      id: 'contact-${addCalls.length}',
      displayName: name,
      phoneNumberE164: phoneNumber,
      isActive: true,
    );
  }

  @override
  Future<EmergencyContact> update(
    String contactId,
    String name,
    String phoneNumber,
    String? region,
  ) async {
    updateCalls.add((
      contactId: contactId,
      name: name,
      phoneNumber: phoneNumber,
      region: region,
    ));
    if (updateError != null) throw updateError!;
    final builder = updateResponseBuilder;
    if (builder != null) return builder(contactId, name, phoneNumber, region);
    return EmergencyContact(
      id: contactId,
      displayName: name,
      phoneNumberE164: phoneNumber,
      isActive: true,
    );
  }

  @override
  Future<void> delete(String contactId) async {
    deleteCalls.add(contactId);
    if (deleteError != null) throw deleteError!;
  }
}
