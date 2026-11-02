import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/preview_badge.dart';
import '../practice/models/exercise_registry.dart';

/// Explore is deliberately focused on the supported movement catalogue. The
/// old learning-marketplace copy described unrelated developer skills and made
/// it unclear what the camera could actually coach.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  ExerciseCategory _category = ExerciseCategory.sports;

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseRegistry.byCategory(_category);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                PreviewBadge(label: 'MOCK CATALOGUE'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse the movement catalogue. The cards below are illustrative until your own sessions are recorded.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _CategoryButton(
                    selected: _category == ExerciseCategory.sports,
                    icon: Icons.sports_basketball_rounded,
                    label: 'Sports',
                    onTap: () =>
                        setState(() => _category = ExerciseCategory.sports),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryButton(
                    selected: _category == ExerciseCategory.gym,
                    icon: Icons.fitness_center_rounded,
                    label: 'Gym',
                    onTap: () =>
                        setState(() => _category = ExerciseCategory.gym),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              _category == ExerciseCategory.sports
                  ? 'Sports movement'
                  : 'Gym movement',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...exercises.map(_ExerciseCard.new),
          ],
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      borderRadius: AppColors.radiusMedium,
      backgroundColor: selected
          ? AppColors.primaryBlue.withValues(alpha: .18)
          : AppColors.surface,
      borderColor: selected ? AppColors.primaryBlue : AppColors.outline,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.exercise);

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        onTap: () => context.push('/practice/prepare/${exercise.id}'),
        padding: const EdgeInsets.all(16),
        borderRadius: AppColors.radiusMedium,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(AppColors.radiusSmall),
              ),
              child: Icon(
                exercise.icon,
                color: AppColors.primaryBlue,
                size: 25,
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
                  const SizedBox(height: 5),
                  Text(
                    exercise.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _Tag(label: _viewLabel(exercise.supportedView)),
                      _Tag(
                        label: exercise.temporalSupported
                            ? 'Movement phases'
                            : 'Measurements',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _viewLabel(String view) => switch (view) {
    'side' => 'Side view',
    'front' => 'Front view',
    _ => 'Supported view',
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
