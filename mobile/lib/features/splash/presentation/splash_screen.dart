import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/animated_safepath_mark.dart';
import '../application/splash_providers.dart';

/// Cold-launch splash screen. Shown exactly once, as `routerProvider`'s
/// `initialLocation`, then handed off via the existing redirect system —
/// see `01.1-UI-SPEC.md` Integration & Navigation Contract and the router's
/// `/splash` redirect gate.
///
/// The logo lockup (mark + traced ring + staggered wordmark, one unit,
/// rendered via the shared `AnimatedSafePathMark`) fades in, scales up from
/// 92% and rises 8px->0px on a single 1800ms `AnimationController`
/// (Curves.easeOutQuart, 0-55% of the controller). Under reduced motion the
/// same controller instead runs an opacity-only 220ms fade
/// (Curves.easeOutCubic) and the shared widget renders its resting frame —
/// no ring, no sheen, no per-letter stagger. Either way, on
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
  static const _defaultDuration = Duration(milliseconds: 1800);
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
    _controller = AnimationController(
      vsync: this,
      duration: _defaultDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
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
    return AnimatedSafePathMark(
      progress: _controller,
      reduceMotion: _reduceMotion,
      wordmarkStyle: AppTypography.display.copyWith(color: Colors.white),
    );
  }
}

/// App-level cold-start overlay that guarantees the SafePath launch motion is
/// visible after Flutter's first frame, independent of platform initial-route
/// quirks. The router can resolve underneath while this overlay plays once.
class StartupSplashOverlay extends StatefulWidget {
  const StartupSplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplashOverlay> createState() => _StartupSplashOverlayState();
}

class _StartupSplashOverlayState extends State<StartupSplashOverlay> {
  static const _defaultDuration = Duration(milliseconds: 1800);
  static const _reducedMotionDuration = Duration(milliseconds: 260);
  static const _postFrameStartDelay = Duration(milliseconds: 120);
  static const _frameInterval = Duration(milliseconds: 16);

  bool _visible = true;
  bool _startScheduled = false;
  bool _reduceMotion = false;
  double _progress = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _startTimer;
  Timer? _frameTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_startScheduled) return;
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimer = Timer(_postFrameStartDelay, () {
        if (!mounted || !_visible || _stopwatch.isRunning) return;
        _startClock();
      });
    });
  }

  void _startClock() {
    _stopwatch.start();
    _frameTimer = Timer.periodic(_frameInterval, (_) {
      final duration = _reduceMotion
          ? _reducedMotionDuration
          : _defaultDuration;
      final nextProgress =
          (_stopwatch.elapsedMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

      if (!mounted) return;
      if (nextProgress >= 1.0) {
        _frameTimer?.cancel();
        setState(() {
          _progress = 1.0;
          _visible = false;
        });
        return;
      }

      setState(() => _progress = nextProgress);
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;

    final lockupProgress = _reduceMotion
        ? 1.0
        : _intervalProgress(begin: 0.0, end: 0.32, curve: Curves.easeOutQuart);

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Semantics(
              label: 'SafePath AI is opening',
              child: Opacity(
                opacity: _overlayOpacity,
                child: _StartupSplashSurface(
                  progress: AlwaysStoppedAnimation<double>(_progress),
                  lockupOpacity: AlwaysStoppedAnimation<double>(lockupProgress),
                  scale: AlwaysStoppedAnimation<double>(
                    _reduceMotion ? 1.0 : 0.92 + (0.08 * lockupProgress),
                  ),
                  rise: AlwaysStoppedAnimation<double>(
                    _reduceMotion ? 0.0 : 8 * (1 - lockupProgress),
                  ),
                  reduceMotion: _reduceMotion,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double get _overlayOpacity {
    if (_progress <= 0.86) return 1.0;
    final fadeProgress = ((_progress - 0.86) / 0.14).clamp(0.0, 1.0);
    return 1.0 - Curves.easeOutCubic.transform(fadeProgress);
  }

  double _intervalProgress({
    required double begin,
    required double end,
    required Curve curve,
  }) {
    final raw = ((_progress - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }
}

class _StartupSplashSurface extends StatelessWidget {
  const _StartupSplashSurface({
    required this.progress,
    required this.lockupOpacity,
    required this.scale,
    required this.rise,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final Animation<double> lockupOpacity;
  final Animation<double> scale;
  final Animation<double> rise;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
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
                opacity: lockupOpacity,
                child: ScaleTransition(
                  scale: scale,
                  child: AnimatedBuilder(
                    animation: rise,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, rise.value),
                      child: child,
                    ),
                    child: AnimatedSafePathMark(
                      progress: progress,
                      reduceMotion: reduceMotion,
                      wordmarkStyle: AppTypography.display.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
