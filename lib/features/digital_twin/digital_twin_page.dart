import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/digital_twin_radar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skill_badge.dart';
import '../../core/widgets/gradient_button.dart';
import '../providers/app_providers.dart';

class DigitalTwinPage extends ConsumerWidget {
  const DigitalTwinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(digitalTwinMetricsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cognitive Twin',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cyanGlow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cyanGlow.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: AppColors.emeraldGreen),
                            SizedBox(width: 4),
                            Text('Synced', style: TextStyle(color: AppColors.cyanGlow, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time simulation of your telemetry',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Custom Radar Visualization Card
              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '6-Axis Competency Matrix',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SkillBadge(label: 'Score: 94.8 / 100', color: AppColors.primaryPurple),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Radar Chart Widget
                    DigitalTwinRadarChart(metrics: metrics, size: 260)
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scale(begin: const Offset(0.9, 0.9)),

                    const SizedBox(height: 20),

                    // Grid Legend of Metrics
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: metrics.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                e.key,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(e.value * 100).toInt()}%',
                                style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Predictive Career Simulation Card
              SectionHeader(
                title: 'Predictive Career Fit',
                subtitle: 'AI projection based on your twin vector',
              ),
              const SizedBox(height: 12),

              GlassContainer(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Principal AI Systems Architect',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SkillBadge(label: '98.4% Match', color: AppColors.emeraldGreen),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Market demand: High • Estimated Compensation Range: \$380k - \$520k',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      width: double.infinity,
                      text: 'Run Telemetry Simulation',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Simulation complete! Skill twin updated by +0.8%.'),
                            backgroundColor: AppColors.emeraldGreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Skill Evolution Log
              SectionHeader(
                title: 'Evolution Timeline',
                subtitle: 'Recent competency milestones',
              ),
              const SizedBox(height: 12),

              _TimelineTile(
                date: 'Today, 02:15 AM',
                title: 'Mastered QLoRA Quantization',
                sub: '+50 XP added to AI & LLMs vector',
                icon: Icons.psychology_rounded,
                color: AppColors.cyanGlow,
              ),
              _TimelineTile(
                date: 'Yesterday',
                title: 'Completed gRPC Microservices Simulation',
                sub: '+35 XP added to System Architecture',
                icon: Icons.hub_rounded,
                color: AppColors.primaryPurple,
              ),
              _TimelineTile(
                date: '3 days ago',
                title: 'Reached 14-Day Unstoppable Streak',
                sub: 'Claimed 300 Streak Reward Points',
                icon: Icons.local_fire_department_rounded,
                color: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final String date;
  final String title;
  final String sub;
  final IconData icon;
  final Color color;

  const _TimelineTile({
    required this.date,
    required this.title,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
