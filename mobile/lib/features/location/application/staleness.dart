class StalenessBand {
  const StalenessBand({
    required this.opacity,
    this.badgeText,
    this.badgeIsAmber = false,
  });

  final double opacity;
  final String? badgeText;
  final bool badgeIsAmber;
}

StalenessBand stalenessFor(Duration age) {
  final normalized = age.isNegative ? Duration.zero : age;
  if (normalized < const Duration(minutes: 2)) {
    return const StalenessBand(opacity: 1);
  }

  if (normalized < const Duration(minutes: 15)) {
    return StalenessBand(
      opacity: 0.7,
      badgeText: 'Last seen ${normalized.inMinutes} min ago',
    );
  }

  if (normalized < const Duration(hours: 1)) {
    return StalenessBand(
      opacity: 0.45,
      badgeText: 'Last seen ${normalized.inMinutes} min ago',
      badgeIsAmber: true,
    );
  }

  return StalenessBand(
    opacity: 0.3,
    badgeText: 'Last seen ${_relativeAge(normalized)} ago',
    badgeIsAmber: true,
  );
}

/// The "connected but no fresh reading" threshold used by
/// [LocationState.isMemberStale] to distinguish online-and-fresh from
/// online-but-stale. Chosen to sit just above the existing 2-minute first
/// opacity-fade band in [stalenessFor] (so the marker begins to visually
/// fade slightly before the explicit "stale" label appears — a coherent
/// progression) and is a reasonable "we should have heard something by now"
/// window given the 5-minute movement-independent battery-refresh cadence
/// in `LocationController`. Complementary to, not a replacement for, the
/// continuous opacity bands above.
const Duration kStaleThreshold = Duration(minutes: 3);

/// Pure boolean staleness check: is [age] at or beyond [threshold]?
/// Negative ages (clock skew / future timestamps) are clamped to zero and
/// treated as fresh, mirroring [stalenessFor]'s existing normalization.
bool isStaleAge(Duration age, {Duration threshold = kStaleThreshold}) {
  final normalized = age.isNegative ? Duration.zero : age;
  return normalized >= threshold;
}

double accuracyCircleRadius(double accuracyMeters) {
  if (accuracyMeters.isNaN || accuracyMeters.isInfinite) return 24;
  return accuracyMeters < 24 ? 24 : accuracyMeters;
}

String _relativeAge(Duration age) {
  if (age < const Duration(days: 1)) {
    final hours = age.inHours;
    return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
  }

  final days = age.inDays;
  return '$days ${days == 1 ? 'day' : 'days'}';
}
