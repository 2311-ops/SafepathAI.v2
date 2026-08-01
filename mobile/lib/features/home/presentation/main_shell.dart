import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../location/presentation/history_timeline_screen.dart';
import '../../location/presentation/live_map_screen.dart';
import '../../privacy/presentation/privacy_center_screen.dart';
import '../../sos/application/sos_controller.dart';
import '../../sos/presentation/sos_arm_button.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  // The SOS slot (index 2) is an action, never a navigation destination, so
  // it is excluded from this list — only the four navigable tabs remain.
  static const _tabs = [
    _ShellTab(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _ShellTab(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Activity',
    ),
    _ShellTab(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'Insights',
    ),
    _ShellTab(
      icon: Icons.privacy_tip_outlined,
      activeIcon: Icons.privacy_tip,
      label: 'Privacy',
    ),
  ];

  void _onArmComplete() {
    // No confirmation dialog, countdown, or cancel-before-send gate between
    // the hold completing and this navigation (D-02). Push (not go) so the
    // emergency session sits on top of the shell and dismissing it returns
    // to where the user was.
    ref.read(sosControllerProvider.notifier).arm();
    context.pushNamed('sos-session');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          LiveMapScreen(),
          HistoryTimelineScreen(),
          _PlainTabPlaceholder(
            icon: Icons.insights,
            title: 'Insights',
            body: 'Insights are coming soon',
          ),
          PrivacyCenterScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 104,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
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
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        // The centre slot (index 2) stays a plain spacer with
                        // no tap forwarding — SOS is an action, not a nav
                        // destination. Tabs beyond it shift down by one to
                        // fill the four navigable slots.
                        child: i == 2
                            ? const SizedBox(width: 76)
                            : _NavItem(
                                tab: _tabs[i < 2 ? i : i - 1],
                                selected: _index == (i < 2 ? i : i - 1),
                                onTap: () =>
                                    setState(() => _index = i < 2 ? i : i - 1),
                              ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -40,
                child: SosArmButton(onArmComplete: _onArmComplete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryTeal : AppColors.bodySecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 64,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryTintBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: selected ? 1.08 : 1.0,
                    child: Icon(
                      selected ? tab.activeIcon : tab.icon,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      letterSpacing: 0,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlainTabPlaceholder extends StatelessWidget {
  const _PlainTabPlaceholder({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppColors.bodySecondary),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: AppTypography.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
