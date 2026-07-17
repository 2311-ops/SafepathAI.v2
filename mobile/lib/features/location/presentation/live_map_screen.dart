import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/logout_action.dart';
import '../../../shared_widgets/member_map_pin.dart';
import '../../../shared_widgets/no_circle_cta.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../family/application/family_controller.dart';
import '../application/location_controller.dart';
import '../application/staleness.dart';
import '../data/location_models.dart';
import 'battery_indicator.dart';
import 'low_battery_banner.dart';
import 'member_detail_sheet.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key, @visibleForTesting this.mapController});

  /// Test seam: a test-owned [MapController] so a widget test can read the
  /// resulting camera position after a rail-card tap. Production callers
  /// keep constructing `const LiveMapScreen()` and get a State-owned
  /// controller instead.
  @visibleForTesting
  final MapController? mapController;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  late final bool _ownsController = widget.mapController == null;
  late final MapController _mapController =
      widget.mapController ?? MapController();

  @override
  void dispose() {
    if (_ownsController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(locationControllerProvider);
    final state = asyncState.value;
    final familyState = ref.watch(familyControllerProvider).value;

    if (asyncState.isLoading ||
        (state?.isLoading ?? false) ||
        (familyState?.isLoading ?? false)) {
      return const Scaffold(
        backgroundColor: AppColors.appBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No family yet: the map has nothing to show and, more importantly, the
    // user needs a way to create or join a circle. This branch must precede
    // the location-based empty state so a family-less user always gets the
    // role-aware CTA rather than the generic "No one to show yet" copy.
    if (familyState?.family == null) {
      return const _MapMessage(
        icon: Icons.group_off,
        title: 'No circle yet',
        body: 'Create or join a family circle to see everyone on the map.',
        action: NoCircleCta(),
      );
    }

    if (state?.error != null) {
      return _MapMessage(
        icon: Icons.cloud_off,
        title: "Couldn't load live locations",
        body: state!.error!,
        action: PrimaryButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(locationControllerProvider),
        ),
      );
    }

    final locations = state?.members.values.toList() ?? const [];
    if (locations.isEmpty) {
      return const _MapMessage(
        icon: Icons.location_off,
        title: 'No one to show yet',
        body:
            "Once a family member turns on location sharing, they'll appear here.",
      );
    }

    final self = state?.selfPosition ?? locations.first;
    final cameraTarget = LatLng(self.lat, self.lng);
    final memberDetails = [
      for (final location in locations)
        _VisibleMember(
          location: location,
          name: _memberName(location, state),
          isOnline: state?.isMemberOnline(location.userId) ?? location.isOnline,
          isSelf: location.userId == state?.selfPosition?.userId,
          lastSeenAtUtc:
              state?.memberLastSeenAt(location.userId) ??
              location.lastSeenAtUtc ??
              location.recordedAtUtc,
          color: _memberColor(location.userId),
        ),
    ];
    final onlineCount = locations
        .where(
          (location) =>
              state?.isMemberOnline(location.userId) ?? location.isOnline,
        )
        .length;
    final offlineCount = locations.length - onlineCount;
    final circleMarkers = [
      for (final location in locations)
        CircleMarker(
          point: LatLng(location.lat, location.lng),
          radius: accuracyCircleRadius(location.accuracyMeters),
          useRadiusInMeter: true,
          color: _memberColor(location.userId).withValues(alpha: 0.15),
          borderColor: _memberColor(location.userId).withValues(alpha: 0.40),
          borderStrokeWidth: 2,
        ),
    ];
    final markers = [
      for (final location in locations)
        Marker(
          point: LatLng(location.lat, location.lng),
          // Widened from the 44x44 tap-target-only box so the always-visible
          // name and online/offline labels have room beneath the avatar;
          // flutter_map has no overflow anchor, so the declared box must
          // contain the whole Column[avatar, labels] (research §5). Height
          // raised 88->108 to also fit the battery readout row (LOC-04)
          // without a RenderFlex overflow.
          width: 104,
          height: 108,
          alignment: Alignment.center,
          child: LiveMemberMarker(
            location: location,
            name: _memberName(location, state),
            isOnline:
                state?.isMemberOnline(location.userId) ?? location.isOnline,
            isSelf: location.userId == state?.selfPosition?.userId,
            color: _memberColor(location.userId),
            onTap: () => showMemberDetailSheet(
              context,
              member: MemberDetail(
                name: _memberName(location, state),
                isOnline:
                    state?.isMemberOnline(location.userId) ?? location.isOnline,
                lastSeenAtUtc:
                    state?.memberLastSeenAt(location.userId) ??
                    location.lastSeenAtUtc ??
                    location.recordedAtUtc,
                batteryPercent: location.batteryPercent,
              ),
            ),
          ),
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: cameraTarget, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safepath.mobile',
              ),
              CircleLayer(circles: circleMarkers),
              MarkerLayer(markers: markers),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveMapOverlay(
                    self: state?.selfPosition,
                    onlineCount: onlineCount,
                    offlineCount: offlineCount,
                    onProfile: () => context.push('/profile'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MemberStatusRail(
                    members: memberDetails,
                    onMemberTap: (member) => _mapController.move(
                      LatLng(member.location.lat, member.location.lng),
                      17,
                    ),
                  ),
                  if (state?.lowBatteryAlert != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    LowBatteryBanner(
                      alert: state!.lowBatteryAlert!,
                      onDismissed: () => ref
                          .read(locationControllerProvider.notifier)
                          .dismissLowBatteryAlert(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _memberColor(String userId) {
    return userId.hashCode.isEven
        ? AppColors.memberViolet
        : AppColors.memberPink;
  }

  static String _memberName(LiveLocation location, LocationState? state) {
    if (location.userId == state?.selfPosition?.userId) return 'You';
    final displayName = location.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return 'Family member';
  }
}

/// A single family member's OSM map marker: an avatar (or colored-initial
/// fallback, D-18) plus an always-visible name label (PROFILE-06), faded by
/// [stalenessFor] the way the pre-migration `google_maps_flutter` marker
/// alpha did, with a tap target opening the member detail sheet. flutter_map
/// `Marker`s carry no `alpha`/`onTap` of their own, so both live here.
///
/// Kept a self-contained `StatelessWidget` over a plain `List<Marker>` (no
/// per-marker global state) so a future `flutter_map_marker_cluster` layer
/// could wrap these without a rewrite (D-19 — compatibility only, the
/// clustering dependency itself is not added this phase). Public (not
/// underscore-private) so it can be exercised directly by widget tests.
class LiveMemberMarker extends StatelessWidget {
  const LiveMemberMarker({
    super.key,
    required this.location,
    required this.name,
    required this.isOnline,
    required this.isSelf,
    required this.color,
    required this.onTap,
  });

  final LiveLocation location;
  final String name;
  final bool isOnline;
  final bool isSelf;
  final Color color;
  final VoidCallback onTap;

  bool get _hasAvatar => (location.profileImageUrl?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final opacity = isSelf
        ? 1.0
        : stalenessFor(
            DateTime.now().toUtc().difference(location.recordedAtUtc),
          ).opacity;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '$name, ${isOnline ? 'online' : 'offline'}, open details',
        child: Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelf ? AppColors.primaryTeal : color,
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
                          imageUrl: location.profileImageUrl!,
                          cacheKey:
                              '${location.userId}-${location.profileUpdatedAt?.toIso8601String()}',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _initials(),
                          errorWidget: (context, url, error) => _initials(),
                        ),
                      )
                    : _initials(),
              ),
              const SizedBox(height: 2),
              _MarkerNameLabel(name: name),
              const SizedBox(height: 2),
              _MarkerPresenceLabel(isOnline: isOnline),
              const SizedBox(height: 2),
              BatteryIndicator(percent: location.batteryPercent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initials() {
    return Text(
      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      style: AppTypography.body.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _VisibleMember {
  const _VisibleMember({
    required this.location,
    required this.name,
    required this.isOnline,
    required this.isSelf,
    required this.lastSeenAtUtc,
    required this.color,
  });

  final LiveLocation location;
  final String name;
  final bool isOnline;
  final bool isSelf;
  final DateTime? lastSeenAtUtc;
  final Color color;
}

class _LiveMapOverlay extends StatelessWidget {
  const _LiveMapOverlay({
    required this.self,
    required this.onlineCount,
    required this.offlineCount,
    required this.onProfile,
  });

  final LiveLocation? self;
  final int onlineCount;
  final int offlineCount;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C0C3A3F),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              MemberMapPin(
                label: 'You',
                identityColor: AppColors.primaryTeal,
                isSelf: true,
                size: 40,
                userId: self?.userId,
                profileImageUrl: self?.profileImageUrl,
                profileUpdatedAt: self?.profileUpdatedAt,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Your family, live', style: AppTypography.title),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _StatusCountChip(
                          icon: Icons.wifi_tethering,
                          label: '$onlineCount online',
                          isOnline: true,
                        ),
                        _StatusCountChip(
                          icon: Icons.wifi_off,
                          label: '$offlineCount offline',
                          isOnline: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Profile',
                icon: const Icon(Icons.person_outline),
                onPressed: onProfile,
              ),
              const SizedBox(width: AppSpacing.xs),
              const LogoutAction(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCountChip extends StatelessWidget {
  const _StatusCountChip({
    required this.icon,
    required this.label,
    required this.isOnline,
  });

  final IconData icon;
  final String label;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final foreground = isOnline ? AppColors.safe : AppColors.bodySecondary;
    final background = isOnline ? AppColors.safeBg : AppColors.hairlineSoft;
    final border = isOnline ? AppColors.safeBgBorder : AppColors.hairline;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberStatusRail extends StatelessWidget {
  const _MemberStatusRail({required this.members, required this.onMemberTap});

  final List<_VisibleMember> members;
  final ValueChanged<_VisibleMember> onMemberTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => _MemberStatusCard(
          key: ValueKey('member-card-${members[index].location.userId}'),
          member: members[index],
          onTap: () => onMemberTap(members[index]),
        ),
      ),
    );
  }
}

class _MemberStatusCard extends StatelessWidget {
  const _MemberStatusCard({
    super.key,
    required this.member,
    required this.onTap,
  });

  final _VisibleMember member;
  final VoidCallback onTap;

  bool get _hasAvatar =>
      (member.location.profileImageUrl?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${member.name}, ${member.isOnline ? 'online' : 'offline'}, ${lastSeenText(member.lastSeenAtUtc)}',
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 136,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: member.isOnline
                    ? AppColors.safeBgBorder
                    : AppColors.hairline,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0C3A3F),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _MemberAvatar(member: member, hasAvatar: _hasAvatar),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 14,
                          height: 1.1,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _InlinePresence(isOnline: member.isOnline),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.hasAvatar});

  final _VisibleMember member;
  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: member.isSelf ? AppColors.primaryTeal : member.color,
            shape: BoxShape.circle,
          ),
          child: hasAvatar
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: member.location.profileImageUrl!,
                    cacheKey:
                        '${member.location.userId}-${member.location.profileUpdatedAt?.toIso8601String()}',
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _AvatarInitial(member.name),
                    errorWidget: (context, url, error) =>
                        _AvatarInitial(member.name),
                  ),
                )
              : _AvatarInitial(member.name),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: _PresenceDot(isOnline: member.isOnline, size: 12),
        ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      style: AppTypography.body.copyWith(
        fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _InlinePresence extends StatelessWidget {
  const _InlinePresence({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final foreground = isOnline ? AppColors.safe : AppColors.bodySecondary;
    return Row(
      children: [
        _PresenceDot(isOnline: isOnline, size: 8),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            isOnline ? 'Online' : 'Offline',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              height: 1.1,
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.isOnline, required this.size});

  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.safe : AppColors.bodySecondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
    );
  }
}

/// Explicit always-visible status badge for map markers. The member detail
/// sheet already shows this state on tap; keeping it here prevents the map
/// surface from relying on color-only interpretation.
class _MarkerPresenceLabel extends StatelessWidget {
  const _MarkerPresenceLabel({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final foreground = isOnline ? AppColors.safe : AppColors.bodySecondary;
    final background = isOnline ? AppColors.safeBg : AppColors.hairlineSoft;
    final border = isOnline ? AppColors.safeBgBorder : AppColors.hairline;
    final label = isOnline ? 'ONLINE' : 'OFFLINE';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppTypography.caption.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                color: foreground,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible name pill under a [LiveMemberMarker] (PROFILE-06 — the
/// name previously only appeared inside the tap-triggered member detail
/// sheet). Never uses SOS red per this phase's UI-SPEC scope rule.
class _MarkerNameLabel extends StatelessWidget {
  const _MarkerNameLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180C3A3F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Manrope (not the mono `caption` role — that's reserved for
          // uppercase status badges, not a person's name) at a compact size
          // so the pill stays small on the map.
          style: AppTypography.title.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          const LogoutAction(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppColors.bodySecondary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
