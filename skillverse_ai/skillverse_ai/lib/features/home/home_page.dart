import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/skill_badge.dart';
import '../providers/app_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final skills = ref.watch(skillsProvider);
    final enrolledSkills = skills.where((s) => s.isEnrolled).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mobile Top Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Drawer menu button for mobile
                      IconButton(
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 4),
                      // Glowing User Avatar
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyanGlow.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(user.avatarUrl),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, color: AppColors.cyanGlow, size: 16),
                            ],
                          ),
                          Text(
                            user.title,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Streak Flame Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${user.streakDays}d',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // Level & XP Progress Card
              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const SkillBadge(label: 'LVL 42', color: AppColors.cyanGlow),
                            const SizedBox(width: 10),
                            Text(
                              '${user.xp} / ${user.nextLevelXp} XP',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const Text(
                          'Top 0.6% Global',
                          style: TextStyle(color: AppColors.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: user.xp / user.nextLevelXp,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanGlow),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // AI Coach Recommendation Hero Banner
              GlassContainer(
                backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                borderColor: AppColors.primaryPurple.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Twin Telemetry Alert',
                            style: TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Simulate LLM Quantization Practice Room to boost your execution index +4.2 points.',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => context.push('/practice'),
                            child: const Row(
                              children: [
                                Text('Launch Simulator', style: TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 12)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, color: AppColors.cyanGlow, size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // Stats Row
              Row(
                children: const [
                  Expanded(
                    child: StatCard(
                      title: 'Skills Mastered',
                      value: '18',
                      trend: '+3 this month',
                      isPositive: true,
                      icon: Icons.workspace_premium_rounded,
                      iconColor: AppColors.cyanGlow,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Digital Twin Index',
                      value: '94.8',
                      trend: '+2.4%',
                      isPositive: true,
                      icon: Icons.radar_rounded,
                      iconColor: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Enrolled Active Courses Section
              SectionHeader(
                title: 'Active Skill Tracks',
                subtitle: 'Continue your learning modules',
                actionText: 'Market',
                onActionTap: () => context.go('/marketplace'),
              ),
              const SizedBox(height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: enrolledSkills.length,
                itemBuilder: (context, index) {
                  final item = enrolledSkills[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'skill_${item.id}',
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(item.imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkillBadge(label: item.category, color: AppColors.primaryBlue),
                                const SizedBox(height: 4),
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: item.progress,
                                    minHeight: 4,
                                    backgroundColor: AppColors.surface,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldGreen),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => context.push('/practice'),
                            icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.cyanGlow, size: 28),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Quick Action Grid
              SectionHeader(
                title: 'Quick Telemetry',
                subtitle: 'Direct shortcuts to AI modules',
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      onTap: () => context.go('/ai-coach'),
                      padding: const EdgeInsets.all(14),
                      child: const Column(
                        children: [
                          Icon(Icons.psychology_rounded, color: AppColors.cyanGlow, size: 28),
                          SizedBox(height: 6),
                          Text('AI Coach', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassContainer(
                      onTap: () => context.go('/digital-twin'),
                      padding: const EdgeInsets.all(14),
                      child: const Column(
                        children: [
                          Icon(Icons.radar_rounded, color: AppColors.primaryPurple, size: 28),
                          SizedBox(height: 6),
                          Text('Digital Twin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassContainer(
                      onTap: () => context.push('/leaderboard'),
                      padding: const EdgeInsets.all(14),
                      child: const Column(
                        children: [
                          Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 28),
                          SizedBox(height: 6),
                          Text('Leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
