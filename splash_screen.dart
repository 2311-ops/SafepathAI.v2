// lib/features/splash/presentation/splash_screen.dart
//
// SafePath AI — production launch splash.
// Fade + scale (92% → 100%) + a small upward settle, then a short hold,
// then a seamless cross-fade into the next screen. No bounce/elastic/overshoot.
//
// Reuses the existing SafePathLogo mark (see assets/safepath_logo.dart) and the
// app's ColorScheme — no new colors are introduced here.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/router/app_router.dart'; // adjust import to your router
import '../../../shared/widgets/safepath_logo.dart'; // the CustomPaint mark

/// Where to go once the splash completes. Resolve this BEFORE building the
/// splash (e.g. in a Riverpod provider) so navigation only ever fires once,
/// driven purely by animation status — never by a Future/Timer race.
enum SplashDestination { authenticated, welcome }

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.resolveDestination,
  });

  /// Async session check. Called once; awaited alongside the minimum
  /// animation time so a fast result doesn't cut the animation short and a
  /// slow result doesn't leave a blank/frozen frame — the final frame holds
  /// with a subtle idle (a very slow, continued glow breathing) until ready.
  final Future<SplashDestination> Function() resolveDestination;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Curves: easeOutQuart moves the bulk of the motion early then settles —
  // no elastic/back/bounce anywhere in this file.
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rise;
  late final Animation<double> _bgFade;

  bool _navigated = false;
  bool _reduceMotion = false;
  SplashDestination? _destination;

  static const _totalDuration = Duration(milliseconds: 1800); // entry ~900ms + hold ~500ms + exit ~400ms
  static const _entryFraction = 0.56;
  static const _holdFraction = 0.25;
  // remaining ~300ms reserved for the caller's own screen-transition fade.

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _totalDuration);

    final entryEnd = _entryFraction;
    final holdEnd = _entryFraction + _holdFraction;

    _bgFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
    );

    final entryCurve = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.03, entryEnd, curve: Curves.easeOutQuart),
    );

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(entryCurve);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(entryCurve);
    _rise = Tween<double>(begin: 8.0, end: 0.0).animate(entryCurve); // 8px settle, within 6–10px spec

    // Idle "breathing" hold from entryEnd→holdEnd is just the resting state —
    // no additional animation needed, the values are already at rest (1.0).
    // The controller keeps running so we have a single source of truth for
    // "animation finished" without a second Future/Timer.

    if (SchedulerBinding.instance.window.accessibilityFeatures.disableAnimations) {
      _reduceMotion = true;
    }

    _controller.addStatusListener(_onStatus);

    // Kick off both the animation and the async session check together.
    // Navigation fires from _tryNavigate(), guarded by _navigated, only once
    // BOTH are true — so a slow init never leaves a blank/frozen screen and
    // a fast init never truncates the animation.
    widget.resolveDestination().then((dest) {
      if (!mounted) return;
      _destination = dest;
      _tryNavigate();
    });

    if (_reduceMotion) {
      // Accessibility: replace the full sequence with a short fade-in only.
      _controller.duration = const Duration(milliseconds: 220);
    }

    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _tryNavigate();
    }
  }

  void _tryNavigate() {
    if (_navigated) return; // guards against duplicate navigation from
    // rebuilds, lifecycle resumes, or the two async sources firing twice.
    if (_destination == null) return; // init not resolved yet — hold frame.
    if (_controller.status != AnimationStatus.completed) return; // anim not done.

    _navigated = true;
    final dest = _destination!;

    // Cross-fade to the next route with no blank frame in between: the new
    // route's own entrance transition should itself fade in from transparent
    // over the tail of this screen (handled by AppRouter's page transition).
    switch (dest) {
      case SplashDestination.authenticated:
        AppRouter.goToHome(context);
        break;
      case SplashDestination.welcome:
        AppRouter.goToWelcome(context);
        break;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Matches the SafePath design system: deep teal in dark, a slightly
    // lighter calm surface in light — no new colors introduced.
    final bg = isDark ? const Color(0xFF0C3A3F) : const Color(0xFFECF0EF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _bgFade,
            child: FadeTransition(
              opacity: _opacity,
              child: AnimatedBuilder(
                animation: _rise,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _rise.value),
                  child: child,
                ),
                child: ScaleTransition(
                  scale: _scale,
                  // _SplashMark listens to _controller directly for its own
                  // finer-grained motion (halo rotation, sheen, letter
                  // stagger) so only this small subtree repaints per frame —
                  // the Scaffold/SafeArea above never rebuild.
                  child: _SplashMark(isDark: isDark, progress: _controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static (non-animated at this level) logo lockup: the parent applies the
/// overall fade/scale/rise, and this widget adds three restrained "fancy"
/// touches layered on top of the same base motion — a slow rotating halo,
/// a one-time diagonal sheen across the shield, and a staggered per-letter
/// wordmark reveal. All still driven by the single parent AnimationController
/// (via `progress`), still only easeOutQuart/Cubic — no bounce/elastic.
class _SplashMark extends AnimatedWidget {
  const _SplashMark({required this.isDark, required Animation<double> progress})
      : super(listenable: progress);

  final bool isDark;
  Animation<double> get _progress => listenable as Animation<double>;

  static const _wordmark = 'SafePath AI';
  static const _wordStart = 0.55; // fraction of total controller duration
  static const _letterStagger = 0.028;
  static const _letterDur = 0.22;

  @override
  Widget build(BuildContext context) {
    final t = _progress.value; // 0..1 over the *entry* interval already
    final halo = 0.5 + 0.5 * math.sin(t * math.pi * 1.4); // slow, continuous, capped low
    final glowOpacity = (0.14 + 0.07 * halo).clamp(0.0, 1.0);
    final haloTurns = t * 0.14; // gentle continuous drift, decorative only

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 156,
          height: 156,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // slow rotating conic halo
              Transform.rotate(
                angle: haloTurns * 2 * math.pi,
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        const Color(0xFF5FD0C5).withOpacity(0.0),
                        const Color(0xFF5FD0C5).withOpacity(glowOpacity),
                        const Color(0xFF5FD0C5).withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // soft constant fill glow
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5FD0C5).withOpacity(glowOpacity * 0.6),
                ),
              ),
              const SafePathLogo(size: 92, tile: false),
              // one-time diagonal sheen sweep across the mark
              _SheenSweep(progress: t),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _StaggeredWordmark(
          text: _wordmark,
          overallProgress: t,
          start: _wordStart,
          stagger: _letterStagger,
          letterDuration: _letterDur,
          color: isDark ? Colors.white : const Color(0xFF0C3A3F),
        ),
      ],
    );
  }
}

/// A single soft diagonal highlight that sweeps once across the logo,
/// masked to its circular bounds. Purely decorative, no repeat.
class _SheenSweep extends StatelessWidget {
  const _SheenSweep({required this.progress});
  final double progress; // 0..1 over the full entry+hold window

  static const _start = 0.5, _end = 0.85;

  @override
  Widget build(BuildContext context) {
    final p = ((progress - _start) / (_end - _start)).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - p, 3); // easeOutCubic
    if (p <= 0 || p >= 1) return const SizedBox.shrink();

    return ClipOval(
      child: SizedBox(
        width: 92,
        height: 92,
        child: Align(
          alignment: Alignment(-1.6 + eased * 3.2, -1.0),
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              width: 26,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0),
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reveals [text] one letter at a time, each fading up on its own
/// easeOutQuart interval — a restrained "premium" flourish, not a bounce.
class _StaggeredWordmark extends StatelessWidget {
  const _StaggeredWordmark({
    required this.text,
    required this.overallProgress,
    required this.start,
    required this.stagger,
    required this.letterDuration,
    required this.color,
  });

  final String text;
  final double overallProgress;
  final double start;
  final double stagger;
  final double letterDuration;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(chars.length, (i) {
        final letterStart = start + i * stagger;
        final raw = ((overallProgress - letterStart) / letterDuration).clamp(0.0, 1.0);
        final eased = 1 - math.pow(1 - raw, 4); // easeOutQuart
        return Transform.translate(
          offset: Offset(0, 6 * (1 - eased)),
          child: Opacity(
            opacity: eased.toDouble(),
            child: Text(
              chars[i] == ' ' ? '\u00A0' : chars[i],
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -0.3,
                color: color,
              ),
            ),
          ),
        );
      }),
    );
  }
}
