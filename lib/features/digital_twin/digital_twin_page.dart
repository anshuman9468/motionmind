import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';

/// Kept as a future-facing route, but does not present simulated competence
/// values as if they were real movement history.
class DigitalTwinPage extends StatelessWidget {
  const DigitalTwinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Movement insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insights_outlined,
                  color: AppColors.primaryBlue,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Insights will grow with your practice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete a verified session to see real movement trends. We do not fill this space with simulated scores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
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
        ),
      ),
    );
  }
}
