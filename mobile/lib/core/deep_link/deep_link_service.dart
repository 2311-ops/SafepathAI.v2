import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PendingInviteLink {
  const PendingInviteLink({this.token, this.code});

  final String? token;
  final String? code;

  String get location {
    final params = <String, String>{};
    if (token?.isNotEmpty ?? false) params['token'] = token!;
    if (code?.isNotEmpty ?? false) params['code'] = code!;
    final query = Uri(queryParameters: params).query;
    return query.isEmpty ? '/invite/accept' : '/invite/accept?$query';
  }
}

class PendingInviteNotifier extends Notifier<PendingInviteLink?> {
  @override
  PendingInviteLink? build() => null;

  void set(PendingInviteLink? link) => state = link;
}

class ResetLinkExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool expired) => state = expired;
}

final pendingInviteProvider =
    NotifierProvider<PendingInviteNotifier, PendingInviteLink?>(
      PendingInviteNotifier.new,
    );
final resetLinkExpiredProvider =
    NotifierProvider<ResetLinkExpiredNotifier, bool>(
      ResetLinkExpiredNotifier.new,
    );

final deepLinkServiceProvider = Provider<DeepLinkService>(
  (ref) => DeepLinkService(ref),
);

class DeepLinkService {
  DeepLinkService(this._ref, {AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final Ref _ref;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  Future<void> start(GoRouter router) async {
    Uri? initial;
    try {
      initial = await _appLinks.getInitialLink();
    } catch (_) {
      initial = null;
    }

    if (initial != null) {
      _handle(initial, router);
    }

    try {
      _subscription ??= _appLinks.uriLinkStream.listen(
        (uri) => _handle(uri, router),
        onError: (_) {},
      );
    } catch (_) {
      // App links are unavailable in some widget-test hosts.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handle(Uri uri, GoRouter router) {
    if (uri.scheme != 'safepathai') return;

    if (uri.host == 'invite') {
      final token = _emptyToNull(uri.queryParameters['token']);
      final code = _emptyToNull(uri.queryParameters['code']);
      if (token == null && code == null) return;

      router.go(PendingInviteLink(token: token, code: code).location);
      return;
    }

    if (uri.host == 'reset-password' && _isExpiredResetLink(uri)) {
      _ref.read(resetLinkExpiredProvider.notifier).set(true);
      router.go('/forgot-password');
    }
  }

  bool _isExpiredResetLink(Uri uri) {
    final values = {...uri.queryParameters, ..._parseFragment(uri.fragment)};
    return values['error_code'] == 'otp_expired' ||
        values['error'] == 'access_denied';
  }

  Map<String, String> _parseFragment(String fragment) {
    if (fragment.isEmpty) return const {};
    final normalized = fragment.startsWith('?')
        ? fragment.substring(1)
        : fragment;
    return Uri.splitQueryString(normalized);
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
