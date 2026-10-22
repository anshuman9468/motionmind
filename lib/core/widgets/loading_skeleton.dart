import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import 'glass_container.dart';

class LoadingSkeletonCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const LoadingSkeletonCard({
    super.key,
    this.height = 140,
    this.width = double.infinity,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface.withValues(alpha: 0.6),
      highlightColor: AppColors.surfaceLight.withValues(alpha: 0.8),
      child: GlassContainer(
        height: height,
        width: width,
        borderRadius: borderRadius,
        child: const SizedBox.expand(),
      ),
    );
  }
}
