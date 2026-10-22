import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({super.key, required this.navigationShell});

  int _getBottomNavIndex(int branchIndex) {
    switch (branchIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 3; // /practice is branch 3, maps to bottom tab 3 (Live Camera)
      case 4:
        return 4; // /digital-twin is branch 4, maps to bottom tab 4 (Oracle)
      case 8:
        return 5; // /profile is branch 8, maps to bottom tab 5 (Hero Profile)
      default:
        return -1;
    }
  }

  int _getBranchIndex(int bottomNavIndex) {
    switch (bottomNavIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 3; // bottom tab 3 (Live Camera) maps to branch 3 (/practice)
      case 4:
        return 4; // bottom tab 4 (Oracle) maps to branch 4 (/digital-twin)
      case 5:
        return 8; // bottom tab 5 (Hero Profile) maps to branch 8 (/profile)
      default:
        return 0;
    }
  }

  void _onTapTab(int index) {
    HapticFeedback.selectionClick();
    final targetBranch = _getBranchIndex(index);
    navigationShell.goBranch(
      targetBranch,
      initialLocation: targetBranch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = const [
      _NavItem(
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance_rounded,
        label: 'Pantheon',
        route: '/',
      ),
      _NavItem(
        icon: Icons.toll_outlined,
        activeIcon: Icons.toll_rounded,
        label: 'Agora',
        route: '/marketplace',
      ),
      _NavItem(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome_rounded,
        label: 'Athena AI',
        route: '/ai-coach',
      ),
      _NavItem(
        icon: Icons.videocam_outlined,
        activeIcon: Icons.videocam_rounded,
        label: 'Live Camera',
        route: '/practice',
      ),
      _NavItem(
        icon: Icons.remove_red_eye_outlined,
        activeIcon: Icons.remove_red_eye_rounded,
        label: 'Oracle',
        route: '/digital-twin',
      ),
      _NavItem(
        icon: Icons.shield_outlined,
        activeIcon: Icons.shield_rounded,
        label: 'Profile',
        route: '/profile',
      ),
    ];

    final secondaryItems = const [
      _NavItem(
        icon: Icons.bolt_rounded,
        activeIcon: Icons.bolt_rounded,
        label: 'Hercules Arena',
        route: '/practice',
      ),
      _NavItem(
        icon: Icons.query_stats_rounded,
        activeIcon: Icons.query_stats_rounded,
        label: 'Atlas Analytics',
        route: '/dashboard',
      ),
      _NavItem(
        icon: Icons.groups_3_rounded,
        activeIcon: Icons.groups_3_rounded,
        label: 'Agora Forums',
        route: '/community',
      ),
      _NavItem(
        icon: Icons.emoji_events_rounded,
        activeIcon: Icons.emoji_events_rounded,
        label: 'Olympus Standings',
        route: '/leaderboard',
      ),
      _NavItem(
        icon: Icons.workspace_premium_rounded,
        activeIcon: Icons.workspace_premium_rounded,
        label: 'Laurel Blessings',
        route: '/achievements',
      ),
      _NavItem(
        icon: Icons.handyman_rounded,
        activeIcon: Icons.handyman_rounded,
        label: 'Hephaestus Forge',
        route: '/settings',
      ),
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
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SkillVerse AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Mobile Telemetry Engine',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.glassBorder),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: secondaryItems.length,
                  itemBuilder: (context, index) {
                    final item = secondaryItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          item.icon,
                          color: AppColors.cyanGlow,
                          size: 22,
                        ),
                        title: Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textMuted,
                          size: 12,
                        ),
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
          border: const Border(
            top: BorderSide(color: AppColors.glassBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected =
                    _getBottomNavIndex(navigationShell.currentIndex) == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onTapTab(index),
                    splashColor: AppColors.cyanGlow.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue.withValues(
                                      alpha: 0.25,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? AppColors.cyanGlow
                                  : AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.cyanGlow
                                  : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
