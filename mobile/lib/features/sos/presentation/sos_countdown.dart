import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// Tabular-figure `mm:ss` countdown for the SOS live-location streaming
/// window (D-21/SOS-04). Ticks once per second from a single
/// `Timer.periodic`, disposed in [dispose]. The very first remaining value
/// is derived from [endsAtUtc] against the current time; every subsequent
/// tick decrements that value by exactly one second rather than
/// re-comparing against the wall clock, so a widget test can drive it
/// deterministically via `tester.pump`. A fresher [endsAtUtc] (e.g. a later
/// `LiveLocationWindowUpdate`) resyncs the displayed value rather than
/// drifting from the server's own authority. Clamps at zero rather than
/// going negative.
class SosCountdown extends StatefulWidget {
  const SosCountdown({super.key, required this.endsAtUtc, this.color});

  final DateTime endsAtUtc;

  /// Defaults to [AppTypography.countdownLarge]'s own ink color when null —
  /// callers on the SOS-red chrome pass `Colors.white`.
  final Color? color;

  @override
  State<SosCountdown> createState() => _SosCountdownState();
}

class _SosCountdownState extends State<SosCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingNow();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant SosCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAtUtc != widget.endsAtUtc) {
      // The server is the sole authority on the window end (D-21) — a
      // fresher value always resyncs the display rather than letting the
      // local per-second decrement drift from it.
      setState(() {
        _remaining = _remainingNow();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remainingNow() {
    final diff = widget.endsAtUtc.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > const Duration(seconds: 1)
            ? _remaining - const Duration(seconds: 1)
            : Duration.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.clamp(0, 99);
    final seconds = _remaining.inSeconds.remainder(60).clamp(0, 59);
    final text =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    final style = widget.color != null
        ? AppTypography.countdownLarge.copyWith(color: widget.color)
        : AppTypography.countdownLarge;

    // Fixed max-width + FittedBox: the largest system font-scale setting
    // must still be readable without clipping the digits, and the
    // constraint keeps the widget's own layout width stable regardless of
    // scale (tabular figures alone only guarantee stable width at a given
    // scale, not across one).
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 176),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, overflow: TextOverflow.clip, style: style),
      ),
    );
  }
}

/// A small filled dot animating opacity between 1.0 and 0.3 on a one-second
/// repeating reverse controller, always rendered beside the static "LIVE"
/// text label — the blink is never the only signal that streaming is
/// active. Renders solid and non-animating under `disableAnimations`
/// (03-UI-SPEC.md "Live-dot blink").
class SosLiveIndicator extends StatefulWidget {
  const SosLiveIndicator({super.key, this.color = Colors.white});

  final Color color;

  @override
  State<SosLiveIndicator> createState() => _SosLiveIndicatorState();
}

class _SosLiveIndicatorState extends State<SosLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  bool? _lastReduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_lastReduceMotion == reduceMotion) return;
    _lastReduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 1.0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        reduceMotion
            ? _dot(1.0)
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _dot(0.3 + _controller.value * 0.7),
              ),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: AppTypography.caption.copyWith(
            color: widget.color,
            letterSpacing: 0.06 * 12,
          ),
        ),
      ],
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// An expanding, fading ring behind the header SOS icon — the "SOS pulse
/// ring" locked motion token (03-UI-SPEC.md): a 2000ms repeating
/// `AnimationController` (the midpoint of the locked 1.6-2.4s band) driving
/// a `CustomPainter` that expands radius `Tween(0, 28)` and fades opacity
/// `Tween(0.5, 0.0)` on an ease-out curve. Renders as a single static
/// outline under `disableAnimations`.
class SosPulseRing extends StatefulWidget {
  const SosPulseRing({super.key, this.color = Colors.white, this.size = 64});

  final Color color;
  final double size;

  @override
  State<SosPulseRing> createState() => _SosPulseRingState();
}

class _SosPulseRingState extends State<SosPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  bool? _lastReduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_lastReduceMotion == reduceMotion) return;
    _lastReduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: reduceMotion
          ? CustomPaint(
              painter: _SosPulseRingPainter(
                progress: 0,
                color: widget.color,
                staticRing: true,
              ),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _SosPulseRingPainter(
                  progress: _controller.value,
                  color: widget.color,
                  staticRing: false,
                ),
              ),
            ),
    );
  }
}

class _SosPulseRingPainter extends CustomPainter {
  const _SosPulseRingPainter({
    required this.progress,
    required this.color,
    required this.staticRing,
  });

  final double progress;
  final Color color;
  final bool staticRing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (staticRing) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, size.shortestSide / 2, paint);
      return;
    }

    final eased = Curves.easeOut.transform(progress);
    final radius = lerpDouble(0, 28, eased) ?? 0;
    final opacity = (lerpDouble(0.5, 0.0, eased) ?? 0).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SosPulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.staticRing != staticRing;
}
