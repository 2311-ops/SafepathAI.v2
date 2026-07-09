import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/family/presentation/accept_invite_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _FakeFamilyApi fakeApi;
  late _FakeAuthApi fakeAuthApi;

  setUp(() {
    fakeApi = _FakeFamilyApi();
    fakeAuthApi = _FakeAuthApi();
  });

  tearDown(() => fakeAuthApi.dispose());

  Widget buildTestApp({String initialLocation = '/invite/accept'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/invite/accept',
          builder: (context, state) => AcceptInviteScreen(
            initialCode: state.uri.queryParameters['code'],
            initialLinkToken: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('home-reached')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        familyApiProvider.overrideWithValue(fakeApi),
        authApiProvider.overrideWithValue(fakeAuthApi),
      ],
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: router,
      ),
    );
  }

  testWidgets('accepting a link invite redeems by link token', (tester) async {
    fakeApi.redeemResultToReturn = const RedeemResult(
      familyId: 'fam-1',
      status: 'Accepted',
      accepted: true,
    );
    fakeApi.membersByFamilyId['fam-1'] = const [];

    await tester.pumpWidget(
      buildTestApp(initialLocation: '/invite/accept?token=opaque-token'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Invite link ready. Tap Accept & join to continue.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept & join'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastRedeemCode, isNull);
    expect(fakeApi.lastRedeemLinkToken, 'opaque-token');
    expect(fakeApi.lastRedeemAccept, isTrue);
    expect(find.text('home-reached'), findsOneWidget);
  });

  testWidgets('declining an invite is a non-joining outcome', (tester) async {
    fakeApi.redeemResultToReturn = const RedeemResult(
      familyId: 'fam-1',
      status: 'Declined',
      accepted: false,
    );

    await tester.pumpWidget(
      buildTestApp(initialLocation: '/invite/accept?code=SP-12345'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastRedeemCode, 'SP-12345');
    expect(fakeApi.lastRedeemAccept, isFalse);
    expect(fakeApi.listMembersCallCount, 0);
  });

  testWidgets('empty manual code without token does not redeem', (
    tester,
  ) async {
    fakeApi.redeemResultToReturn = const RedeemResult(
      familyId: 'fam-1',
      status: 'Accepted',
      accepted: true,
    );

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept & join'));
    await tester.pumpAndSettle();

    expect(fakeApi.redeemCallCount, 0);
  });
}

class _FakeFamilyApi implements FamilyApi {
  RedeemResult? redeemResultToReturn;
  Map<String, List<FamilyMemberView>> membersByFamilyId = {};
  int redeemCallCount = 0;
  int listMembersCallCount = 0;
  String? lastRedeemCode;
  String? lastRedeemLinkToken;
  bool? lastRedeemAccept;

  @override
  Future<List<MyFamily>> getMyFamilies() async => const [];

  @override
  Future<Family> createFamily(String name) async =>
      Family(id: 'fam-1', name: name);

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async {
    listMembersCallCount++;
    return membersByFamilyId[familyId] ?? const [];
  }

  @override
  Future<Invitation> generateInvite(
    String familyId, {
    String? inviteeLabel,
  }) async => throw UnimplementedError();

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async {
    redeemCallCount++;
    lastRedeemCode = code;
    lastRedeemLinkToken = linkToken;
    lastRedeemAccept = accept;
    return redeemResultToReturn!;
  }

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async => level;

  @override
  Future<void> removeMember(String familyId, String memberId) async {}
}

class _FakeAuthApi implements AuthApi {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => null;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  void dispose() => _controller.close();

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() => throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
}
