import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_typography.dart';
import 'sos_arm_ring_painter.dart';

/// Self-cancel control shown on the Delivering/Live-active session states
/// (03-UI-SPEC.md "Hold-to-cancel", D-05/D-24). Reuses the arm button's
/// press-and-hold-plus-ring pattern (`SosArmButton`,
/// `SosArmRingPainter`) with three deliberate differences:
///
/// - The hold is 2000ms, not 3000ms — short enough that correcting a false
///   alarm feels responsive, long enough that an accidental brush cannot
///   silently retract a real emergency.
/// - The ring is white-on-transparent (via [SosArmRingPainter.colorOverride])
///   instead of the arm's mint-to-red interpolation — canceling is not
///   arming, and reusing that color language here would suggest otherwise.
/// - Completion fires [HapticFeedback.mediumImpact] rather than heavy impact.
///
/// There is deliberately no confirmation dialog anywhere in this widget: a
/// modal would insert exactly the decision gate the parallel-cancel design
/// exists to avoid. The two-second hold itself is the confirmation; the
/// post-action confirmation is the caller's own Self-canceled screen state.
class SosHoldToCancelButton extends StatefulWidget {
  const SosHoldToCancelButton({super.key, required this.onCancelComplete});

  /// Invoked exactly once per completed 2000ms hold.
  final VoidCallback onCancelComplete;

  @override
  State<SosHoldToCancelButton> createState() => _SosHoldToCancelButtonState();
}

class _SosHoldToCancelButtonState extends State<SosHoldToCancelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  bool _completedFired = false;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completedFired) {
      _completedFired = true;
      if (mounted) setState(() => _isHolding = false);
      HapticFeedback.mediumImpact();
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Alert canceled',
        TextDirection.ltr,
      );
      widget.onCancelComplete();
    }
  }

  void _startHold() {
    _completedFired = false;
    if (!_isHolding) setState(() => _isHolding = true);
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    // Mirrors SosArmButton's own guard: a synthesized pointer-cancel during
    // widget disposal must never touch a deactivated context.
    if (!mounted) return;
    if (_controller.value >= 1.0) return;
    if (_isHolding) setState(() => _isHolding = false);
    if (_reduceMotion) {
      _controller.value = 0;
    } else {
      _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    return Semantics(
      button: true,
      label: 'Cancel this emergency alert. Press and hold for two seconds.',
      onLongPress: _startHold,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _startHold(),
        onPointerUp: (_) => _cancelHold(),
        onPointerCancel: (_) => _cancelHold(),
        child: SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'Hold to cancel alert',
                      style: AppTypography.ctaLabel.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    // The ring painter's geometry is fixed to a 72px canvas
                    // (matches SosArmButton's own control) — FittedBox scales
                    // it down to a small in-line indicator rather than
                    // reimplementing the ring at a second radius.
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: FittedBox(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) => CustomPaint(
                                size: const Size(72, 72),
                                painter: SosArmRingPainter(
                                  progress: _controller.value,
                                  reduceMotion: reduceMotion,
                                  colorOverride: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
