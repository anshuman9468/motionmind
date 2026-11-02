import 'dart:math' as math;

import '../models/skill_biomechanics.dart';

/// A local mirror of the versioned backend quality states. The mobile engine
/// uses the same fail-closed semantics before rendering any technique result.
enum BiomechanicsEvaluationStatus {
  valid,
  lowConfidence,
  insufficientData,
  unsupportedView,
  trackingLost,
}

enum BiomechanicalErrorSeverity { unavailable, green, yellow, red }

class JointEvaluationResult {
  final String jointName;
  final double? currentAngle;
  final double targetAngle;
  final double? angleDifference;
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
  final BiomechanicsEvaluationStatus status;
  final bool techniqueEvaluationAvailable;
  final double? overallTechniqueScore;
  final double? torsoInclination;
  final double? limbSymmetryScore;
  final Map<String, JointEvaluationResult> jointResults;
  final String primaryInstruction;

  const BiomechanicsEvaluationFrame({
    required this.isHumanDetected,
    required this.trackingState,
    required this.status,
    required this.techniqueEvaluationAvailable,
    required this.overallTechniqueScore,
    required this.torsoInclination,
    required this.limbSymmetryScore,
    required this.jointResults,
    required this.primaryInstruction,
  });
}

class BiomechanicsEngine {
  /// Initial heuristic gate; keep configurable when exercise-specific mobile
  /// profiles are introduced. This is not a validated accuracy threshold.
  static const localConfidenceThreshold = 0.60;

  static bool _finite(double value) => value.isFinite;

  /// Returns angle ABC in degrees. Normalized-image landmarks intentionally
  /// use only x/y; MediaPipe normalized z is relative depth, not metric data.
  static double? calculateAngle(
    Joint3DPoint p1,
    Joint3DPoint p2,
    Joint3DPoint p3, {
    String coordinateSpace = 'normalized_image',
  }) {
    final values = [p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z];
    if (values.any((value) => !_finite(value))) return null;

    final useWorld = coordinateSpace == 'world';
    final v1 = <double>[p1.x - p2.x, p1.y - p2.y, if (useWorld) p1.z - p2.z];
    final v2 = <double>[p3.x - p2.x, p3.y - p2.y, if (useWorld) p3.z - p2.z];
    final mag1 = math.sqrt(
      v1.fold<double>(0, (sum, value) => sum + value * value),
    );
    final mag2 = math.sqrt(
      v2.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (mag1 <= 1e-8 || mag2 <= 1e-8) return null;
    final dot = v1.asMap().entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value * v2[entry.key],
    );
    final cosine = (dot / (mag1 * mag2)).clamp(-1.0, 1.0).toDouble();
    final result = math.acos(cosine) * 180.0 / math.pi;
    return result.isFinite ? double.parse(result.toStringAsFixed(3)) : null;
  }

  /// Backwards-compatible name retained for widgets/tests.
  static double? calculate3DAngle(
    Joint3DPoint p1,
    Joint3DPoint p2,
    Joint3DPoint p3, {
    String coordinateSpace = 'normalized_image',
  }) => calculateAngle(p1, p2, p3, coordinateSpace: coordinateSpace);

  static double? calculateTorsoInclination(
    Joint3DPoint leftShoulder,
    Joint3DPoint rightShoulder,
    Joint3DPoint leftHip,
    Joint3DPoint rightHip, {
    String coordinateSpace = 'normalized_image',
  }) {
    final shoulder = Joint3DPoint(
      x: (leftShoulder.x + rightShoulder.x) / 2,
      y: (leftShoulder.y + rightShoulder.y) / 2,
      z: (leftShoulder.z + rightShoulder.z) / 2,
      confidence: math
          .min(leftShoulder.confidence, rightShoulder.confidence)
          .toDouble(),
    );
    final hip = Joint3DPoint(
      x: (leftHip.x + rightHip.x) / 2,
      y: (leftHip.y + rightHip.y) / 2,
      z: (leftHip.z + rightHip.z) / 2,
      confidence: math.min(leftHip.confidence, rightHip.confidence).toDouble(),
    );
    final values = [shoulder.x, shoulder.y, shoulder.z, hip.x, hip.y, hip.z];
    if (values.any((value) => !_finite(value))) return null;
    final useWorld = coordinateSpace == 'world';
    final dx = shoulder.x - hip.x;
    final dy = shoulder.y - hip.y;
    final dz = useWorld ? shoulder.z - hip.z : 0.0;
    final magnitude = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (magnitude <= 1e-8) return null;
    final referenceY = useWorld ? 1.0 : -1.0;
    final cosine = (dy * referenceY / magnitude).clamp(-1.0, 1.0).toDouble();
    final result = math.acos(cosine) * 180.0 / math.pi;
    return result.isFinite ? double.parse(result.toStringAsFixed(3)) : null;
  }

  static double? calculateLimbSymmetry(double? leftAngle, double? rightAngle) {
    if (leftAngle == null || rightAngle == null) return null;
    final result = 1.0 - ((leftAngle - rightAngle).abs() / 180.0);
    return result.clamp(0.0, 1.0).toDouble();
  }

  static double _confidence(Iterable<Joint3DPoint> joints) {
    final values = joints
        .map(
          (joint) => joint.presence == null
              ? joint.confidence
              : math.min(joint.confidence, joint.presence!).toDouble(),
        )
        .toList();
    if (values.isEmpty || values.any((value) => !value.isFinite)) return 0.0;
    return values.reduce((a, b) => math.min(a, b).toDouble());
  }

  static BiomechanicsEvaluationFrame _unavailable({
    required HumanTrackingPayload payload,
    required BiomechanicsEvaluationStatus status,
    required String instruction,
    bool humanDetected = false,
  }) {
    return BiomechanicsEvaluationFrame(
      isHumanDetected: humanDetected,
      trackingState: payload.trackingState,
      status: status,
      techniqueEvaluationAvailable: false,
      overallTechniqueScore: null,
      torsoInclination: null,
      limbSymmetryScore: null,
      jointResults: const {},
      primaryInstruction: instruction,
    );
  }

  /// Suppress a frame-level technique score when the temporal gate rejects the
  /// sample.  The geometric engine may have enough landmarks for a snapshot,
  /// but squat coaching requires a valid timestamped temporal sample as well.
  static BiomechanicsEvaluationFrame suppressTechniqueEvaluation({
    required BiomechanicsEvaluationFrame evaluation,
    required BiomechanicsEvaluationStatus status,
    required String instruction,
  }) {
    return BiomechanicsEvaluationFrame(
      isHumanDetected: evaluation.isHumanDetected,
      trackingState: evaluation.trackingState,
      status: status,
      techniqueEvaluationAvailable: false,
      overallTechniqueScore: null,
      torsoInclination: null,
      limbSymmetryScore: null,
      jointResults: const {},
      primaryInstruction: instruction,
    );
  }

  /// Evaluates only supplied landmarks. There are no synthetic anatomical
  /// points, default angles, or green results for low-confidence joints.
  static BiomechanicsEvaluationFrame evaluateFrame({
    required HumanTrackingPayload payload,
    required SkillMovementPhase phaseTarget,
    String skillId = 'sk_3',
  }) {
    if (!payload.humanDetected ||
        payload.trackingState == HumanDetectionState.searchingForHuman) {
      return _unavailable(
        payload: payload,
        status: BiomechanicsEvaluationStatus.trackingLost,
        instruction: 'SEARCHING FOR HUMAN IN FRAME...',
      );
    }
    if (payload.trackingState == HumanDetectionState.bodyNotClear ||
        payload.trackingState == HumanDetectionState.multiplePeopleDetected) {
      return _unavailable(
        payload: payload,
        status: BiomechanicsEvaluationStatus.lowConfidence,
        instruction: 'STEP BACK AND KEEP YOUR FULL BODY CLEARLY VISIBLE.',
        humanDetected: true,
      );
    }
    final joints = payload.joints;
    Joint3DPoint? get(String name) => joints[name];
    final required = _requiredJointsForSkill(skillId);
    final missing = required.where((name) => get(name) == null).toList();
    if (missing.isNotEmpty) {
      return _unavailable(
        payload: payload,
        status: BiomechanicsEvaluationStatus.insufficientData,
        instruction: 'KEEP THE REQUIRED JOINTS VISIBLE TO CONTINUE.',
        humanDetected: true,
      );
    }
    final requiredJoints = required.map((name) => get(name)!).toList();
    final confidence = _confidence(requiredJoints);
    if (confidence < localConfidenceThreshold) {
      return _unavailable(
        payload: payload,
        status: BiomechanicsEvaluationStatus.lowConfidence,
        instruction:
            'MOVE INTO BETTER LIGHT AND KEEP THE REQUIRED JOINTS VISIBLE.',
        humanDetected: true,
      );
    }

    final coordinateSpace = payload.coordinateSpace;
    final leftElbowAngle = _angleIfPresent(
      get,
      'leftShoulder',
      'leftElbow',
      'leftWrist',
      coordinateSpace,
    );
    final rightElbowAngle = _angleIfPresent(
      get,
      'rightShoulder',
      'rightElbow',
      'rightWrist',
      coordinateSpace,
    );
    final leftKneeAngle = _angleIfPresent(
      get,
      'leftHip',
      'leftKnee',
      'leftAnkle',
      coordinateSpace,
    );
    final rightKneeAngle = _angleIfPresent(
      get,
      'rightHip',
      'rightKnee',
      'rightAnkle',
      coordinateSpace,
    );
    final leftHipAngle = _angleIfPresent(
      get,
      'leftShoulder',
      'leftHip',
      'leftKnee',
      coordinateSpace,
    );
    final rightHipAngle = _angleIfPresent(
      get,
      'rightShoulder',
      'rightHip',
      'rightKnee',
      coordinateSpace,
    );
    final torsoAngle =
        get('leftShoulder') != null &&
            get('rightShoulder') != null &&
            get('leftHip') != null &&
            get('rightHip') != null
        ? calculateTorsoInclination(
            get('leftShoulder')!,
            get('rightShoulder')!,
            get('leftHip')!,
            get('rightHip')!,
            coordinateSpace: coordinateSpace,
          )
        : null;
    final calculated = <String, double?>{
      'left_elbow_angle': leftElbowAngle,
      'right_elbow_angle': rightElbowAngle,
      'left_knee_angle': leftKneeAngle,
      'right_knee_angle': rightKneeAngle,
      'left_hip_angle': leftHipAngle,
      'right_hip_angle': rightHipAngle,
      'torso_inclination': torsoAngle,
    };
    final requiredMeasurements = _requiredMeasurementsForSkill(skillId);
    if (requiredMeasurements.any((name) => calculated[name] == null)) {
      return _unavailable(
        payload: payload,
        status: BiomechanicsEvaluationStatus.insufficientData,
        instruction:
            'HOLD A STEADY POSE SO THE REQUIRED MEASUREMENTS CAN BE CALCULATED.',
        humanDetected: true,
      );
    }

    final symmetry = calculateLimbSymmetry(leftKneeAngle, rightKneeAngle);
    final measurements = <String, double>{
      'elbow': _average(leftElbowAngle, rightElbowAngle),
      'knee': _average(leftKneeAngle, rightKneeAngle),
      'hip': _average(leftHipAngle, rightHipAngle),
      'torso': torsoAngle ?? 0.0,
    };
    final results = <String, JointEvaluationResult>{};
    var deduction = 0.0;
    var topCorrection = 'HUMAN LOCKED: MEASUREMENTS AVAILABLE ✓';
    for (final entry in phaseTarget.targets.entries) {
      final target = entry.value;
      final current = measurements[entry.key];
      if (current == null) {
        results[entry.key] = JointEvaluationResult(
          jointName: target.jointName,
          currentAngle: null,
          targetAngle: target.targetAngle,
          angleDifference: null,
          severity: BiomechanicalErrorSeverity.unavailable,
          correctionPrompt: 'MEASUREMENT UNAVAILABLE',
          confidence: 0.0,
        );
        continue;
      }
      final diff = current - target.targetAngle;
      final absDiff = diff.abs();
      final severity =
          current >= target.minAcceptableAngle &&
              current <= target.maxAcceptableAngle
          ? BiomechanicalErrorSeverity.green
          : (absDiff <= 15.0
                ? BiomechanicalErrorSeverity.yellow
                : BiomechanicalErrorSeverity.red);
      final prompt = severity == BiomechanicalErrorSeverity.green
          ? '${target.jointName.toUpperCase()} ALIGNED ✓'
          : (diff < 0
                ? '${target.increasePrompt} ${absDiff.toInt()}°'
                : '${target.decreasePrompt} ${absDiff.toInt()}°');
      if (severity == BiomechanicalErrorSeverity.yellow) {
        deduction += 6;
        topCorrection = prompt;
      } else if (severity == BiomechanicalErrorSeverity.red) {
        deduction += 15;
        topCorrection = prompt;
      }
      results[entry.key] = JointEvaluationResult(
        jointName: target.jointName,
        currentAngle: current,
        targetAngle: target.targetAngle,
        angleDifference: diff,
        severity: severity,
        correctionPrompt: prompt,
        confidence: confidence,
      );
    }
    return BiomechanicsEvaluationFrame(
      isHumanDetected: true,
      trackingState: payload.trackingState,
      status: BiomechanicsEvaluationStatus.valid,
      techniqueEvaluationAvailable: true,
      overallTechniqueScore: (100 - deduction).clamp(0.0, 100.0).toDouble(),
      torsoInclination: torsoAngle,
      limbSymmetryScore: symmetry,
      jointResults: results,
      primaryInstruction: topCorrection,
    );
  }

  static double? _angleIfPresent(
    Joint3DPoint? Function(String) get,
    String a,
    String b,
    String c,
    String coordinateSpace,
  ) {
    final p1 = get(a);
    final p2 = get(b);
    final p3 = get(c);
    if (p1 == null || p2 == null || p3 == null) return null;
    return calculateAngle(p1, p2, p3, coordinateSpace: coordinateSpace);
  }

  static double _average(double? left, double? right) {
    if (left != null && right != null) return (left + right) / 2.0;
    return left ?? right ?? 0.0;
  }

  static List<String> _requiredJointsForSkill(String skillId) {
    switch (skillId) {
      case 'squat':
      case 'sk_squat':
      case 'sk_3':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftHip',
          'rightHip',
          'leftKnee',
          'rightKnee',
          'leftAnkle',
          'rightAnkle',
        ];
      case 'push_up':
      case 'tricep_push_up':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
          'leftHip',
          'rightHip',
          'leftAnkle',
          'rightAnkle',
        ];
      case 'seated_chest_fly':
      case 'boxing_jab':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
          'leftHip',
          'rightHip',
        ];
      case 'bent_over_row':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
          'leftHip',
          'rightHip',
          'leftKnee',
          'rightKnee',
        ];
      case 'basketball_shooting':
      case 'cricket_batting':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
          'leftHip',
          'rightHip',
          'leftKnee',
          'rightKnee',
          'leftAnkle',
          'rightAnkle',
        ];
      default:
        return const ['leftShoulder', 'rightShoulder', 'leftHip', 'rightHip'];
    }
  }

  static List<String> _requiredMeasurementsForSkill(String skillId) {
    switch (skillId) {
      case 'squat':
      case 'sk_squat':
      case 'sk_3':
        return const [
          'left_knee_angle',
          'right_knee_angle',
          'torso_inclination',
        ];
      case 'push_up':
      case 'tricep_push_up':
      case 'boxing_jab':
      case 'seated_chest_fly':
        return const [
          'left_elbow_angle',
          'right_elbow_angle',
          'torso_inclination',
        ];
      case 'bent_over_row':
        return const [
          'left_elbow_angle',
          'right_elbow_angle',
          'left_hip_angle',
          'right_hip_angle',
          'torso_inclination',
        ];
      case 'basketball_shooting':
      case 'cricket_batting':
        return const [
          'left_elbow_angle',
          'right_elbow_angle',
          'left_knee_angle',
          'right_knee_angle',
          'torso_inclination',
        ];
      default:
        return const ['torso_inclination'];
    }
  }
}
