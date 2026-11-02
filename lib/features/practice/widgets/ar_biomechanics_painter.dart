import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/skill_biomechanics.dart';
import '../services/biomechanics_engine.dart';

enum PoseOverlayMode { off, minimal, fullSkeleton }

/// Renders only landmarks supplied by the native tracker. Ghost mode is a
/// visual reference overlay; it is never used as a measurement input.
class ARBiomechanicsPainter extends CustomPainter {
  final HumanTrackingPayload payload;
  final BiomechanicsEvaluationFrame evaluation;
  final SkillMovementPhase currentPhase;
  final bool isGhostModeEnabled;
  final bool isReplayModeEnabled;
  final PoseOverlayMode overlayMode;
  final double pulseProgress;

  ARBiomechanicsPainter({
    required this.payload,
    required this.evaluation,
    required this.currentPhase,
    required this.isGhostModeEnabled,
    required this.isReplayModeEnabled,
    this.overlayMode = PoseOverlayMode.minimal,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayMode == PoseOverlayMode.off ||
        !payload.humanDetected ||
        payload.joints.isEmpty)
      return;

    final joints = payload.joints;
    final center = Offset(size.width / 2, size.height / 2);
    final scaleX = size.width * 0.45;
    final scaleY = size.height * 0.45;

    Offset mapPoint(Joint3DPoint point) {
      // Native MediaPipe coordinates are normalized image coordinates. Keep a
      // compatibility branch for older named-joint payloads using [-1, 1].
      if (payload.coordinateSpace == 'normalized_image' &&
          point.x >= 0 &&
          point.x <= 1 &&
          point.y >= 0 &&
          point.y <= 1) {
        return Offset(point.x * size.width, point.y * size.height);
      }
      return Offset(center.dx + point.x * scaleX, center.dy - point.y * scaleY);
    }

    Offset? point(String name) {
      final value = joints[name];
      return value == null ? null : mapPoint(value);
    }

    final head = point('head');
    final leftShoulder = point('leftShoulder');
    final rightShoulder = point('rightShoulder');
    final leftElbow = point('leftElbow');
    final rightElbow = point('rightElbow');
    final leftWrist = point('leftWrist');
    final rightWrist = point('rightWrist');
    final leftHip = point('leftHip');
    final rightHip = point('rightHip');
    final leftKnee = point('leftKnee');
    final rightKnee = point('rightKnee');
    final leftAnkle = point('leftAnkle');
    final rightAnkle = point('rightAnkle');
    final torso =
        leftShoulder != null &&
            rightShoulder != null &&
            leftHip != null &&
            rightHip != null
        ? Offset(
            (leftShoulder.dx + rightShoulder.dx + leftHip.dx + rightHip.dx) / 4,
            (leftShoulder.dy + rightShoulder.dy + leftHip.dy + rightHip.dy) / 4,
          )
        : null;

    final themeColor = _getOverallSeverityColor(evaluation);
    final kneeAngle =
        joints['leftHip'] != null &&
            joints['leftKnee'] != null &&
            joints['leftAnkle'] != null
        ? BiomechanicsEngine.calculateAngle(
            joints['leftHip']!,
            joints['leftKnee']!,
            joints['leftAnkle']!,
            coordinateSpace: payload.coordinateSpace,
          )
        : null;
    final actionLabel = kneeAngle == null
        ? 'POSE DATA INCOMPLETE'
        : kneeAngle < 98
        ? 'SITTING / DESK POSTURE'
        : kneeAngle < 115
        ? 'SQUAT / CROUCH LOAD'
        : kneeAngle < 145
        ? 'WALKING / RUNNING CADENCE'
        : 'STANDING POSTURE';

    final bodyPoints = [
      head,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftWrist,
      rightWrist,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ].whereType<Offset>().toList();
    if (overlayMode == PoseOverlayMode.minimal) {
      // Keep the default camera view calm: only show the body region involved
      // in a verified correction. Tracking continues regardless of overlay.
      final guide = evaluation.jointResults['knee']?.currentAngle != null
          ? <Offset?>[leftHip, leftKnee, leftAnkle]
          : evaluation.jointResults['elbow']?.currentAngle != null
          ? <Offset?>[leftShoulder, leftElbow, leftWrist]
          : <Offset?>[torso, leftShoulder, rightShoulder, leftHip, rightHip];
      final guidePoints = guide.whereType<Offset>().toList(growable: false);
      final guidePaint = Paint()
        ..color = themeColor.withValues(alpha: .8)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < guidePoints.length; i++) {
        canvas.drawLine(guidePoints[i - 1], guidePoints[i], guidePaint);
      }
      for (final point in guidePoints) {
        canvas.drawCircle(point, 4, Paint()..color = themeColor);
      }
      return;
    }

    final scanTop = bodyPoints.isEmpty
        ? 0.0
        : bodyPoints.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final scanBottom = bodyPoints.isEmpty
        ? size.height
        : bodyPoints.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final scanY = scanTop + pulseProgress * (scanBottom - scanTop);
    final laserGlowPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.15)
      ..strokeWidth = 12;
    final laserPaint = Paint()
      ..color = AppColors.cyanGlow
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(size.width * .1, scanY),
      Offset(size.width * .9, scanY),
      laserGlowPaint,
    );
    canvas.drawLine(
      Offset(size.width * .1, scanY),
      Offset(size.width * .9, scanY),
      laserPaint,
    );

    void drawBone(Offset? from, Offset? to) {
      if (from == null || to == null) return;
      final outer = Paint()
        ..color = themeColor.withValues(alpha: .25)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      final inner = Paint()
        ..color = themeColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to, outer);
      canvas.drawLine(from, to, inner);
    }

    drawBone(leftShoulder, rightShoulder);
    drawBone(leftHip, rightHip);
    drawBone(leftShoulder, leftElbow);
    drawBone(leftElbow, leftWrist);
    drawBone(rightShoulder, rightElbow);
    drawBone(rightElbow, rightWrist);
    drawBone(leftShoulder, leftHip);
    drawBone(rightShoulder, rightHip);
    drawBone(leftHip, leftKnee);
    drawBone(leftKnee, leftAnkle);
    drawBone(rightHip, rightKnee);
    drawBone(rightKnee, rightAnkle);

    if (isGhostModeEnabled &&
        leftHip != null &&
        leftKnee != null &&
        leftAnkle != null) {
      final ghostPaint = Paint()
        ..color = AppColors.cyanGlow.withValues(alpha: .35)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(leftHip, leftKnee, ghostPaint);
      canvas.drawLine(leftKnee, leftAnkle, ghostPaint);
    }

    if (head != null) {
      canvas.drawCircle(
        head,
        24 + pulseProgress * 6,
        Paint()
          ..color = AppColors.cyanGlow.withValues(alpha: .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        head,
        14,
        Paint()..color = AppColors.cyanGlow.withValues(alpha: .3),
      );
    }
    for (final joint in bodyPoints) {
      canvas.drawCircle(
        joint,
        10 + pulseProgress * 4,
        Paint()..color = themeColor.withValues(alpha: .35),
      );
      canvas.drawCircle(joint, 5, Paint()..color = Colors.white);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawTag(
      String text,
      BiomechanicalErrorSeverity severity,
      Offset? joint,
      Offset offset,
    ) {
      if (joint == null || severity == BiomechanicalErrorSeverity.unavailable)
        return;
      final color = switch (severity) {
        BiomechanicalErrorSeverity.green => AppColors.emeraldGreen,
        BiomechanicalErrorSeverity.yellow => Colors.amber,
        BiomechanicalErrorSeverity.red => AppColors.roseError,
        BiomechanicalErrorSeverity.unavailable => AppColors.textMuted,
      };
      final tagPosition = joint + offset;
      canvas.drawLine(
        joint,
        tagPosition,
        Paint()
          ..color = color.withValues(alpha: .8)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(joint, 6, Paint()..color = color);
      textPainter.text = TextSpan(
        text: ' $text ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          background: Paint()..color = color.withValues(alpha: .95),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, tagPosition);
    }

    final elbow = evaluation.jointResults['elbow'];
    if (elbow?.currentAngle != null) {
      drawTag(
        '${elbow!.correctionPrompt} [${elbow.currentAngle!.toInt()}°]',
        elbow.severity,
        leftElbow,
        const Offset(-130, -20),
      );
    }
    final knee = evaluation.jointResults['knee'];
    if (knee?.currentAngle != null) {
      drawTag(
        '${knee!.correctionPrompt} [${knee.currentAngle!.toInt()}°]',
        knee.severity,
        leftKnee,
        const Offset(20, -10),
      );
    }
    final torsoResult = evaluation.jointResults['torso'];
    if (torsoResult?.currentAngle != null) {
      drawTag(
        '${torsoResult!.correctionPrompt} [Torso: ${evaluation.torsoInclination!.toInt()}°]',
        torsoResult.severity,
        torso,
        const Offset(24, 15),
      );
    }

    if (head != null) {
      textPainter.text = TextSpan(
        text: ' ⚡ DYNAMIC ACTION: $actionLabel ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          background: Paint()..color = AppColors.primaryBlue,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(head.dx - textPainter.width / 2, head.dy - 40),
      );
    }

    if (isReplayModeEnabled && leftElbow != null) {
      final heatPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.red.withValues(alpha: .6),
            Colors.orange.withValues(alpha: .3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: leftElbow, radius: 45));
      canvas.drawCircle(leftElbow, 45, heatPaint);
    }
  }

  Color _getOverallSeverityColor(BiomechanicsEvaluationFrame eval) {
    if (!eval.techniqueEvaluationAvailable ||
        eval.overallTechniqueScore == null) {
      return AppColors.textMuted;
    }
    if (eval.overallTechniqueScore! >= 85) return AppColors.emeraldGreen;
    if (eval.overallTechniqueScore! >= 70) return AppColors.primaryBlue;
    return AppColors.roseError;
  }

  @override
  bool shouldRepaint(covariant ARBiomechanicsPainter oldDelegate) {
    return oldDelegate.payload.timestampUs != payload.timestampUs ||
        oldDelegate.evaluation.status != evaluation.status ||
        oldDelegate.evaluation.overallTechniqueScore !=
            evaluation.overallTechniqueScore ||
        oldDelegate.currentPhase.name != currentPhase.name ||
        oldDelegate.isGhostModeEnabled != isGhostModeEnabled ||
        oldDelegate.isReplayModeEnabled != isReplayModeEnabled ||
        oldDelegate.overlayMode != overlayMode ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
