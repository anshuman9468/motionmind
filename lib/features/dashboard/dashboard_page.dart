import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/preview_badge.dart';

/// This screen currently shows an explicit preview so the product areas are
/// visible before durable session history is connected.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Your training, over time',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const PreviewBadge(),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'A preview of the progress view. Replace these examples with verified session history as you practice.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Example training summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _MockStat(value: '6', label: 'sessions'),
                      _MockStat(value: '42m', label: 'training'),
                      _MockStat(value: '38', label: 'reps'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Illustrative values only — not recorded user performance.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 18),
                  GradientButton(
                    text: 'Start practice',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.push('/practice'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent preview sessions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const _MockSession(
              exercise: 'Squats',
              details: '12 reps · 8 min',
              date: 'Today',
            ),
            const SizedBox(height: 8),
            const _MockSession(
              exercise: 'Boxing jab',
              details: '24 cycles · 10 min',
              date: 'Yesterday',
            ),
          ],
        ),
      ),
    );
  }
}

class _MockStat extends StatelessWidget {
  final String value;
  final String label;

  const _MockStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cyanGlow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MockSession extends StatelessWidget {
  final String exercise;
  final String details;
  final String date;

  const _MockSession({
    required this.exercise,
    required this.details,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
