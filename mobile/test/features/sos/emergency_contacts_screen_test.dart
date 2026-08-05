// Behavior under test (03-07-PLAN.md Task 2):
// - lists the user's contacts
// - shows an empty state that explains why contacts matter
// - adds a contact
// - surfaces the server's rejection of an invalid number
// - edits a contact
// - removes a contact behind a confirmation
// - keeps the existing list visible when a mutation fails
// - uses no SOS red (this screen is an ordinary settings surface)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/sos/data/emergency_contact_api.dart';
import 'package:mobile/features/sos/presentation/emergency_contacts_screen.dart';

import '../../helpers/fake_emergency_contact_api.dart';

Widget _wrap(FakeEmergencyContactApi api) {
  return ProviderScope(
    overrides: [emergencyContactApiProvider.overrideWithValue(api)],
    child: const MaterialApp(home: EmergencyContactsScreen()),
  );
}

/// The add form sits below the list on this screen; a tall test surface
/// keeps every control (including "Add contact") within the hit-testable
/// viewport without needing manual scroll gymnastics per test.
Future<void> _pumpScreen(WidgetTester tester, FakeEmergencyContactApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(api));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("lists the user's contacts", (tester) async {
    final api = FakeEmergencyContactApi()
      ..contactsToList = const [
        EmergencyContact(
          id: 'contact-1',
          displayName: 'Grandma',
          phoneNumberE164: '+15551234567',
          isActive: true,
        ),
        EmergencyContact(
          id: 'contact-2',
          displayName: 'Uncle Theo',
          phoneNumberE164: '+15557654321',
          isActive: true,
        ),
      ];

    await _pumpScreen(tester, api);

    expect(find.text('Grandma'), findsOneWidget);
    expect(find.text('Uncle Theo'), findsOneWidget);
  });

  testWidgets('shows an empty state that explains why contacts matter', (
    tester,
  ) async {
    final api = FakeEmergencyContactApi();

    await _pumpScreen(tester, api);

    expect(find.text('No emergency contacts yet.'), findsOneWidget);
    expect(
      find.textContaining('SOS has nowhere to send help'),
      findsOneWidget,
    );
  });

  testWidgets('adds a contact', (tester) async {
    final api = FakeEmergencyContactApi();

    await _pumpScreen(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), 'Grandma');
    await tester.enterText(find.byType(TextFormField).at(1), '+15551234567');
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();

    expect(api.addCalls, hasLength(1));
    expect(api.addCalls.single.name, 'Grandma');
    expect(api.addCalls.single.phoneNumber, '+15551234567');
  });

  testWidgets('adds a local number with the selected country code', (
    tester,
  ) async {
    final api = FakeEmergencyContactApi();

    await _pumpScreen(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), 'Mona');
    await tester.tap(find.byKey(const ValueKey('country-code-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Egypt (+20)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '01113133589');
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();

    expect(api.addCalls, hasLength(1));
    expect(api.addCalls.single.name, 'Mona');
    expect(api.addCalls.single.phoneNumber, '+201113133589');
    expect(api.addCalls.single.region, 'EG');
  });

  testWidgets("surfaces the server's rejection of an invalid number", (
    tester,
  ) async {
    final api = FakeEmergencyContactApi()
      ..addError = EmergencyContactApiException(
        EmergencyContactApiIssue.validation,
        message: 'That number could not be parsed.',
      );

    await _pumpScreen(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), 'Grandma');
    await tester.enterText(find.byType(TextFormField).at(1), '+1555000000');
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();

    expect(find.text('That number could not be parsed.'), findsOneWidget);
    // No contact was added: the empty state (there were zero contacts to
    // begin with) still renders.
    expect(find.text('No emergency contacts yet.'), findsOneWidget);
  });

  testWidgets('edits a contact', (tester) async {
    final api = FakeEmergencyContactApi()
      ..contactsToList = const [
        EmergencyContact(
          id: 'contact-1',
          displayName: 'Grandma',
          phoneNumberE164: '+15551234567',
          isActive: true,
        ),
      ];

    await _pumpScreen(tester, api);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Grandma Rose');
    await tester.enterText(dialogFields.at(1), '+15559998888');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.updateCalls, hasLength(1));
    expect(api.updateCalls.single.contactId, 'contact-1');
    expect(api.updateCalls.single.name, 'Grandma Rose');
    expect(api.updateCalls.single.phoneNumber, '+15559998888');
  });

  testWidgets('removes a contact behind a confirmation', (tester) async {
    final api = FakeEmergencyContactApi()
      ..contactsToList = const [
        EmergencyContact(
          id: 'contact-1',
          displayName: 'Grandma',
          phoneNumberE164: '+15551234567',
          isActive: true,
        ),
      ];

    await _pumpScreen(tester, api);

    // Dismissing the confirmation records no delete call.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, isEmpty);

    // Confirming records exactly one delete call.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(api.deleteCalls, ['contact-1']);
  });

  testWidgets('keeps the existing list visible when a mutation fails', (
    tester,
  ) async {
    final api = FakeEmergencyContactApi()
      ..contactsToList = const [
        EmergencyContact(
          id: 'contact-1',
          displayName: 'Grandma',
          phoneNumberE164: '+15551234567',
          isActive: true,
        ),
        EmergencyContact(
          id: 'contact-2',
          displayName: 'Uncle Theo',
          phoneNumberE164: '+15557654321',
          isActive: true,
        ),
      ]
      ..addError = EmergencyContactApiException(
        EmergencyContactApiIssue.validation,
        message: 'That number could not be parsed.',
      );

    await _pumpScreen(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), 'New Contact');
    await tester.enterText(find.byType(TextFormField).at(1), '+1555000000');
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();

    expect(find.text('Grandma'), findsOneWidget);
    expect(find.text('Uncle Theo'), findsOneWidget);
  });

  testWidgets('uses no SOS red', (tester) async {
    final api = FakeEmergencyContactApi()
      ..contactsToList = const [
        EmergencyContact(
          id: 'contact-1',
          displayName: 'Grandma',
          phoneNumberE164: '+15551234567',
          isActive: true,
        ),
      ];

    await _pumpScreen(tester, api);

    for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.color, isNot(AppColors.sosRed));
      expect(icon.color, isNot(AppColors.sosRedDeep));
    }
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(AppColors.sosRed));
      expect(text.style?.color, isNot(AppColors.sosRedDeep));
    }
    for (final container in tester.widgetList<Container>(
      find.byType(Container),
    )) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration) {
        expect(decoration.color, isNot(AppColors.sosRed));
        expect(decoration.color, isNot(AppColors.sosRedDeep));
      }
    }
  });
}
