import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/os_shortcuts/quick_actions_service.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureSupabaseConfigured();

  try {
    await Firebase.initializeApp();
    // Required by firebase_messaging for background-isolate execution of a
    // data message that arrives while the app process is fully terminated.
    FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
  } catch (error) {
    // No Firebase project provisioned yet (no google-services.json /
    // GoogleService-Info.plist) — the rest of the app must still build, run
    // and demo (D-07 parity with the backend's zero-cost LoggingPushSender
    // default). The FCM channel simply stays inactive until Task 3's human
    // Firebase setup is done; PushServiceController below also guards its
    // own calls so this never crashes app startup.
    debugPrint('Firebase.initializeApp failed (no Firebase project configured yet?): $error');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  final container = ProviderContainer();
  // Bootstraps the FCM token lifecycle (register on sign-in, remove on
  // sign-out, re-register on rotation) and all three notification-tap
  // lifecycles alongside the existing DeepLinkService.start(router) call in
  // app.dart's initState. Reading the provider here (rather than a second
  // ProviderScope) triggers PushServiceController.build() exactly once,
  // before the widget tree exists — mirrors DeepLinkService's own
  // startup-time wiring.
  container.read(pushServiceControllerProvider);
  // Registers the home-screen "Emergency SOS" quick-action shortcut and its
  // invocation handler (SOS-06) alongside the push/deep-link bootstrap
  // above — same startup-time-wiring convention, one shared ProviderContainer.
  container.read(quickActionsServiceProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const SafePathApp()),
  );
}
