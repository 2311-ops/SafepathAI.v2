import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'safepath_logo.dart';

class OnboardingScaffold extends StatefulWidget {
  const OnboardingScaffold({
    super.key,
    required this.children,
    this.stepLabel,
    this.title,
    this.subtitle,
    this.showLogo = true,
  });

  final List<Widget> children;
  final String? stepLabel;
  final String? title;
  final String? subtitle;
  final bool showLogo;

  @override
  State<OnboardingScaffold> createState() => _OnboardingScaffoldState();
}

class _OnboardingScaffoldState extends State<OnboardingScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      animationBehavior: AnimationBehavior.preserve,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showLogo) ...[
                        const Hero(
                          tag: 'safepath-logo',
                          child: SafePathLogo(size: 40),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (widget.stepLabel != null) ...[
                        StepIndicator(label: widget.stepLabel!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (widget.title != null)
                        Text(widget.title!, style: AppTypography.heading),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.subtitle!,
                          style: AppTypography.bodySecondary,
                        ),
                      ],
                      if (widget.title != null || widget.subtitle != null)
                        const SizedBox(height: AppSpacing.lg),
                      ...widget.children,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.label, this.progress = 0.34});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress.clamp(0, 1),
              backgroundColor: AppColors.hairline,
              color: AppColors.primaryTeal,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.kind = AuthMessageKind.warning,
  });

  final String message;
  final AuthMessageKind kind;

  @override
  Widget build(BuildContext context) {
    final isSuccess = kind == AuthMessageKind.success;
    final background = isSuccess ? AppColors.safeBg : AppColors.cautionBg;
    final border = isSuccess ? AppColors.safeBgBorder : AppColors.cautionBorder;
    final foreground = isSuccess ? AppColors.safe : AppColors.cautionText;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.info_outline;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySecondary.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AuthMessageKind { warning, success }
