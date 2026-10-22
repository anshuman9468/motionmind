import 'dart:math' as math;
import '../models/skill_biomechanics.dart';

enum BiomechanicalErrorSeverity {
  green,  // Within target range
  yellow, // Minor deviation (1° - 15° outside range)
  red,    // Major deviation (> 15° outside range)
}

class JointEvaluationResult {
  final String jointName;
  final double currentAngle;
  final double targetAngle;
  final double angleDifference;
  final BiomechanicalErrorSeverity severity;
  final String correctionPrompt;
  final double confidence;

  const JointEvaluationResult({
    required this.jointName,
    required this.currentAngle,
    required this.targetAngle,
    required this.angleDifference,
    required this.severity,
    required this.correctionPrompt,
    required this.confidence,
  });
}

class BiomechanicsEvaluationFrame {
  final bool isHumanDetected;
  final HumanDetectionState trackingState;
  final double overallTechniqueScore;
  final double torsoInclination;
  final double limbSymmetryScore;
  final Map<String, JointEvaluationResult> jointResults;
  final String primaryInstruction;

  const BiomechanicsEvaluationFrame({
    required this.isHumanDetected,
    required this.trackingState,
    required this.overallTechniqueScore,
    required this.torsoInclination,
    required this.limbSymmetryScore,
    required this.jointResults,
    required this.primaryInstruction,
  });
}

class BiomechanicsEngine {
  /// Calculate 3D angle between three points: P1 (origin node), P2 (joint vertex), P3 (terminal node)
  static double calculate3DAngle(Joint3DPoint p1, Joint3DPoint p2, Joint3DPoint p3) {
    final v1x = p1.x - p2.x;
    final v1y = p1.y - p2.y;
    final v1z = p1.z - p2.z;

    final v2x = p3.x - p2.x;
    final v2y = p3.y - p2.y;
    final v2z = p3.z - p2.z;

    final dotProduct = (v1x * v2x) + (v1y * v2y) + (v1z * v2z);
    final mag1 = math.sqrt((v1x * v1x) + (v1y * v1y) + (v1z * v1z));
    final mag2 = math.sqrt((v2x * v2x) + (v2y * v2y) + (v2z * v2z));

    if (mag1 == 0 || mag2 == 0) return 0.0;

    double cosTheta = dotProduct / (mag1 * mag2);
    // Clamp to [-1.0, 1.0] to prevent NaN from precision errors
    cosTheta = math.max(-1.0, math.min(1.0, cosTheta));

    final rad = math.acos(cosTheta);
    return (rad * 180.0) / math.pi;
  }

  /// Calculate Torso inclination angle relative to pure vertical axis (0, 1, 0)
  static double calculateTorsoInclination(Joint3DPoint spine, Joint3DPoint neck) {
    final dx = neck.x - spine.x;
    final dy = neck.y - spine.y;
    final dz = neck.z - spine.z;

    final mag = math.sqrt((dx * dx) + (dy * dy) + (dz * dz));
    if (mag == 0) return 180.0;

    final cosTheta = dy / mag;
    final clamped = math.max(-1.0, math.min(1.0, cosTheta));
    return (math.acos(clamped) * 180.0) / math.pi;
  }

  /// Calculate Left/Right limb symmetry ratio (1.0 = perfect symmetry)
  static double calculateLimbSymmetry(double leftAngle, double rightAngle) {
    final diff = (leftAngle - rightAngle).abs();
    final symmetry = 1.0 - (diff / 180.0);
    return math.max(0.0, math.min(1.0, symmetry));
  }

  /// Evaluate frame joint telemetry against target phase
  static BiomechanicsEvaluationFrame evaluateFrame({
    required HumanTrackingPayload payload,
    required SkillMovementPhase phaseTarget,
  }) {
    if (!payload.humanDetected || payload.joints.isEmpty) {
      return BiomechanicsEvaluationFrame(
        isHumanDetected: false,
        trackingState: payload.trackingState,
        overallTechniqueScore: 0.0,
        torsoInclination: 0.0,
        limbSymmetryScore: 0.0,
        jointResults: const {},
        primaryInstruction: 'SEARCHING FOR HUMAN IN FRAME...',
      );
    }

    final joints = payload.joints;
    final neck = joints['neck'] ?? const Joint3DPoint(x: 0, y: 0.70, z: 0);
    final lShoulder = joints['leftShoulder'] ?? const Joint3DPoint(x: -0.22, y: 0.65, z: 0);
    final lElbow = joints['leftElbow'] ?? const Joint3DPoint(x: -0.38, y: 0.35, z: 0.05);
    final lWrist = joints['leftWrist'] ?? const Joint3DPoint(x: -0.45, y: 0.10, z: 0.10);
    final spine = joints['spine'] ?? const Joint3DPoint(x: 0, y: 0.30, z: 0);
    final lHip = joints['leftHip'] ?? const Joint3DPoint(x: -0.15, y: 0.10, z: 0);
    final rHip = joints['rightHip'] ?? const Joint3DPoint(x: 0.15, y: 0.10, z: 0);
    final lKnee = joints['leftKnee'] ?? const Joint3DPoint(x: -0.18, y: -0.30, z: -0.05);
    final rKnee = joints['rightKnee'] ?? const Joint3DPoint(x: 0.18, y: -0.30, z: -0.05);
    final lAnkle = joints['leftAnkle'] ?? const Joint3DPoint(x: -0.20, y: -0.70, z: 0);
    final rAnkle = joints['rightAnkle'] ?? const Joint3DPoint(x: 0.20, y: -0.70, z: 0);

    // Calculate actual 3D joint angles
    final lElbowAngle = calculate3DAngle(lShoulder, lElbow, lWrist);
    final lKneeAngle = calculate3DAngle(lHip, lKnee, lAnkle);
    final rKneeAngle = calculate3DAngle(rHip, rKnee, rAnkle);
    final torsoAngle = calculateTorsoInclination(spine, neck);
    final symmetryScore = calculateLimbSymmetry(lKneeAngle, rKneeAngle);

    final Map<String, JointEvaluationResult> jointResults = {};
    double totalDeduction = 0.0;
    String topCorrection = 'HUMAN LOCKED: STANCE ALIGNED ✓';

    for (final entry in phaseTarget.targets.entries) {
      final key = entry.key;
      final targetSpec = entry.value;

      double currentVal = 0.0;
      double jointConf = 1.0;

      if (key == 'elbow') {
        currentVal = lElbowAngle;
        jointConf = (lShoulder.confidence + lElbow.confidence + lWrist.confidence) / 3.0;
      } else if (key == 'knee') {
        currentVal = lKneeAngle;
        jointConf = (lHip.confidence + lKnee.confidence + lAnkle.confidence) / 3.0;
      } else if (key == 'torso') {
        currentVal = torsoAngle;
        jointConf = (spine.confidence + neck.confidence) / 2.0;
      } else if (key == 'hip') {
        currentVal = calculate3DAngle(lShoulder, lHip, lKnee);
        jointConf = (lShoulder.confidence + lHip.confidence + lKnee.confidence) / 3.0;
      } else {
        currentVal = lElbowAngle;
      }

      // Do NOT trigger corrections if joint confidence is too low (< 0.60)
      if (jointConf < 0.60) {
        jointResults[key] = JointEvaluationResult(
          jointName: targetSpec.jointName,
          currentAngle: currentVal,
          targetAngle: targetSpec.targetAngle,
          angleDifference: 0.0,
          severity: BiomechanicalErrorSeverity.green,
          correctionPrompt: 'JOINT NOT VISIBLE',
          confidence: jointConf,
        );
        continue;
      }

      final diff = currentVal - targetSpec.targetAngle;
      final absDiff = diff.abs();

      BiomechanicalErrorSeverity severity;
      String prompt;

      if (currentVal >= targetSpec.minAcceptableAngle && currentVal <= targetSpec.maxAcceptableAngle) {
        severity = BiomechanicalErrorSeverity.green;
        prompt = '${targetSpec.jointName.toUpperCase()} ALIGNED ✓';
      } else if (absDiff <= 15.0) {
        severity = BiomechanicalErrorSeverity.yellow;
        final delta = absDiff.toInt();
        prompt = diff < 0 ? '${targetSpec.increasePrompt} $delta°' : '${targetSpec.decreasePrompt} $delta°';
        totalDeduction += 6.0;
        topCorrection = prompt;
      } else {
        severity = BiomechanicalErrorSeverity.red;
        final delta = absDiff.toInt();
        prompt = diff < 0 ? '${targetSpec.increasePrompt} $delta°' : '${targetSpec.decreasePrompt} $delta°';
        totalDeduction += 15.0;
        topCorrection = prompt;
      }

      jointResults[key] = JointEvaluationResult(
        jointName: targetSpec.jointName,
        currentAngle: currentVal,
        targetAngle: targetSpec.targetAngle,
        angleDifference: diff,
        severity: severity,
        correctionPrompt: prompt,
        confidence: jointConf,
      );
    }

    final score = math.max(0.0, math.min(100.0, 100.0 - totalDeduction));

    return BiomechanicsEvaluationFrame(
      isHumanDetected: true,
      trackingState: payload.trackingState,
      overallTechniqueScore: score,
      torsoInclination: torsoAngle,
      limbSymmetryScore: symmetryScore,
      jointResults: jointResults,
      primaryInstruction: topCorrection,
    );
  }
}
