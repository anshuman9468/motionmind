import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DigitalTwinRadarChart extends StatefulWidget {
  final Map<String, double> metrics; // Scale 0.0 to 1.0
  final double size;

  const DigitalTwinRadarChart({
    super.key,
    required this.metrics,
    this.size = 280,
  });

  @override
  State<DigitalTwinRadarChart> createState() => _DigitalTwinRadarChartState();
}

class _DigitalTwinRadarChartState extends State<DigitalTwinRadarChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final animatedMetrics = widget.metrics.map(
            (key, val) => MapEntry(key, val * _animation.value),
          );
          return CustomPaint(
            painter: RadarChartPainter(metrics: animatedMetrics),
          );
        },
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
    final radius = math.min(size.width, size.height) / 3.0; // Shrink radius slightly to leave space for labels
    final keys = metrics.keys.toList();
    final count = keys.length;

    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.15) // Golden translucency
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.primaryBlue // Olympian Gold line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final pointPaint = Paint()
      ..color = AppColors.cyanGlow // Pure Pentelic Marble dot
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
      // Subtle glow behind the point
      canvas.drawCircle(p, 8.0, Paint()..color = AppColors.cyanGlow.withValues(alpha: 0.15)..style = PaintingStyle.fill);
    }

    // Draw text labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final labelRadius = radius + 22.0; // Distance of text from center
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      // We wrap the labels to avoid text overlapping or clipping
      String labelText = keys[i];
      if (labelText.contains('&')) {
        labelText = labelText.replaceAll(' & ', '\n& ');
      }

      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();

      // Calculate offset so text is centered on the point (x, y)
      final textOffset = Offset(
        x - textPainter.width / 2,
        y - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) => true;
}
