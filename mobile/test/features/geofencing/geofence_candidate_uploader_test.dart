import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/geofencing/data/geofence_candidate_uploader.dart';
import 'package:mobile/features/geofencing/data/native_geofence_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({
    this.session,
    this.refreshResult = const AuthSessionResult(signedIn: true),
  });

  sb.Session? session;
  AuthSessionResult refreshResult;
  Object? refreshError;
  int refreshCalls = 0;

  @override
  Stream<dynamic> get authStateChanges => const Stream.empty();

  @override
  sb.Session? get currentSession => session;

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshResult;
  }

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> updateRoleMetadata(Role role) => throw UnimplementedError();
}

class _FakeNativePlatform implements NativeGeofencePlatform {
  _FakeNativePlatform(this.candidates);

  final List<NativeGeofenceCandidate> candidates;
  final List<String> acknowledgements = [];

  @override
  Future<void> acknowledgeCandidate(String eventId) async {
    acknowledgements.add(eventId);
  }

  @override
  Future<List<NativeGeofenceCandidate>> drainPendingCandidates() async =>
      candidates;

  @override
  Future<NativeGeofenceCapability> getCapability() async =>
      NativeGeofenceCapability.ready;

  @override
  Future<void> replaceMonitoredZones(List<NativeGeofenceZone> zones) async {}

  @override
  Future<NativeGeofenceCapability> requestBackgroundCapability() async =>
      NativeGeofenceCapability.ready;
}

NativeGeofenceCandidate _candidate({
  String eventId = '00000000-0000-0000-0000-000000000001',
}) => NativeGeofenceCandidate(
  eventId: eventId,
  requestId: '00000000-0000-0000-0000-000000000010:2',
  transition: NativeGeofenceTransition.enter,
  occurredAtUtc: DateTime.utc(2026, 8, 13, 10),
  latitude: 30.0444,
  longitude: 31.2357,
  accuracyMeters: 8,
);

void main() {
  test(
    'refreshes restored auth, uploads, then acknowledges accepted rows',
    () async {
      final auth = _FakeAuthApi(session: null);
      final native = _FakeNativePlatform([_candidate()]);
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _ReplyingAdapter(202, calls);

      final result = await GeofenceCandidateUploader(
        authApi: auth,
        dio: dio,
        nativePlatform: native,
      ).drain();

      expect(result.shouldRetry, isFalse);
      expect(auth.refreshCalls, 1);
      expect(calls.single.path, '/geofences/candidates');
      expect(calls.single.data['eventId'], _candidate().eventId);
      expect(native.acknowledgements, [_candidate().eventId]);
    },
  );

  test(
    'keeps every row for a missing or failed session and requests retry',
    () async {
      final auth = _FakeAuthApi(
        session: null,
        refreshResult: const AuthSessionResult(signedIn: false),
      );
      final native = _FakeNativePlatform([_candidate()]);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));

      final result = await GeofenceCandidateUploader(
        authApi: auth,
        dio: dio,
        nativePlatform: native,
      ).drain();

      expect(result.shouldRetry, isTrue);
      expect(native.acknowledgements, isEmpty);
    },
  );

  test(
    'acknowledges duplicate responses but retains rows after a network failure',
    () async {
      final auth = _FakeAuthApi(session: null);
      final first = _candidate();
      final second = _candidate(
        eventId: '00000000-0000-0000-0000-000000000002',
      );
      final native = _FakeNativePlatform([first, second]);
      var callCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequenceAdapter(() {
          callCount++;
          if (callCount == 1) return 200;
          throw DioException(
            requestOptions: RequestOptions(path: '/geofences/candidates'),
          );
        });

      final result = await GeofenceCandidateUploader(
        authApi: auth,
        dio: dio,
        nativePlatform: native,
      ).drain();

      expect(result.shouldRetry, isTrue);
      expect(native.acknowledgements, [first.eventId]);
    },
  );
}

class _ReplyingAdapter implements HttpClientAdapter {
  _ReplyingAdapter(this.statusCode, this.calls);

  final int statusCode;
  final List<RequestOptions> calls;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return ResponseBody.fromString('{"outcome":"accepted"}', statusCode);
  }
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this._next);

  final int Function() _next;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"outcome":"duplicate"}', _next());
}
