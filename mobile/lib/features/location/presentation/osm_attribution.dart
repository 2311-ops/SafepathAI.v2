import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Shared, visually-minimal OpenStreetMap attribution used by every
/// `FlutterMap` in the app (Live Map, route-history map).
///
/// The "OpenStreetMap contributors" credit is kept always-visible on
/// purpose to satisfy OSM's ODbL attribution requirement — it must never
/// be removed or hidden behind a tap. Only the visual weight is reduced
/// (small, muted, low-opacity text on a faint translucent chip) versus
/// the default `SimpleAttributionWidget` styling.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleAttributionWidget(
      source: Text(
        'OpenStreetMap contributors',
        style: AppTypography.bodySecondary.copyWith(
          fontSize: 9,
          height: 1.0,
          color: AppColors.bodySecondary.withValues(alpha: 0.55),
        ),
      ),
      backgroundColor: AppColors.surface.withValues(alpha: 0.45),
    );
  }
}
