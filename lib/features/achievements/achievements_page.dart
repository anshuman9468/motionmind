import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/preview_badge.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Achievements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Milestones to chase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                PreviewBadge(),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'These examples show how achievements can look after real sessions.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            const _MockAchievement(
              icon: Icons.flag_rounded,
              title: 'First practice',
              subtitle: 'Complete your first camera session',
              progress: 0.7,
            ),
            const SizedBox(height: 10),
            const _MockAchievement(
              icon: Icons.repeat_rounded,
              title: 'Controlled repetition',
              subtitle: 'Complete 25 verified repetitions',
              progress: 0.48,
            ),
            const SizedBox(height: 10),
            const _MockAchievement(
              icon: Icons.local_fire_department_rounded,
              title: 'Keep the rhythm',
              subtitle: 'Practice on three different days',
              progress: 0.33,
            ),
            const SizedBox(height: 18),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Preview milestones are illustrative and do not represent your earned achievements yet.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: 'Start practice',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push('/practice'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockAchievement extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;

  const _MockAchievement({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.cyanGlow, size: 24),
          ),
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
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.cyanGlow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              color: AppColors.cyanGlow,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
