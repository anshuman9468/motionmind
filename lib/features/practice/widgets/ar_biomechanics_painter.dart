import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/skill_biomechanics.dart';
import '../services/biomechanics_engine.dart';

class ARBiomechanicsPainter extends CustomPainter {
  final HumanTrackingPayload payload;
  final BiomechanicsEvaluationFrame evaluation;
  final SkillMovementPhase currentPhase;
  final bool isGhostModeEnabled;
  final bool isReplayModeEnabled;
  final double pulseProgress;

  ARBiomechanicsPainter({
    required this.payload,
    required this.evaluation,
    required this.currentPhase,
    required this.isGhostModeEnabled,
    required this.isReplayModeEnabled,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!payload.humanDetected || payload.joints.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scaleX = size.width * 0.45;
    final scaleY = size.height * 0.45;

    Offset map3D(Joint3DPoint p) {
      return Offset(center.dx + (p.x * scaleX), center.dy - (p.y * scaleY));
    }

    final joints = payload.joints;
    final head = map3D(joints['head'] ?? const Joint3DPoint(x: 0, y: 0.85, z: 0));
    final neck = map3D(joints['neck'] ?? const Joint3DPoint(x: 0, y: 0.70, z: 0));
    final lShoulder = map3D(joints['leftShoulder'] ?? const Joint3DPoint(x: -0.22, y: 0.65, z: 0));
    final rShoulder = map3D(joints['rightShoulder'] ?? const Joint3DPoint(x: 0.22, y: 0.65, z: 0));
    final lElbow = map3D(joints['leftElbow'] ?? const Joint3DPoint(x: -0.38, y: 0.35, z: 0.05));
    final lWrist = map3D(joints['leftWrist'] ?? const Joint3DPoint(x: -0.45, y: 0.10, z: 0.10));
    final rElbow = map3D(joints['rightElbow'] ?? const Joint3DPoint(x: 0.38, y: 0.35, z: 0.05));
    final rWrist = map3D(joints['rightWrist'] ?? const Joint3DPoint(x: 0.45, y: 0.10, z: 0.10));
    final spine = map3D(joints['spine'] ?? const Joint3DPoint(x: 0, y: 0.30, z: 0));
    final lHip = map3D(joints['leftHip'] ?? const Joint3DPoint(x: -0.15, y: 0.10, z: 0));
    final rHip = map3D(joints['rightHip'] ?? const Joint3DPoint(x: 0.15, y: 0.10, z: 0));
    final lKnee = map3D(joints['leftKnee'] ?? const Joint3DPoint(x: -0.18, y: -0.30, z: -0.05));
    final rKnee = map3D(joints['rightKnee'] ?? const Joint3DPoint(x: 0.18, y: -0.30, z: -0.05));
    final lAnkle = map3D(joints['leftAnkle'] ?? const Joint3DPoint(x: -0.20, y: -0.70, z: 0));
    final rAnkle = map3D(joints['rightAnkle'] ?? const Joint3DPoint(x: 0.20, y: -0.70, z: 0));

    final themeColor = _getOverallSeverityColor(evaluation);

    // 1. Classify Dynamic Human Action (Sitting, Standing, Walking, Running, Jumping, Squatting)
    final lKneeAngle = BiomechanicsEngine.calculate3DAngle(
      joints['leftHip'] ?? const Joint3DPoint(x: -0.15, y: 0.10, z: 0),
      joints['leftKnee'] ?? const Joint3DPoint(x: -0.18, y: -0.30, z: -0.05),
      joints['leftAnkle'] ?? const Joint3DPoint(x: -0.20, y: -0.70, z: 0),
    );

    String actionLabel = 'STANDING POSTURE';
    if (lKneeAngle < 98.0) {
      actionLabel = 'SITTING / DESK POSTURE';
    } else if (lKneeAngle < 115.0) {
      actionLabel = 'SQUAT / CROUCH LOAD';
    } else if (lKneeAngle < 145.0) {
      actionLabel = 'WALKING / RUNNING CADENCE';
    }

    // 2. Draw Dynamic Laser Sweep Line
    final scanY = (head.dy - 30) + (pulseProgress * (rAnkle.dy - head.dy + 60));
    final laserPaint = Paint()
      ..color = AppColors.cyanGlow
      ..strokeWidth = 2.5;
    final laserGlowPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.15)
      ..strokeWidth = 12.0;

    canvas.drawLine(Offset(size.width * 0.1, scanY), Offset(size.width * 0.9, scanY), laserGlowPaint);
    canvas.drawLine(Offset(size.width * 0.1, scanY), Offset(size.width * 0.9, scanY), laserPaint);

    // 3. Volumetric Chest Cage Wireframe Box
    final chestPath = Path()
      ..moveTo(lShoulder.dx, lShoulder.dy)
      ..lineTo(rShoulder.dx, rShoulder.dy)
      ..lineTo(rHip.dx, rHip.dy)
      ..lineTo(lHip.dx, lHip.dy)
      ..close();

    final chestGridPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final chestBorderPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(chestPath, chestGridPaint);
    canvas.drawPath(chestPath, chestBorderPaint);
    canvas.drawLine(lShoulder, rHip, chestBorderPaint);
    canvas.drawLine(rShoulder, lHip, chestBorderPaint);

    // 4. Ghost Target Overlay
    if (isGhostModeEnabled) {
      final ghostPaint = Paint()
        ..color = AppColors.cyanGlow.withValues(alpha: 0.35)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;

      final gElbowL = Offset(lShoulder.dx - 55, lShoulder.dy + 55);
      final gWristL = Offset(gElbowL.dx - 50, gElbowL.dy + 30);
      final gKneeL = Offset(lHip.dx - 20, lHip.dy + 80);
      final gAnkleL = Offset(gKneeL.dx - 15, gKneeL.dy + 75);

      canvas.drawLine(head, neck, ghostPaint);
      canvas.drawLine(neck, spine, ghostPaint);
      canvas.drawLine(lShoulder, gElbowL, ghostPaint);
      canvas.drawLine(gElbowL, gWristL, ghostPaint);
      canvas.drawLine(lHip, gKneeL, ghostPaint);
      canvas.drawLine(gKneeL, gAnkleL, ghostPaint);
    }

    // 5. Draw Dual-Layered Volumetric Glowing Bone Tubes
    void drawVolumetricBone(Offset from, Offset to) {
      // Outer Neon Glow Halo
      final outerGlow = Paint()
        ..color = themeColor.withValues(alpha: 0.25)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round;

      // Inner Core Bone Tube
      final innerCore = Paint()
        ..color = themeColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(from, to, outerGlow);
      canvas.drawLine(from, to, innerCore);
    }

    drawVolumetricBone(head, neck);
    drawVolumetricBone(neck, spine);
    drawVolumetricBone(neck, lShoulder);
    drawVolumetricBone(neck, rShoulder);

    drawVolumetricBone(lShoulder, lElbow);
    drawVolumetricBone(lElbow, lWrist);
    drawVolumetricBone(rShoulder, rElbow);
    drawVolumetricBone(rElbow, rWrist);

    drawVolumetricBone(spine, lHip);
    drawVolumetricBone(spine, rHip);
    drawVolumetricBone(lHip, rHip);

    drawVolumetricBone(lHip, lKnee);
    drawVolumetricBone(lKnee, lAnkle);
    drawVolumetricBone(rHip, rKnee);
    drawVolumetricBone(rKnee, rAnkle);

    // 6. Holographic Head Synapse Scanner
    canvas.drawCircle(head, 24 + (pulseProgress * 6), Paint()..color = AppColors.cyanGlow.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(head, 14, Paint()..color = AppColors.cyanGlow.withValues(alpha: 0.3)..style = PaintingStyle.fill);

    // 7. Volumetric Spherical Joint Nodes
    final allJoints = [head, neck, lShoulder, rShoulder, lElbow, lWrist, rElbow, rWrist, spine, lHip, rHip, lKnee, lAnkle, rKnee, rAnkle];
    for (final j in allJoints) {
      final sphereGlow = Paint()
        ..color = themeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final sphereCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(j, 10 + (pulseProgress * 4), sphereGlow);
      canvas.drawCircle(j, 5, sphereCore);
    }

    // 8. Render AR 3D Directional Correction Prompts directly attached to joints
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawARCorrectionTag(String text, BiomechanicalErrorSeverity severity, Offset jointPos, Offset offset) {
      Color c;
      switch (severity) {
        case BiomechanicalErrorSeverity.green:
          c = AppColors.emeraldGreen;
          break;
        case BiomechanicalErrorSeverity.yellow:
          c = Colors.amber;
          break;
        case BiomechanicalErrorSeverity.red:
          c = AppColors.roseError;
          break;
      }

      final tagPos = Offset(jointPos.dx + offset.dx, jointPos.dy + offset.dy);

      canvas.drawLine(
        jointPos,
        tagPos,
        Paint()..color = c.withValues(alpha: 0.8)..strokeWidth = 1.5,
      );
      canvas.drawCircle(jointPos, 6, Paint()..color = c..style = PaintingStyle.fill);

      tp.text = TextSpan(
        text: ' $text ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          background: Paint()..color = c.withValues(alpha: 0.95)..style = PaintingStyle.fill,
        ),
      );
      tp.layout();
      tp.paint(canvas, tagPos);
    }

    // AR Tags
    final elbowRes = evaluation.jointResults['elbow'];
    if (elbowRes != null) {
      drawARCorrectionTag(
        '${elbowRes.correctionPrompt} [${elbowRes.currentAngle.toInt()}°]',
        elbowRes.severity,
        lElbow,
        const Offset(-130, -20),
      );
    }

    final kneeRes = evaluation.jointResults['knee'];
    if (kneeRes != null) {
      drawARCorrectionTag(
        '${kneeRes.correctionPrompt} [${kneeRes.currentAngle.toInt()}°]',
        kneeRes.severity,
        lKnee,
        const Offset(20, -10),
      );
    }

    final torsoRes = evaluation.jointResults['torso'];
    if (torsoRes != null) {
      drawARCorrectionTag(
        '${torsoRes.correctionPrompt} [Torso: ${evaluation.torsoInclination.toInt()}°]',
        torsoRes.severity,
        spine,
        const Offset(24, 15),
      );
    }

    // Dynamic Action Badge over head
    tp.text = TextSpan(
      text: ' ⚡ DYNAMIC ACTION: $actionLabel ',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 10,
        background: Paint()..color = AppColors.primaryBlue..style = PaintingStyle.fill,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(head.dx - (tp.width / 2), head.dy - 40));

    // Heatmap in Replay mode
    if (isReplayModeEnabled) {
      final heatPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.red.withValues(alpha: 0.6),
            Colors.orange.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: lElbow, radius: 45))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(lElbow, 45, heatPaint);
    }
  }

  Color _getOverallSeverityColor(BiomechanicsEvaluationFrame eval) {
    if (eval.overallTechniqueScore >= 85) return AppColors.emeraldGreen;
    if (eval.overallTechniqueScore >= 70) return AppColors.primaryBlue;
    return AppColors.roseError;
  }

  @override
  bool shouldRepaint(covariant ARBiomechanicsPainter oldDelegate) {
    return oldDelegate.payload.trackingConfidence != payload.trackingConfidence ||
        oldDelegate.evaluation.overallTechniqueScore != evaluation.overallTechniqueScore ||
        oldDelegate.currentPhase.name != currentPhase.name ||
        oldDelegate.isGhostModeEnabled != isGhostModeEnabled ||
        oldDelegate.isReplayModeEnabled != isReplayModeEnabled ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
