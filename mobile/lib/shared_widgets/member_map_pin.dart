import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class MemberMapPin extends StatelessWidget {
  const MemberMapPin({
    super.key,
    required this.label,
    required this.color,
    this.opacity = 1,
    this.size = 44,
  });

  final String label;
  final Color color;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
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
        child: Text(
          label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
          style: AppTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
