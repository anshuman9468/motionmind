import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../models/skill_biomechanics.dart';
import '../services/biomechanics_engine.dart';

class BiomechanicalHudPanel extends StatelessWidget {
  final SkillBiomechanicsProfile profile;
  final SkillMovementPhase currentPhase;
  final BiomechanicsEvaluationFrame evaluation;
  final VoidCallback onNextPhase;
  final VoidCallback onPrevPhase;

  const BiomechanicalHudPanel({
    super.key,
    required this.profile,
    required this.currentPhase,
    required this.evaluation,
    required this.onNextPhase,
    required this.onPrevPhase,
  });

  @override
  Widget build(BuildContext context) {
    if (!evaluation.isHumanDetected) return const SizedBox.shrink();

    final scoreColor = evaluation.overallTechniqueScore >= 85
        ? AppColors.emeraldGreen
        : (evaluation.overallTechniqueScore >= 70
              ? AppColors.primaryBlue
              : AppColors.roseError);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      borderColor: AppColors.cyanGlow.withValues(alpha: 0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Skill Phase Step Tracker & Technique Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.cyanGlow,
                        size: 16,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onPrevPhase();
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PHASE: ${currentPhase.name}',
                            style: const TextStyle(
                              color: AppColors.cyanGlow,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            profile.skillTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.cyanGlow,
                        size: 16,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onNextPhase();
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor, width: 1),
                ),
                child: Text(
                  '${evaluation.overallTechniqueScore.toInt()}% SCORE',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 10),

          // Primary Real-Time AR Instruction Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.cyanGlow,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    evaluation.primaryInstruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Measured Angle vs Target Angle Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: evaluation.jointResults.entries.map((entry) {
                final res = entry.value;
                Color statusColor;
                switch (res.severity) {
                  case BiomechanicalErrorSeverity.green:
                    statusColor = AppColors.emeraldGreen;
                    break;
                  case BiomechanicalErrorSeverity.yellow:
                    statusColor = Colors.amber;
                    break;
                  case BiomechanicalErrorSeverity.red:
                    statusColor = AppColors.roseError;
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.adjust_rounded,
                            color: statusColor,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            res.jointName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'CURRENT: ${res.currentAngle.toInt()}°',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• TARGET: ${res.targetAngle.toInt()}°',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
