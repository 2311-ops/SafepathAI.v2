import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../location/presentation/history_timeline_screen.dart';
import '../../location/presentation/live_map_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    _ShellTab(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _ShellTab(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Activity',
    ),
    _ShellTab(icon: Icons.sos_outlined, activeIcon: Icons.sos, label: 'SOS'),
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
            icon: Icons.sos,
            title: 'SOS',
            body: 'Emergency tools are coming soon.',
          ),
          _PlainTabPlaceholder(
            icon: Icons.insights,
            title: 'Insights',
            body: 'Insights are coming soon',
          ),
          _PlainTabPlaceholder(
            icon: Icons.privacy_tip,
            title: 'Privacy',
            body: 'Privacy controls are coming soon.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x160C3A3F),
                      blurRadius: 22,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: i == 2
                            ? const SizedBox.shrink()
                            : _NavItem(
                                tab: _tabs[i],
                                selected: _index == i,
                                onTap: () => setState(() => _index = i),
                              ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                child: _SosTabButton(
                  selected: _index == 2,
                  onPressed: () {
                    setState(() => _index = 2);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
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
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosTabButton extends StatelessWidget {
  const _SosTabButton({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.sosRed,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73DE3B40),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            'SOS',
            style: AppTypography.body.copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
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
