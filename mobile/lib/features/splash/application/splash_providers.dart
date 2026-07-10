import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier backing [splashAnimationCompleteProvider]. Follows the same
/// `Notifier`/`set()` convention as `PendingInviteNotifier` /
/// `ResetLinkExpiredNotifier` (`deep_link_service.dart`) — this Riverpod
/// setup has no legacy `StateProvider`.
class SplashAnimationCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool complete) => state = complete;
}

/// Flips exactly once, from `false` to `true`, when the cold-launch splash
/// animation (see `splash_screen.dart`) reaches
/// `AnimationStatus.completed` (or immediately under reduced motion).
///
/// `routerProvider`'s `_AuthRefreshListenable` listens to this provider so
/// flipping it re-runs the redirect callback and moves the app off
/// `/splash` — see `01.1-UI-SPEC.md` Integration & Navigation Contract.
final splashAnimationCompleteProvider =
    NotifierProvider<SplashAnimationCompleteNotifier, bool>(
      SplashAnimationCompleteNotifier.new,
    );
