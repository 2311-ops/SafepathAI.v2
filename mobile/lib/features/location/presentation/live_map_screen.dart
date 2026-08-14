import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/logout_action.dart';
import '../../../shared_widgets/member_map_pin.dart';
import '../../../shared_widgets/no_circle_cta.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../family/application/family_controller.dart';
import '../../home/presentation/main_shell.dart';
import '../../profile/application/profile_controller.dart';
import '../../auth/data/auth_models.dart';
import '../application/location_controller.dart';
import '../application/map_geometry.dart';
import '../application/staleness.dart';
import '../data/location_models.dart';
import 'battery_indicator.dart';
import 'low_battery_banner.dart';
import 'member_detail_sheet.dart';
import 'vector_map.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({
    super.key,
    @visibleForTesting this.mapController,
    @visibleForTesting this.mapPlatformViewBuilder,
  });

  /// Test seam: a test-owned camera-command sink so a widget test can read
  /// the camera *intent* recorded after a rail-card tap. A real native map
  /// controller is only handed out by `onMapCreated` and cannot be
  /// constructed in a widget test, so this replaces reading back a resulting
  /// camera position. Production callers keep constructing
  /// `const LiveMapScreen()` and get a State-owned controller instead.
  @visibleForTesting
  final VectorMapController? mapController;

  /// Test seam: when supplied, replaces the native map view entirely so a
  /// widget test never mounts a real platform view. Production callers
  /// leave this null.
  @visibleForTesting
  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

/// Zoom the live map opens at, and the zoom it returns to when it first
/// centres on this device's own GPS fix.
const double _initialZoom = 15;

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  late final bool _ownsController = widget.mapController == null;
  late final VectorMapController _mapController =
      widget.mapController ?? VectorMapController();

  @override
  void dispose() {
    if (_ownsController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Centre the camera on the user the first time this device's own GPS
    // reports, and only then.
    //
    // `VectorMap.initialTarget` cannot do this job: the plugin reads
    // `initialCameraPosition` only when the native platform view is created and
    // its `didUpdateWidget` diffs map *options*, which carry no camera — so a
    // corrected position arriving later moves the pin but leaves the camera
    // stranded wherever the bootstrap snapshot pointed. That snapshot is just
    // the last position the server ever recorded for this user, so the observed
    // failure was a map sitting on a coordinate from a previous session with
    // the user's pin thousands of kilometres off-screen and no way to reach it
    // except tapping their own status-rail card.
    //
    // Fires on the false -> true edge only, so it can never fight the user's
    // panning afterwards, and re-uses `initialZoom` so the result is exactly
    // "as if the map had opened here".
    ref.listen<AsyncValue<LocationState>>(locationControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.value?.hasDeviceFix ?? false) return;
      final fixed = next.value;
      if (fixed == null || !fixed.hasDeviceFix) return;
      final self = fixed.selfPosition;
      if (self == null) return;
      _mapController.animateTo(
        lat: self.lat,
        lng: self.lng,
        zoom: _initialZoom,
      );
    });

    final asyncState = ref.watch(locationControllerProvider);
    final state = asyncState.value;
    final familyState = ref.watch(familyControllerProvider).value;
    final profile = ref.watch(profileControllerProvider).value?.profile;
    final showSafeZones = profile?.role == Role.guardian;

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
    final cameraTarget = MapPoint(self.lat, self.lng);
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
        MapCircle(
          id: location.userId,
          center: MapPoint(location.lat, location.lng),
          radiusMeters: accuracyCircleRadius(location.accuracyMeters),
          colorHex: hexColor(_memberColor(location.userId)),
        ),
    ];
    final motionDots = [
      for (final location in locations)
        MapDot(
          id: location.userId,
          center: MapPoint(location.lat, location.lng),
          radius: location.userId == state?.selfPosition?.userId ? 12 : 10,
          colorHex: hexColor(
            location.userId == state?.selfPosition?.userId
                ? AppColors.primaryTeal
                : _memberColor(location.userId),
          ),
          opacity: location.userId == state?.selfPosition?.userId
              ? 1.0
              : stalenessFor(
                  DateTime.now().toUtc().difference(location.recordedAtUtc),
                ).opacity,
          strokeColorHex: hexColor(AppColors.surface),
          strokeWidth: 3.0,
          strokeOpacity: 1.0,
        ),
    ];
    final markers = [
      for (final location in locations)
        OverlayMarker(
          id: location.userId,
          lat: location.lat,
          lng: location.lng,
          // Widened from the 44x44 tap-target-only box so the always-visible
          // name and online/offline labels have room beneath the avatar; the
          // declared box must contain the whole Column[avatar, labels]
          // (research §5). Height raised 88->108 to fit the battery readout
          // row (LOC-04) without a RenderFlex overflow, then 108->128 when
          // the avatar's tap-target slot grew 36->56 to make room for the
          // self pin's pulse ring (DESIGN-01 redesign).
          width: 104,
          height: 128,
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
          VectorMap(
            controller: _mapController,
            initialTarget: cameraTarget,
            initialZoom: _initialZoom,
            markers: markers,
            circles: circleMarkers,
            dots: motionDots,
            // Both fields are test-only seams: LiveMapScreen's own
            // @visibleForTesting field is simply threaded through to
            // VectorMap's identically-scoped seam so a widget test can
            // inject a platform-view stand-in without either seam being
            // reachable from production call sites.
            // ignore: invalid_use_of_visible_for_testing_member
            platformViewBuilder: widget.mapPlatformViewBuilder,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapTopBar(
                    self: state?.selfPosition,
                    onlineCount: onlineCount,
                    offlineCount: offlineCount,
                    onProfile: () => context.push('/profile'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MemberStatusRail(
                    members: memberDetails,
                    onMemberTap: (member) => _mapController.animateTo(
                      lat: member.location.lat,
                      lng: member.location.lng,
                      zoom: 17,
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
          Positioned.fill(
            bottom: kShellBottomBarHeight,
            child: DraggableScrollableSheet(
              initialChildSize: 0.2,
              minChildSize: 0.2,
              maxChildSize: 0.5,
              snap: true,
              snapSizes: const [0.2, 0.5],
              builder: (context, scrollController) => DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.bottomSheet),
                  ),
                  border: const Border(
                    top: BorderSide(color: AppColors.hairline),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160C3A3F),
                      blurRadius: 22,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (showSafeZones) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ManageSafeZonesButton(
                          onPressed: () => context.push('/safe-zones'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ViewNotificationsButton(
                        onPressed: () => context.push('/notifications'),
                      ),
                    ),
                  ],
                ),
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

/// A single family member's vector-map marker: an avatar (or colored-initial
/// fallback, D-18) plus an always-visible name label (PROFILE-06), faded by
/// [stalenessFor] the way the pre-migration marker alpha did, with a tap
/// target opening the member detail sheet. This is a screen-space Flutter
/// widget overlay above the native renderer (see `vector_map.dart`), which
/// carries no built-in `alpha`/`onTap` of its own, so both live here.
///
/// The avatar border colors by presence (safety green online / slate grey
/// offline, DESIGN-01 redesign) and the self ("You") marker additionally
/// draws an animated expanding pulse ring behind the avatar — other
/// members' pins never animate.
///
/// A `StatefulWidget` (previously `StatelessWidget`) solely to own the pulse
/// animation's `AnimationController`; the constructor signature stays
/// byte-identical and this remains public (not underscore-private) so it can
/// be exercised directly by widget tests. Kept over a plain
/// `List<OverlayMarker>` (no per-marker global state beyond the pulse
/// controller) so a future marker-clustering layer could still wrap these
/// without a rewrite (D-19 — compatibility only, no clustering dependency is
/// added this phase; at MVP scale, screen-space widget pins reprojected via
/// the native projection need no clustering package).
class LiveMemberMarker extends StatefulWidget {
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

  @override
  State<LiveMemberMarker> createState() => _LiveMemberMarkerState();
}

class _LiveMemberMarkerState extends State<LiveMemberMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool get _hasAvatar =>
      (widget.location.profileImageUrl?.trim().isNotEmpty ?? false);

  // The controller is created above (in initState, implicitly via the
  // `late final` field initializer) but intentionally not started there —
  // start/stop depends on MediaQuery, which is unsafe to read before
  // didChangeDependencies runs.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant LiveMemberMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelf != widget.isSelf) {
      _syncPulseAnimation();
    }
  }

  void _syncPulseAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate = widget.isSelf && !reduceMotion;
    if (shouldAnimate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isSelf
        ? 1.0
        : stalenessFor(
            DateTime.now().toUtc().difference(widget.location.recordedAtUtc),
          ).opacity;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Semantics(
        button: true,
        label:
            '${widget.name}, ${widget.isOnline ? 'online' : 'offline'}, '
            'open details',
        child: Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isSelf)
                      IgnorePointer(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) => CustomPaint(
                              key: const ValueKey('self-pulse-ring'),
                              size: const Size(56, 56),
                              painter: _SelfPulseRingPainter(
                                progress: _pulseController.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.isSelf
                            ? AppColors.primaryTeal
                            : widget.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isOnline
                              ? AppColors.safe
                              : AppColors.bodySecondary,
                          width: 3,
                        ),
                        boxShadow: const [
                          // Crisp white halo separating the presence ring
                          // from the basemap beneath it, at zero layout cost.
                          BoxShadow(
                            color: AppColors.surface,
                            blurRadius: 0,
                            spreadRadius: 1.5,
                          ),
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
                                imageUrl: widget.location.profileImageUrl!,
                                cacheKey:
                                    '${widget.location.userId}-${widget.location.profileUpdatedAt?.toIso8601String()}',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _initials(),
                                errorWidget: (context, url, error) =>
                                    _initials(),
                              ),
                            )
                          : _initials(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              _MarkerNameLabel(name: widget.name),
              const SizedBox(height: 2),
              _MarkerPresenceLabel(isOnline: widget.isOnline),
              const SizedBox(height: 2),
              BatteryIndicator(percent: widget.location.batteryPercent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initials() {
    return Text(
      widget.name.isEmpty ? '?' : widget.name.substring(0, 1).toUpperCase(),
      style: AppTypography.body.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

/// Animated expanding pulse ring drawn behind the self ("You") map pin only
/// (DESIGN-01 redesign). Deliberately a standalone painter rather than
/// reusing `SosPulseRing` from `sos_countdown.dart` — that widget is
/// SOS-scoped emergency visual language and must not appear on a routine
/// surface.
class _SelfPulseRingPainter extends CustomPainter {
  const _SelfPulseRingPainter({required this.progress});

  /// 0.0 -> 1.0 animation progress, looping.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 20 + (28 - 20) * progress;
    final opacity = 0.5 * (1 - progress);
    final paint = Paint()
      ..color = AppColors.primaryTeal.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SelfPulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
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

/// The slim, always-visible top status bar (DESIGN-01 redesign): identity
/// pin, aggregate family presence pill, profile action, logout action. No
/// title text and no action buttons live here anymore — those moved to the
/// draggable bottom action sheet built in `_LiveMapScreenState.build`.
class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
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
          borderRadius: BorderRadius.circular(999),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberMapPin(
                label: 'You',
                identityColor: AppColors.primaryTeal,
                isSelf: true,
                size: 36,
                userId: self?.userId,
                profileImageUrl: self?.profileImageUrl,
                profileUpdatedAt: self?.profileUpdatedAt,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FamilyStatusPill(
                  onlineCount: onlineCount,
                  offlineCount: offlineCount,
                ),
              ),
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

/// Aggregate family presence, e.g. "1 online · 1 offline". Copy is
/// deliberately lowercase so it can never collide with the uppercase
/// ONLINE/OFFLINE labels rendered under each map marker.
class _FamilyStatusPill extends StatelessWidget {
  const _FamilyStatusPill({
    required this.onlineCount,
    required this.offlineCount,
  });

  final int onlineCount;
  final int offlineCount;

  @override
  Widget build(BuildContext context) {
    final foreground = onlineCount > 0
        ? AppColors.safe
        : AppColors.bodySecondary;
    final background = onlineCount > 0
        ? AppColors.safeBg
        : AppColors.hairlineSoft;
    final border = onlineCount > 0
        ? AppColors.safeBgBorder
        : AppColors.hairline;
    final label = '$onlineCount online · $offlineCount offline';

    return Semantics(
      label: '$onlineCount family members online, $offlineCount offline',
      child: DecoratedBox(
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
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageSafeZonesButton extends StatelessWidget {
  const ManageSafeZonesButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.add_location_alt_outlined),
    label: const Text('Manage safe zones'),
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
  );
}

class ViewNotificationsButton extends StatelessWidget {
  const ViewNotificationsButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'View notifications',
    button: true,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.notifications_none),
      label: const Text('Notifications'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
