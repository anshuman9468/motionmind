import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import 'models/exercise_registry.dart';

class ExercisePreparationPage extends StatelessWidget {
  const ExercisePreparationPage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final exercise = ExerciseRegistry.byId(exerciseId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Prepare your session'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(exercise.icon, color: Colors.white, size: 42),
                    const SizedBox(height: 22),
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _infoCard(
                Icons.camera_alt_rounded,
                'Camera setup',
                exercise.cameraPlacement,
              ),
              _infoCard(
                Icons.crop_free_rounded,
                'Frame and view',
                '${exercise.cameraDistance}\nSupported view: ${exercise.supportedView}.',
              ),
              _infoCard(
                Icons.accessibility_new_rounded,
                'Keep visible',
                exercise.requiredVisibility,
              ),
              _infoCard(
                Icons.insights_rounded,
                'What MotionMind measures',
                '${exercise.measurements.join(' • ')}\n\n${exercise.bodyOnlyNote}',
              ),
              const SizedBox(height: 8),
              GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Row(
                  children: [
                    const Icon(
                      Icons.timeline_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phases: ${exercise.phases.join('  →  ')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'START PRACTICE',
                  icon: Icons.videocam_rounded,
                  onPressed: () =>
                      context.push('/practice/session/${exercise.id}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 22),
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
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
