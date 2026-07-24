import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DigitalTwinRadarChart extends StatelessWidget {
  final Map<String, double> metrics; // Scale 0.0 to 1.0
  final double size;

  const DigitalTwinRadarChart({
    super.key,
    required this.metrics,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RadarChartPainter(metrics: metrics),
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final Map<String, double> metrics;

  RadarChartPainter({required this.metrics});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.6;
    final keys = metrics.keys.toList();
    final count = keys.length;

    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.cyanGlow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final pointPaint = Paint()
      ..color = AppColors.emeraldGreen
      ..style = PaintingStyle.fill;

    // Draw grid webs (levels 0.2, 0.4, 0.6, 0.8, 1.0)
    for (int step = 1; step <= 5; step++) {
      final r = radius * (step / 5);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = (2 * math.pi / count) * i - (math.pi / 2);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw radial axes lines
    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // Draw metric polygon
    final polyPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final val = metrics[keys[i]] ?? 0.5;
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final r = radius * val.clamp(0.1, 1.0);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final point = Offset(x, y);
      points.add(point);
      if (i == 0) {
        polyPath.moveTo(x, y);
      } else {
        polyPath.lineTo(x, y);
      }
    }
    polyPath.close();

    canvas.drawPath(polyPath, fillPaint);
    canvas.drawPath(polyPath, linePaint);

    // Draw vertex dots
    for (final p in points) {
      canvas.drawCircle(p, 4.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) => true;
}
