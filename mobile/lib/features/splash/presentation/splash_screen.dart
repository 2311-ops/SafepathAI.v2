import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_logo.dart';
import '../application/splash_providers.dart';

/// Cold-launch splash screen. Shown exactly once, as `routerProvider`'s
/// `initialLocation`, then handed off via the existing redirect system —
/// see `01.1-UI-SPEC.md` Integration & Navigation Contract and the router's
/// `/splash` redirect gate.
///
/// Baseline motion only: the logo lockup (mark + wordmark, one unit) fades
/// in, scales up from 92% and rises 8px->0px on a single 1400ms
/// `AnimationController` (Curves.easeOutQuart, 0-55% of the controller).
/// Under reduced motion the same controller instead runs an opacity-only
/// 220ms fade (Curves.easeOutCubic). Either way, on
/// `AnimationStatus.completed` the widget flips
/// [splashAnimationCompleteProvider] exactly once, which is the only signal
/// that moves the app off `/splash`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _defaultDuration = Duration(milliseconds: 1400);
  static const _reducedMotionDuration = Duration(milliseconds: 220);

  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<double> _rise;

  bool _started = false;
  bool _reduceMotion = false;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _defaultDuration);
    _opacity = const AlwaysStoppedAnimation<double>(0.0);
    _scale = const AlwaysStoppedAnimation<double>(0.92);
    _rise = const AlwaysStoppedAnimation<double>(8.0);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _reduceMotion = MediaQuery.of(context).disableAnimations;

    if (_reduceMotion) {
      _controller.duration = _reducedMotionDuration;
      _opacity = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      );
      _scale = const AlwaysStoppedAnimation<double>(1.0);
      _rise = const AlwaysStoppedAnimation<double>(0.0);
    } else {
      final entryCurve = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutQuart),
      );
      _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(entryCurve);
      _scale = Tween<double>(begin: 0.92, end: 1.0).animate(entryCurve);
      _rise = Tween<double>(begin: 8.0, end: 0.0).animate(entryCurve);
    }

    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_flipped || !mounted) return;
    _flipped = true;
    ref.read(splashAnimationCompleteProvider.notifier).set(true);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.heroGradientStart, AppColors.deepTeal],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: AnimatedBuilder(
                    animation: _rise,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _rise.value),
                      child: child,
                    ),
                    child: _buildLockup(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcludeSemantics(
          child: SafePathLogo(size: 96, tile: false),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'SafePath AI',
          textAlign: TextAlign.center,
          style: AppTypography.display.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
