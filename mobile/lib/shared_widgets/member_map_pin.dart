import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/location/application/staleness.dart';

class MemberMapPin extends StatefulWidget {
  const MemberMapPin({
    super.key,
    required this.label,
    Color? identityColor,
    Color? color,
    this.recordedAt,
    this.accuracyMeters,
    this.isSelf = false,
    this.size = 44,
    this.userId,
    this.profileImageUrl,
    this.profileUpdatedAt,
  }) : identityColor = identityColor ?? color ?? AppColors.memberViolet;

  final String label;
  final Color identityColor;
  final DateTime? recordedAt;
  final double? accuracyMeters;
  final bool isSelf;
  final double size;

  /// Stable identity for the avatar cache key. Falls back to [label] when
  /// omitted (existing callers that don't yet pass a userId keep working).
  final String? userId;

  /// When set, renders a cached network avatar inside the pin's existing
  /// bordered/shadowed circle instead of the colored-initial fallback
  /// (D-18) — extends this widget, does not replace it.
  final String? profileImageUrl;
  final DateTime? profileUpdatedAt;

  @override
  State<MemberMapPin> createState() => _MemberMapPinState();
}

class _MemberMapPinState extends State<MemberMapPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 1, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasAvatar =>
      (widget.profileImageUrl?.trim().isNotEmpty ?? false);

  Widget _initialsText() {
    return Text(
      widget.label.isEmpty ? '?' : widget.label.substring(0, 1).toUpperCase(),
      style: AppTypography.body.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = widget.recordedAt == null
        ? const StalenessBand(opacity: 1)
        : stalenessFor(DateTime.now().toUtc().difference(widget.recordedAt!));
    final circleRadius = accuracyCircleRadius(widget.accuracyMeters ?? 0);
    final circleSize = circleRadius * 2;
    final pinSize = widget.size;
    final visualSize = circleSize > pinSize ? circleSize : pinSize;
    final isLiveSelf = widget.isSelf && band.badgeText == null;
    final statusPhrase = band.badgeText ?? 'current location';
    final semanticsLabel = '${widget.label}, $statusPhrase';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: band.opacity,
            child: SizedBox(
              width: visualSize,
              height: visualSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: widget.identityColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.identityColor.withValues(alpha: 0.40),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: pinSize,
                    height: pinSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.isSelf
                          ? AppColors.primaryTeal
                          : widget.identityColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x220C3A3F),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _hasAvatar
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.profileImageUrl!,
                              cacheKey:
                                  '${widget.userId ?? widget.label}-${widget.profileUpdatedAt?.toIso8601String()}',
                              width: pinSize,
                              height: pinSize,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => _initialsText(),
                              errorWidget: (context, url, error) =>
                                  _initialsText(),
                            ),
                          ),
                        : _initialsText(),
                  ),
                  if (isLiveSelf)
                    Positioned(
                      right: (visualSize - pinSize) / 2,
                      top: (visualSize - pinSize) / 2,
                      child: FadeTransition(
                        opacity: _pulseOpacity,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.safe,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (band.badgeText != null) ...[
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: band.badgeIsAmber
                    ? AppColors.cautionBg
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: band.badgeIsAmber
                      ? AppColors.cautionBorder
                      : AppColors.hairline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  band.badgeText!,
                  style: AppTypography.caption.copyWith(
                    color: band.badgeIsAmber
                        ? AppColors.cautionText
                        : AppColors.bodySecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
