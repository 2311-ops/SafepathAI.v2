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
