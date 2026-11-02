import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marks content that is intentionally illustrative and is not the user's
/// recorded history or a live community result.
class PreviewBadge extends StatelessWidget {
  final String label;

  const PreviewBadge({super.key, this.label = 'MOCK PREVIEW'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.amberWarning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.amberWarning.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.amberWarning,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
