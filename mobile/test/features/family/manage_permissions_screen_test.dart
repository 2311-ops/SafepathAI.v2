import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/family/presentation/manage_permissions_screen.dart';

import '../../helpers/fake_auth_api.dart';

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'fam-1', name: 'Safe circle'),
    members: [
      FamilyMemberView(
        memberId: 'mem-self',
        userId: 'self-user',
        displayName: 'Alex Guardian',
        role: Role.guardian,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 8, 14),
      ),
      FamilyMemberView(
        memberId: 'mem-child',
        userId: 'child-user',
        displayName: 'Maya',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 8, 14),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('member privacy is display-only for guardians', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(
            FakeAuthApi(initialSession: _session(userId: 'self-user')),
          ),
          familyControllerProvider.overrideWith(_SeededFamilyController.new),
        ],
        child: const MaterialApp(home: ManagePermissionsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Circle members'), findsWidgets);
    expect(find.text('Privacy controlled by member'), findsOneWidget);
    expect(
      find.text(
        'They choose who can see live location, history, and wellness from their own Privacy Center.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Remove from circle'), findsOneWidget);
    expect(find.text('Full location'), findsNothing);
    expect(find.text('View only'), findsNothing);
    expect(find.text('Notification only'), findsNothing);
  });
}

sb.Session _session({required String userId}) {
  return sb.Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: sb.User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}
