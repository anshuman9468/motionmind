import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTapTab(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = const [
      _NavItem(icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded, label: 'Home', route: '/'),
      _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Market', route: '/marketplace'),
      _NavItem(icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded, label: 'AI Coach', route: '/ai-coach'),
      _NavItem(icon: Icons.radar_outlined, activeIcon: Icons.radar_rounded, label: 'Twin', route: '/digital-twin'),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', route: '/profile'),
    ];

    final secondaryItems = const [
      _NavItem(icon: Icons.sports_esports_rounded, activeIcon: Icons.sports_esports_rounded, label: 'Practice Room', route: '/practice'),
      _NavItem(icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded, label: 'Analytics Dashboard', route: '/dashboard'),
      _NavItem(icon: Icons.forum_rounded, activeIcon: Icons.forum_rounded, label: 'Community Feed', route: '/community'),
      _NavItem(icon: Icons.leaderboard_rounded, activeIcon: Icons.leaderboard_rounded, label: 'Leaderboard', route: '/leaderboard'),
      _NavItem(icon: Icons.workspace_premium_rounded, activeIcon: Icons.workspace_premium_rounded, label: 'Achievements', route: '/achievements'),
      _NavItem(icon: Icons.settings_rounded, activeIcon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Mobile Drawer App Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SkillVerse AI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Mobile Telemetry Engine', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.glassBorder),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: secondaryItems.length,
                  itemBuilder: (context, index) {
                    final item = secondaryItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: Icon(item.icon, color: AppColors.cyanGlow, size: 22),
                        title: Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 12),
                        onTap: () {
                          Navigator.pop(context);
                          context.push(item.route);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.90),
          border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                navItems.length,
                (index) {
                  final item = navItems[index];
                  final isSelected = navigationShell.currentIndex == index;
                  return InkWell(
                    onTap: () => _onTapTab(index),
                    splashColor: AppColors.cyanGlow.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.25) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppColors.cyanGlow : AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.cyanGlow : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
