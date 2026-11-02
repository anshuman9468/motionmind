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
  final String? phaseLabel;
  final bool automaticPhase;
  final String? instructionOverride;
  final VoidCallback onNextPhase;
  final VoidCallback onPrevPhase;

  const BiomechanicalHudPanel({
    super.key,
    required this.profile,
    required this.currentPhase,
    required this.evaluation,
    this.phaseLabel,
    this.automaticPhase = false,
    this.instructionOverride,
    required this.onNextPhase,
    required this.onPrevPhase,
  });

  String _statusLabel(BiomechanicsEvaluationStatus status) {
    switch (status) {
      case BiomechanicsEvaluationStatus.lowConfidence:
        return 'LOW CONFIDENCE';
      case BiomechanicsEvaluationStatus.insufficientData:
        return 'MEASUREMENTS PENDING';
      case BiomechanicsEvaluationStatus.unsupportedView:
        return 'VIEW NOT SUPPORTED';
      case BiomechanicsEvaluationStatus.trackingLost:
        return 'TRACKING PAUSED';
      case BiomechanicsEvaluationStatus.valid:
        return 'TRACKING ONLY';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!evaluation.isHumanDetected) return const SizedBox.shrink();

    final score = evaluation.overallTechniqueScore;
    final scoreColor = !evaluation.techniqueEvaluationAvailable
        ? AppColors.textMuted
        : score! >= 85
        ? AppColors.emeraldGreen
        : (score >= 70 ? AppColors.primaryBlue : AppColors.roseError);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      borderColor: AppColors.cyanGlow.withValues(alpha: 0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive header: phase and status are allowed to occupy their
          // own rows, so long exercise names can never wrap letter-by-letter.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!automaticPhase)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHASE: ${(phaseLabel ?? currentPhase.name)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.cyanGlow,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              if (!automaticPhase)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scoreColor, width: 1),
              ),
              child: Text(
                score == null
                    ? (evaluation.status == BiomechanicsEvaluationStatus.valid
                          ? 'TRACKING ONLY'
                          : _statusLabel(evaluation.status))
                    : '${score.toInt()}% HEURISTIC QUALITY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
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
                    instructionOverride?.isNotEmpty == true
                        ? instructionOverride!
                        : evaluation.primaryInstruction,
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
                  case BiomechanicalErrorSeverity.unavailable:
                    statusColor = AppColors.textMuted;
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
                          Flexible(
                            child: Text(
                              res.currentAngle == null
                                  ? 'CURRENT: UNAVAILABLE'
                                  : 'CURRENT: ${res.currentAngle!.toInt()}°',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• TARGET: ${res.targetAngle.toInt()}°',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
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
