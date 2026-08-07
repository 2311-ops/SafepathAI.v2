// mobile/lib/shared_widgets/animated_safepath_mark.dart
//
// Shared, single-source-of-truth animated logo mark for SafePath AI's launch
// motion. Used by BOTH `SplashScreen` (the routed `/splash` page) and
// `StartupSplashOverlay` (the cold-start overlay in app.dart) so the two
// surfaces can never visually drift from each other again — previously each
// had its own copy of the glow/sheen logic and only the overlay had a working
// halo, and neither had the ring-trace or per-letter wordmark reveal from the
// hi-fi mockup (00 · App Open on the design canvas).
//
// Motion budget (progress is 0..1, mapped by the caller onto whatever
// duration/curve source it uses — AnimationController for SplashScreen,
// the Timer-driven progress double for StartupSplashOverlay):
//   0.00–0.55  lockup fade + scale(92%→100%) + rise(8px→0)   easeOutQuart
//   0.00–0.60  ring traces in (full circumference)            easeOutCubic
//   0.34–0.72  one-time diagonal sheen sweep across the mark  easeOutCubic
//   0.30–1.00  halo: continuous slow rotation + soft breathe  linear/sine
//   0.30–1.00  wordmark: 11 letters, staggered ~28ms apart    easeOutQuart
//
// No elastic/back/bounce anywhere — matches the "calm, no overshoot"
// requirement. reduceMotion collapses straight to the resting frame (no ring
// animation, no sheen, no stagger, full opacity/scale) — do not skip this,
// it is the accessibility contract for `disableAnimations`.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'safepath_logo.dart';

class AnimatedSafePathMark extends AnimatedWidget {
  const AnimatedSafePathMark({
    super.key,
    required Animation<double> progress,
    required this.reduceMotion,
    this.wordmarkStyle,
  }) : super(listenable: progress);

  final bool reduceMotion;
  final TextStyle? wordmarkStyle;

  /// Test handle for the ring's `CustomPaint` — the painter itself is
  /// private, so this key is the only automated way to prove the ring is
  /// drawn (or correctly absent under reduced motion).
  @visibleForTesting
  static const ValueKey<String> ringKey = ValueKey<String>(
    'animated-safepath-mark-ring',
  );

  Animation<double> get _progress => listenable as Animation<double>;

  static const _wordmark = 'SafePath AI';
  static const _wordStart = 0.30;
  static const _letterStagger = 0.028;
  static const _letterDuration = 0.34;

  @override
  Widget build(BuildContext context) {
    final t = reduceMotion ? 1.0 : _progress.value.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Mark(t: t, reduceMotion: reduceMotion),
        const SizedBox(height: AppSpacing.lg),
        _StaggeredWordmark(
          text: _wordmark,
          t: t,
          reduceMotion: reduceMotion,
          start: _wordStart,
          stagger: _letterStagger,
          letterDuration: _letterDuration,
          style: wordmarkStyle ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.t, required this.reduceMotion});
  final double t;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final entryP = reduceMotion
        ? 1.0
        : Curves.easeOutQuart.transform((t / 0.55).clamp(0.0, 1.0));
    final ringP = reduceMotion
        ? 1.0
        : Curves.easeOutCubic.transform((t / 0.60).clamp(0.0, 1.0));

    final breathe = reduceMotion ? 1.0 : 0.5 + 0.5 * math.sin(t * math.pi * 1.4);
    final glowOpacity = reduceMotion ? 0.18 : (0.14 + 0.08 * breathe) * entryP;
    final haloTurns = reduceMotion ? 0.0 : t * 0.42; // slow continuous drift

    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!reduceMotion)
            Transform.rotate(
              angle: haloTurns * 2 * math.pi,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.accentMint.withValues(alpha: 0),
                      AppColors.accentMint.withValues(alpha: glowOpacity),
                      AppColors.accentMint.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentMint.withValues(alpha: glowOpacity * 0.6),
            ),
          ),
          // thin traced-in progress ring — echoes the SOS ring motif used
          // elsewhere in the app (press-and-hold arm indicator).
          if (!reduceMotion)
            CustomPaint(
              key: AnimatedSafePathMark.ringKey,
              size: const Size(140, 140),
              painter: _RingPainter(progress: ringP),
            ),
          const ExcludeSemantics(child: SafePathLogo(size: 96, tile: false)),
          if (!reduceMotion) _SheenSweep(progress: t),
        ],
      ),
    );
  }
}

/// Thin traced ring behind the mark, drawn with the SAME geometry math the
/// mockup uses (2*pi*r, so it always closes into a complete loop — the
/// earlier mockup bug was a hardcoded circumference constant that didn't
/// match the radius; this painter computes it directly so that class of bug
/// can't recur).
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 66.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.accentMint.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..color = AppColors.accentMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _SheenSweep extends StatelessWidget {
  const _SheenSweep({required this.progress});
  final double progress;

  static const _start = 0.34, _end = 0.72;

  @override
  Widget build(BuildContext context) {
    final raw = ((progress - _start) / (_end - _start)).clamp(0.0, 1.0);
    if (raw <= 0 || raw >= 1) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(raw);

    return ClipOval(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Align(
          alignment: Alignment(-1.6 + eased * 3.2, -1),
          child: Transform.rotate(
            angle: 0.48,
            child: Container(
              width: 24,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0),
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

/// Reveals [text] one letter at a time, each fading/rising in on its own
/// easeOutQuart interval — this is the piece that was entirely missing from
/// both existing implementations (they render the wordmark as a single
/// static Text with no per-letter motion).
class _StaggeredWordmark extends StatelessWidget {
  const _StaggeredWordmark({
    required this.text,
    required this.t,
    required this.reduceMotion,
    required this.start,
    required this.stagger,
    required this.letterDuration,
    required this.style,
  });

  final String text;
  final double t;
  final bool reduceMotion;
  final double start;
  final double stagger;
  final double letterDuration;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }
    final chars = text.split('');
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(chars.length, (i) {
        final letterStart = start + i * stagger;
        final raw = ((t - letterStart) / letterDuration).clamp(0.0, 1.0);
        final eased = Curves.easeOutQuart.transform(raw);
        return Transform.translate(
          offset: Offset(0, 6 * (1 - eased)),
          child: Opacity(
            opacity: eased,
            child: Text(chars[i] == ' ' ? ' ' : chars[i], style: style),
          ),
        );
      }),
    );
    return Semantics(
      label: text,
      container: true,
      child: ExcludeSemantics(
        child: FittedBox(fit: BoxFit.scaleDown, child: row),
      ),
    );
  }
}
