import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/preview_badge.dart';
import '../providers/app_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Edit profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: GlassTextField(
          hintText: 'Your name',
          controller: controller,
          prefixIcon: Icons.person_outline_rounded,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(userProvider.notifier).updateName(name);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: AppColors.radiusLarge,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryBlue,
                    child: Text(
                      user.name.isEmpty
                          ? 'M'
                          : user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textOnAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showEditProfileDialog(context, ref, user.name),
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.primaryBlue,
                    tooltip: 'Edit profile',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Training history',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Example history',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                PreviewBadge(label: 'MOCK DATA'),
              ],
            ),
            const SizedBox(height: 10),
            const _MockHistoryItem(
              icon: Icons.fitness_center_rounded,
              title: 'Squat fundamentals',
              detail: '12 reps · 8 min · Example session',
            ),
            const SizedBox(height: 8),
            const _MockHistoryItem(
              icon: Icons.sports_martial_arts_rounded,
              title: 'Boxing jab mechanics',
              detail: '24 cycles · 10 min · Example session',
            ),
            const SizedBox(height: 8),
            GlassContainer(
              padding: const EdgeInsets.all(14),
              child: const Text(
                'These entries are previews only. Your real history will appear after verified sessions.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Preferences',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.tune_rounded,
                    title: 'App settings',
                    subtitle: 'Notifications, camera, and privacy',
                    onTap: () => context.push('/settings'),
                  ),
                  _ProfileTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Achievements',
                    subtitle: 'View your earned milestones',
                    onTap: () => context.push('/achievements'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            GradientButton(
              width: double.infinity,
              text: 'Sign out',
              icon: Icons.logout_rounded,
              gradient: const LinearGradient(
                colors: [AppColors.roseError, Color(0xFF6E2025)],
              ),
              onPressed: () => context.go('/auth'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _MockHistoryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _MockHistoryItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
