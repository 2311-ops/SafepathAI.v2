import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../family/application/family_controller.dart';
import '../application/geofence_controller.dart';
import '../data/geofence_models.dart';
import 'edit_safe_zone_screen.dart';
import 'review_safe_zone_screen.dart';
import 'safe_zone_detail_screen.dart';
import 'safe_zones_screen.dart';

/// Test seam: when overridden, this widget replaces the real `VectorMap`
/// (via each screen's `mapOverride` parameter) on every safe-zone route
/// wrapper below. `VectorMap` throws in widget tests unless a platform-view
/// stand-in is supplied, and these route-level wrappers cannot take a
/// constructor param the way a plain screen widget can — so the seam has to
/// arrive through Riverpod instead. Production reads null and renders the
/// real map; router-level tests override this with a stand-in so no native
/// platform view is mounted.
///
/// @visibleForTesting — production code must never override this provider.
final safeZoneMapOverrideProvider = Provider<Widget?>((ref) => null);

/// Route-level wrapper for `/safe-zones`: resolves the caller's family and
/// safe zones from live Riverpod state instead of the frozen loading const
/// the route used to build.
class SafeZonesPage extends ConsumerStatefulWidget {
  const SafeZonesPage({super.key});

  @override
  ConsumerState<SafeZonesPage> createState() => _SafeZonesPageState();
}

class _SafeZonesPageState extends ConsumerState<SafeZonesPage> {
  String? _requestedFamilyId;

  void _load(String familyId) {
    if (_requestedFamilyId == familyId) return;
    _requestedFamilyId = familyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(geofenceListControllerProvider.notifier).load(familyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(familyControllerProvider);
    final familyState = familyAsync.value;
    final family = familyState?.family;

    if (familyAsync.isLoading || (familyState?.isLoading ?? false)) {
      return const SafeZonesScreen.loading();
    }
    if (family == null) {
      return const SafeZonesScreen.empty();
    }

    _load(family.id);

    final listState = ref.watch(geofenceListControllerProvider);
    if (listState.isLoading && listState.zones.isEmpty) {
      return const SafeZonesScreen.loading();
    }
    if (listState.error != null && listState.zones.isEmpty) {
      return SafeZonesScreen.error(onRetry: () => _retry(family.id));
    }

    final memberNames = <String, String>{
      for (final member in familyState?.members ?? const [])
        member.userId: member.displayName ?? 'Family member',
    };

    return SafeZonesScreen(
      zones: listState.zones,
      memberNames: memberNames,
      onAdd: () => context.push('/safe-zones/add'),
      onOpen: (zone) => context.push('/safe-zones/${zone.id}', extra: zone),
      onActivity: (zone) => context.push(
        '/zone-activity?zoneId=${Uri.encodeComponent(zone.id)}',
      ),
      onRetry: () => _retry(family.id),
    );
  }

  void _retry(String familyId) {
    ref.read(geofenceListControllerProvider.notifier).load(familyId);
  }
}

/// Route-level wrapper for `/safe-zones/add` and `/safe-zones/:zoneId/edit`:
/// resolves the caller's real family id and member list instead of the
/// empty placeholders the add route used to build (which left Review zone
/// permanently disabled).
class SafeZoneEditorPage extends ConsumerWidget {
  const SafeZoneEditorPage({super.key, this.initialZone});

  final SafeZone? initialZone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final family = familyState?.family;
    if (family == null) {
      // A zone cannot belong to no circle — fall back to the list, which
      // renders its own empty state rather than constructing an editor with
      // an empty family id.
      return const SafeZonesPage();
    }

    return SafeZoneEditorScreen(
      familyId: family.id,
      members: familyState?.members ?? const [],
      initialZone: initialZone,
      mapOverride: ref.watch(safeZoneMapOverrideProvider),
      // The edit journey deliberately reuses this same review route: the
      // draft carries `zoneId` (set via `SafeZoneDraft.fromZone`), and that
      // is what makes `GeofenceController.save()` choose update over
      // create — no second save path is introduced.
      onReview: () => context.push('/safe-zones/add/review'),
    );
  }
}

/// Route-level wrapper for `/safe-zones/add/review`, used by both the
/// create and edit journeys.
class SafeZoneReviewPage extends ConsumerWidget {
  const SafeZoneReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final family = familyState?.family;
    if (family == null) {
      return const SafeZonesPage();
    }

    return SafeZoneReviewScreen(
      familyId: family.id,
      members: familyState?.members ?? const [],
      mapOverride: ref.watch(safeZoneMapOverrideProvider),
      // The editor is directly beneath this screen on the navigation stack,
      // so popping returns to it with the draft intact.
      onEditLocation: () => context.pop(),
      onEditDetails: () => context.pop(),
      onEditRadius: () => context.pop(),
      onEditSensitivity: () => context.pop(),
      onEditNotifications: () => context.pop(),
      onSaved: (zone) {
        ref.read(geofenceListControllerProvider.notifier).load(family.id);
        context.go('/safe-zones');
        context.push('/safe-zones/${zone.id}', extra: zone);
      },
    );
  }
}

/// Route-level wrapper for `/safe-zones/:zoneId`.
class SafeZoneDetailPage extends ConsumerWidget {
  const SafeZoneDetailPage({super.key, required this.zoneId, this.zone});

  final String zoneId;
  final SafeZone? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyControllerProvider).value;
    final listState = ref.watch(geofenceListControllerProvider);
    final resolvedZone =
        zone ??
        listState.zones.where((item) => item.id == zoneId).firstOrNull;
    if (resolvedZone == null) {
      // A cold deep link with no extra and no loaded list yet — fall back to
      // the list rather than rendering a detail screen with nothing to show.
      return const SafeZonesPage();
    }

    final assignedMemberName =
        (familyState?.members ?? const [])
            .where((member) => member.userId == resolvedZone.assignedMemberId)
            .firstOrNull
            ?.displayName ??
        'Family member';

    return SafeZoneDetailScreen(
      zone: resolvedZone,
      assignedMemberName: assignedMemberName,
      mapOverride: ref.watch(safeZoneMapOverrideProvider),
      onEdit: () => context.push(
        '/safe-zones/${resolvedZone.id}/edit',
        extra: resolvedZone,
      ),
      onActivity: () => context.push(
        '/zone-activity?zoneId=${Uri.encodeComponent(resolvedZone.id)}',
      ),
    );
  }
}
