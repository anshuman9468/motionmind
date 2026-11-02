import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/preview_badge.dart';

/// Shows an explicitly labelled preview until verified movement history is
/// available for this profile.
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Example movement profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                PreviewBadge(),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Illustrative insights show how verified sessions can appear here.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Latest preview session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 14),
                  _InsightRow(label: 'Exercise', value: 'Squats'),
                  _InsightRow(label: 'Knee angle range', value: '108°–171°'),
                  _InsightRow(label: 'Movement control', value: 'Steady'),
                  _InsightRow(label: 'Tracking quality', value: 'Good'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.amberWarning,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Preview values are not your measurements and do not affect scores or coaching.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
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
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;

  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cyanGlow,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
