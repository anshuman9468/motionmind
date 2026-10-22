import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/skill_badge.dart';
import '../providers/app_providers.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Achievements & Badges', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(20),
                backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: AppColors.emeraldCyanGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('2 of 4 Badges Unlocked', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Collect verified NFT-grade credentials on chain', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Badges Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final badge = achievements[index];
                  return GlassContainer(
                    borderColor: badge.isUnlocked ? badge.color : AppColors.glassBorder,
                    backgroundColor: badge.isUnlocked ? badge.color.withValues(alpha: 0.1) : null,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badge.isUnlocked ? badge.color.withValues(alpha: 0.2) : AppColors.surface,
                            border: Border.all(color: badge.isUnlocked ? badge.color : AppColors.glassBorder),
                          ),
                          child: Icon(badge.icon, color: badge.isUnlocked ? badge.color : AppColors.textMuted, size: 32),
                        ),
                        Column(
                          children: [
                            Text(
                              badge.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: badge.isUnlocked ? Colors.white : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badge.description,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                        if (badge.isUnlocked)
                          SkillBadge(label: '+${badge.points} XP', color: badge.color)
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: badge.progress,
                              minHeight: 6,
                              backgroundColor: AppColors.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms);
                },
              ),

              const SizedBox(height: 24),

              GradientButton(
                width: double.infinity,
                text: 'Claim All Unlocked Badges (+800 XP)',
                icon: Icons.card_giftcard_rounded,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('800 XP Credited to your Digital Twin telemetry!'),
                      backgroundColor: AppColors.emeraldGreen,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
