import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/emergency_contact_api.dart';

/// State held by [EmergencyContactsController]: the caller's own emergency
/// contacts, plus [error] — a UI-facing message from the last failed
/// mutation. Set without touching [contacts], so a failed add/edit/remove
/// never blanks the user's already-loaded list (mirrors
/// `FamilyController`'s `FamilyState.error` convention).
class EmergencyContactsState {
  const EmergencyContactsState({this.contacts = const [], this.error});

  final List<EmergencyContact> contacts;
  final String? error;

  EmergencyContactsState copyWith({
    List<EmergencyContact>? contacts,
    String? error,
    bool clearError = false,
  }) {
    return EmergencyContactsState(
      contacts: contacts ?? this.contacts,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the emergency-contact list backing plan 03-07's offline fallback
/// ("call {emergency contact}") and the management screen (D-30). Loads on
/// [build] and applies every mutation's server response directly to the
/// in-memory list rather than re-fetching, matching `FamilyController`'s
/// add/update/remove conventions.
class EmergencyContactsController extends AsyncNotifier<EmergencyContactsState> {
  @override
  Future<EmergencyContactsState> build() async {
    final contacts = await ref.read(emergencyContactApiProvider).list();
    return EmergencyContactsState(contacts: contacts);
  }

  EmergencyContactsState get _current =>
      state.value ?? const EmergencyContactsState();

  /// Re-fetches the caller's contacts (e.g. pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final contacts = await ref.read(emergencyContactApiProvider).list();
      return EmergencyContactsState(contacts: contacts);
    });
  }

  Future<void> add(String name, String phoneNumber, {String? region}) async {
    final current = _current;
    try {
      final contact = await ref
          .read(emergencyContactApiProvider)
          .add(name, phoneNumber, region);
      state = AsyncData(
        current.copyWith(
          contacts: [...current.contacts, contact],
          clearError: true,
        ),
      );
    } on EmergencyContactApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }

  /// Named `updateContact` (not `update`) to avoid colliding with
  /// `AsyncNotifier`'s own built-in `update()` state-mutation helper.
  Future<void> updateContact(
    String contactId,
    String name,
    String phoneNumber, {
    String? region,
  }) async {
    final current = _current;
    try {
      final updated = await ref
          .read(emergencyContactApiProvider)
          .update(contactId, name, phoneNumber, region);
      final contacts = [
        for (final contact in current.contacts)
          if (contact.id == contactId) updated else contact,
      ];
      state = AsyncData(current.copyWith(contacts: contacts, clearError: true));
    } on EmergencyContactApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }

  Future<void> remove(String contactId) async {
    final current = _current;
    try {
      await ref.read(emergencyContactApiProvider).delete(contactId);
      final contacts = current.contacts
          .where((contact) => contact.id != contactId)
          .toList();
      state = AsyncData(current.copyWith(contacts: contacts, clearError: true));
    } on EmergencyContactApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }
}

final emergencyContactsControllerProvider =
    AsyncNotifierProvider<EmergencyContactsController, EmergencyContactsState>(
      EmergencyContactsController.new,
    );
