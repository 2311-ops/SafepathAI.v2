import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/shared_widgets/member_map_pin.dart';
import 'package:mobile/shared_widgets/profile_avatar.dart';

/// Deterministic rendering + cache-key tests for the two avatar surfaces
/// (map pin + profile/header avatar). No real network: we assert on the
/// presence/props of the CachedNetworkImage widget and its cache key, which is
/// the load-bearing contract for cold-start persistence and cache-busting
/// (bug: avatar-persist-after-refresh). Actual byte loading is a package
/// concern already exercised by cached_network_image itself.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('MemberMapPin', () {
    testWidgets('renders a CachedNetworkImage with a stable cache key when a '
        'URL is present', (tester) async {
      await tester.pumpWidget(
        wrap(
          MemberMapPin(
            label: 'Sam',
            userId: 'member-2',
            profileImageUrl: 'https://example.com/member-2.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.com/member-2.jpg');
      expect(image.cacheKey, 'member-2-2026-07-12T08:00:00.000Z');
    });

    testWidgets('renders the initials fallback when the URL is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MemberMapPin(label: 'Sam', userId: 'member-2')),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('changing profileUpdatedAt busts the cache key (replaced photo '
        'under the same URL host)', (tester) async {
      await tester.pumpWidget(
        wrap(
          MemberMapPin(
            label: 'Sam',
            userId: 'member-2',
            profileImageUrl: 'https://example.com/member-2.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
          ),
        ),
      );
      await tester.pump();
      final firstKey = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      await tester.pumpWidget(
        wrap(
          MemberMapPin(
            label: 'Sam',
            userId: 'member-2',
            profileImageUrl: 'https://example.com/member-2.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
          ),
        ),
      );
      await tester.pump();
      final secondKey = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      expect(firstKey, isNot(secondKey));
    });

    testWidgets('rebuilds with the new image URL when the URL changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MemberMapPin(
            label: 'Sam',
            userId: 'member-2',
            profileImageUrl: 'https://example.com/old.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrap(
          MemberMapPin(
            label: 'Sam',
            userId: 'member-2',
            profileImageUrl: 'https://example.com/new.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 8),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.com/new.jpg');
    });
  });

  group('ProfileAvatar', () {
    testWidgets('renders a CachedNetworkImage with the userId+timestamp cache '
        'key when a URL is present', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProfileAvatar(
            userId: 'self-user',
            label: 'Ada',
            profileImageUrl: 'https://example.com/self.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.com/self.jpg');
      expect(image.cacheKey, 'self-user-2026-07-12T09:00:00.000Z');
    });

    testWidgets('renders the initials fallback when the URL is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const ProfileAvatar(userId: 'self-user', label: 'Ada')),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a cold-start restored URL still renders the network avatar', (
      tester,
    ) async {
      // Simulates the state a fresh app boot lands in: a persisted URL +
      // timestamp threaded from GET /live-locations / GET /me.
      await tester.pumpWidget(
        wrap(
          ProfileAvatar(
            userId: 'self-user',
            label: 'Ada',
            profileImageUrl: 'https://example.com/restored.jpg',
            profileUpdatedAt: DateTime.utc(2026, 7, 12, 9),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });
  });
}
