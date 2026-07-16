import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.label,
    this.profileImageUrl,
    this.profileUpdatedAt,
    this.size = 72,
    this.identityColor = AppColors.memberViolet,
  });

  final String userId;
  final String label;
  final String? profileImageUrl;
  final DateTime? profileUpdatedAt;
  final double size;
  final Color identityColor;

  @override
  Widget build(BuildContext context) {
    final url = profileImageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _InitialsAvatar(
        label: label,
        size: size,
        identityColor: identityColor,
      );
    }

    final cacheKey = '$userId-${profileUpdatedAt?.toIso8601String()}';
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: size / 2,
        backgroundColor: identityColor,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => _InitialsAvatar(
        label: label,
        size: size,
        identityColor: identityColor.withValues(alpha: 0.72),
      ),
      errorWidget: (context, url, error) => _InitialsAvatar(
        label: label,
        size: size,
        identityColor: identityColor,
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.label,
    required this.size,
    required this.identityColor,
  });

  final String label;
  final double size;
  final Color identityColor;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty
        ? '?'
        : label.trim().substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: identityColor,
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
        initial,
        style: AppTypography.title.copyWith(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
