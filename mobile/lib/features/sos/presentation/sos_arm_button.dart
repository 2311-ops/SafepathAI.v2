import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'sos_arm_ring_painter.dart';

/// The always-visible, raised centre SOS control (DESIGN-02).
///
/// A 72px disc that arms over a locked 3000ms press-and-hold: releasing
/// before the hold completes snaps the ring back and sends nothing (nothing
/// was ever "sent" on a canceled arm — no snackbar/toast is shown). Completing
/// the hold invokes [onArmComplete] in the same animation frame the hold
/// finishes, with no confirmation gate in between (D-02: sends immediately).
///
/// This control is an action, never a navigation destination — it never
/// mutates the host shell's selected tab.
class SosArmButton extends StatefulWidget {
  const SosArmButton({super.key, required this.onArmComplete});

  /// Invoked exactly once per completed 3000ms hold.
  final VoidCallback onArmComplete;

  @override
  State<SosArmButton> createState() => _SosArmButtonState();
}

class _SosArmButtonState extends State<SosArmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  int _lastAnnouncedSecond = 0;
  bool _completedFired = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
    _controller.addListener(_handleProgress);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.removeListener(_handleProgress);
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _handleProgress() {
    // Throttled to once per whole second of hold — never per-frame, which
    // would drown out the one announcement that matters (arm-complete).
    final wholeSeconds = (_controller.value * 3).floor();
    if (wholeSeconds > _lastAnnouncedSecond && wholeSeconds < 3) {
      _lastAnnouncedSecond = wholeSeconds;
      if (mounted) setState(() {});
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Holding, $wholeSeconds of 3 seconds',
        TextDirection.ltr,
      );
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completedFired) {
      _completedFired = true;
      if (mounted) setState(() => _isPressed = false);
      HapticFeedback.heavyImpact();
      SemanticsService.sendAnnouncement(
        View.of(context),
        'SOS alert sending',
        TextDirection.ltr,
      );
      // Do not await anything before firing — the hold completing and the
      // arm-complete callback must run in the same frame (D-02).
      widget.onArmComplete();
    }
  }

  void _startArm() {
    _completedFired = false;
    _lastAnnouncedSecond = 0;
    if (!_isPressed) setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
  }

  void _cancelArm() {
    // Guards against a gesture recognizer resolving a synthesized cancel
    // during widget disposal (e.g. the tree is torn down while a hold is
    // still in progress) — reading `context` on an already-deactivated
    // element would otherwise throw.
    if (!mounted) return;
    if (_controller.value >= 1.0) return;
    if (_isPressed) setState(() => _isPressed = false);
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
      label:
          'Emergency S O S. Press and hold for three seconds to alert your '
          'guardians with your location.',
      onLongPress: _startArm,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  size: const Size(72, 72),
                  painter: SosArmRingPainter(
                    progress: _controller.value,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ),
            ),
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _startArm(),
              onPointerUp: (_) => _cancelArm(),
              onPointerCancel: (_) => _cancelArm(),
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.sosRed,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x73DE3B40),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  'SOS',
                  style: AppTypography.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
