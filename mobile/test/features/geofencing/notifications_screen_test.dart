import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/application/routine_notifications_controller.dart';
import 'package:mobile/features/geofencing/presentation/notifications_screen.dart';

void main() {
  final item = RoutineNotification(
    id: 'feed-1',
    activityId: 'activity-1',
    memberUserId: 'member-1',
    memberName: 'Maya',
    zoneName: 'Home',
    transition: RoutineNotificationTransition.entered,
    occurredAtUtc: DateTime.utc(2026, 8, 14, 16, 5),
  );

  testWidgets('shows durable unread routine rows and opens activity', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var openedActivityId = '';
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          state: RoutineNotificationsState(items: [item]),
          onOpen: (notification) => openedActivityId = notification.activityId,
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Maya entered Home'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open activity for Maya entered Home'),
      findsOneWidget,
    );

    await tester.tap(find.text('Maya entered Home'));
    expect(openedActivityId, 'activity-1');
    semantics.dispose();
  });

  testWidgets('shows the feed empty state and settings action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationsScreen.empty()),
    );

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('New safe-zone alerts will appear here.'), findsOneWidget);
    expect(find.bySemanticsLabel('Notification settings'), findsOneWidget);
  });
}
