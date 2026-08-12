import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import 'geofence_candidate_uploader.dart';

const _backgroundChannel = MethodChannel('safepath/geofence-background');

/// Android WorkManager launches this in a headless Flutter engine.
@pragma('vm:entry-point')
Future<void> geofenceBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var shouldRetry = true;
  try {
    ensureSupabaseConfigured();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    shouldRetry =
        (await drainGeofenceCandidatesAfterAuthRestoration()).shouldRetry;
  } catch (_) {
    shouldRetry = true;
  }

  try {
    await _backgroundChannel.invokeMethod<void>('complete', {
      'retry': shouldRetry,
    });
  } on PlatformException {
    // The native worker times out and retries if process teardown wins this race.
  }
}
