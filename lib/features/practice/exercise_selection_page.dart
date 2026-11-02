import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import 'models/exercise_registry.dart';

class ExerciseSelectionPage extends StatefulWidget {
  const ExerciseSelectionPage({super.key});

  @override
  State<ExerciseSelectionPage> createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  ExerciseCategory _category = ExerciseCategory.sports;

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseRegistry.byCategory(_category);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Live coaching',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WHAT DO YOU WANT\nTO PRACTICE?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose a movement profile before the camera opens. MotionMind will only show measurements supported by that profile.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _categoryCard(
                          ExerciseCategory.sports,
                          Icons.sports_rounded,
                          'SPORTS',
                          'Athletic skills and technique',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _categoryCard(
                          ExerciseCategory.gym,
                          Icons.fitness_center_rounded,
                          'GYM',
                          'Strength and movement control',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _category == ExerciseCategory.sports
                            ? 'Sports profiles'
                            : 'Gym profiles',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${exercises.length} options',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...exercises.map(_exerciseCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryCard(
    ExerciseCategory category,
    IconData icon,
    String label,
    String subtitle,
  ) {
    final selected = _category == category;
    return GestureDetector(
      onTap: () => setState(() => _category = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.primaryBlue,
              size: 30,
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: .82)
                    : AppColors.textMuted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(ExerciseDefinition exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        onTap: () => context.push('/practice/prepare/${exercise.id}'),
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                exercise.icon,
                color: AppColors.primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _tag(exercise.supportedView.toUpperCase()),
                      _tag(
                        exercise.temporalSupported ? 'PHASES' : 'MEASUREMENTS',
                      ),
                      _tag(
                        exercise.scoreSupported
                            ? 'HEURISTIC RULES'
                            : 'TRACKING ONLY',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    ),
  );
}
