import 'dart:math' as math;

import '../models/skill_biomechanics.dart';
import 'biomechanics_engine.dart';

/// The five observable squat phases.  Thresholds in this file are starting
/// heuristics for a side-view demo, not validated clinical targets.
enum SquatPhase { standing, descending, bottom, ascending, completedRep }

extension SquatPhaseLabel on SquatPhase {
  String get label {
    switch (this) {
      case SquatPhase.standing:
        return 'STANDING';
      case SquatPhase.descending:
        return 'DESCENDING';
      case SquatPhase.bottom:
        return 'BOTTOM';
      case SquatPhase.ascending:
        return 'ASCENDING';
      case SquatPhase.completedRep:
        return 'COMPLETED REP';
    }
  }
}

class SquatTemporalResult {
  final BiomechanicsEvaluationStatus status;
  final SquatPhase phase;
  final int repetitionCount;
  final bool completedRep;
  final double? smoothedKneeAngle;
  final String? movementDirection;
  final double? movementSpeedDegreesPerSecond;
  final double? torsoInclination;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? bilateralKneeSymmetry;
  final bool feedbackEligible;
  final List<String> verifiedFindings;
  final String message;

  const SquatTemporalResult({
    required this.status,
    required this.phase,
    required this.repetitionCount,
    required this.completedRep,
    required this.smoothedKneeAngle,
    required this.movementDirection,
    required this.movementSpeedDegreesPerSecond,
    required this.torsoInclination,
    required this.leftHipAngle,
    required this.rightHipAngle,
    required this.bilateralKneeSymmetry,
    required this.feedbackEligible,
    required this.verifiedFindings,
    required this.message,
  });

  const SquatTemporalResult.initial()
    : status = BiomechanicsEvaluationStatus.trackingLost,
      phase = SquatPhase.standing,
      repetitionCount = 0,
      completedRep = false,
      smoothedKneeAngle = null,
      movementDirection = null,
      movementSpeedDegreesPerSecond = null,
      torsoInclination = null,
      leftHipAngle = null,
      rightHipAngle = null,
      bilateralKneeSymmetry = null,
      feedbackEligible = false,
      verifiedFindings = const <String>[],
      message = 'STEP INTO A SIDE VIEW TO BEGIN SQUAT TRACKING.';
}

/// Bounded audit record retained for every accepted timestamped camera frame.
/// It contains native landmarks plus the measurements/status used by the
/// state machine; no placeholder coordinates are inserted.
class TemporalPoseSnapshot {
  final int timestampUs;
  final String? sessionId;
  final String? skillId;
  final String subjectView;
  final HumanDetectionState trackingState;
  final bool humanDetected;
  final double trackingConfidence;
  final List<MediaPipePoseLandmark> landmarks;
  final Map<String, Joint3DPoint> joints;
  final BiomechanicsEvaluationStatus? status;
  final double? leftKneeAngle;
  final double? rightKneeAngle;
  final double? torsoInclination;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? bilateralKneeSymmetry;

  const TemporalPoseSnapshot({
    required this.timestampUs,
    required this.sessionId,
    required this.skillId,
    required this.subjectView,
    required this.trackingState,
    required this.humanDetected,
    required this.trackingConfidence,
    required this.landmarks,
    required this.joints,
    required this.status,
    required this.leftKneeAngle,
    required this.rightKneeAngle,
    required this.torsoInclination,
    required this.leftHipAngle,
    required this.rightHipAngle,
    required this.bilateralKneeSymmetry,
  });
}

/// Local real-time tracker used by the camera UI.  It consumes only actual
/// MediaPipe landmarks already present in [HumanTrackingPayload].
class SquatTemporalTracker {
  static const requiredLandmarkIndices = <int>{11, 12, 23, 24, 25, 26, 27, 28};

  SquatTemporalTracker({
    this.maxBufferSize = 120,
    this.smoothingWindow = 3,
    this.minConfidence = 0.60,
    this.standingExitAngle = 150.0,
    this.bottomAngle = 120.0,
    this.bottomExitAngle = 130.0,
    this.standingReturnAngle = 160.0,
    this.minDirectionSpeed = 1.0,
    this.trackingLossGraceUs = 1000000,
  }) : assert(maxBufferSize > 0),
       assert(smoothingWindow > 0 && smoothingWindow.isOdd);

  final int maxBufferSize;
  final int smoothingWindow;
  final double minConfidence;
  final double standingExitAngle;
  final double bottomAngle;
  final double bottomExitAngle;
  final double standingReturnAngle;
  final double minDirectionSpeed;
  final int trackingLossGraceUs;

  final List<TemporalPoseSnapshot> _frames = <TemporalPoseSnapshot>[];
  final List<double> _validAngles = <double>[];
  final List<double> _validHipAngles = <double>[];
  SquatPhase _phase = SquatPhase.standing;
  int _repetitionCount = 0;
  int? _lastTimestampUs;
  int? _lastValidTimestampUs;
  double? _lastSmoothedAngle;
  double? _lastSmoothedHipAngle;
  int? _lossStartedUs;
  String _lastMessage = '';
  bool _incompleteCycle = false;

  SquatPhase get phase => _phase;
  int get repetitionCount => _repetitionCount;
  int get bufferSize => _frames.length;
  List<TemporalPoseSnapshot> get frameBuffer =>
      List<TemporalPoseSnapshot>.unmodifiable(_frames);

  void reset({bool keepRepetitionCount = true}) {
    final repetitions = keepRepetitionCount ? _repetitionCount : 0;
    _frames.clear();
    _validAngles.clear();
    _validHipAngles.clear();
    _phase = SquatPhase.standing;
    _repetitionCount = repetitions;
    _lastTimestampUs = null;
    _lastValidTimestampUs = null;
    _lastSmoothedAngle = null;
    _lastSmoothedHipAngle = null;
    _lossStartedUs = null;
    _lastMessage = '';
    _incompleteCycle = false;
  }

  /// Clear a camera/inference interruption without inventing a timestamped
  /// frame. Completed repetitions remain in the session, but a partial phase
  /// must be restarted from a newly reliable standing sample.
  SquatTemporalResult resetAfterInterruption({
    String message = 'TRACKING PAUSED. REPOSITION AND TRY AGAIN.',
  }) {
    final repetitions = _repetitionCount;
    reset(keepRepetitionCount: true);
    return SquatTemporalResult(
      status: BiomechanicsEvaluationStatus.trackingLost,
      phase: _phase,
      repetitionCount: repetitions,
      completedRep: false,
      smoothedKneeAngle: null,
      movementDirection: null,
      movementSpeedDegreesPerSecond: null,
      torsoInclination: null,
      leftHipAngle: null,
      rightHipAngle: null,
      bilateralKneeSymmetry: null,
      feedbackEligible: false,
      verifiedFindings: const <String>[],
      message: message,
    );
  }

  /// Process one native pose payload. A missing/uncertain joint produces a
  /// non-scoring result and never supplies a replacement coordinate.
  SquatTemporalResult process(HumanTrackingPayload payload) {
    final timestampUs = payload.timestampUs;
    if (timestampUs <= 0) {
      return _unavailable(
        BiomechanicsEvaluationStatus.insufficientData,
        'FRAME TIMESTAMP UNAVAILABLE; TEMPORAL ANALYSIS PAUSED.',
        record: false,
      );
    }
    if (_lastTimestampUs != null && timestampUs <= _lastTimestampUs!) {
      return _unavailable(
        BiomechanicsEvaluationStatus.insufficientData,
        'OUT-OF-ORDER CAMERA FRAME IGNORED.',
        record: false,
      );
    }
    _lastTimestampUs = timestampUs;
    _frames.add(_snapshotFor(payload));
    if (_frames.length > maxBufferSize) _frames.removeAt(0);

    final skillId = payload.skillId ?? '';
    // The current exercise registry sends the canonical `squat` id. Keep the
    // historical aliases for recorded fixtures, but never reject a real
    // camera session merely because it uses the registry id.
    if (skillId != 'squat' && skillId != 'sk_3' && skillId != 'sk_squat') {
      _resetPhaseOnly();
      return _unavailable(
        BiomechanicsEvaluationStatus.insufficientData,
        'AUTOMATIC SQUAT TRACKING IS UNAVAILABLE FOR THIS EXERCISE.',
      );
    }
    if (payload.subjectView.toLowerCase() != 'side') {
      _resetPhaseOnly();
      return _unavailable(
        BiomechanicsEvaluationStatus.unsupportedView,
        'TURN THE PHONE TO A SIDE VIEW FOR SQUAT TRACKING.',
      );
    }

    if (!payload.humanDetected ||
        payload.trackingState != HumanDetectionState.humanLocked) {
      return _trackingLost(timestampUs);
    }

    final landmarksByIndex = <int, MediaPipePoseLandmark>{};
    for (final landmark in payload.landmarks) {
      final index = landmark.index;
      if (index != null) {
        if (landmarksByIndex.containsKey(index)) {
          return _trackingLost(timestampUs, insufficient: true);
        }
        landmarksByIndex[index] = landmark;
      }
    }
    if (!requiredLandmarkIndices.every(landmarksByIndex.containsKey)) {
      return _trackingLost(timestampUs, insufficient: true);
    }
    for (final index in requiredLandmarkIndices) {
      final landmark = landmarksByIndex[index]!;
      if (!landmark.x.isFinite ||
          !landmark.y.isFinite ||
          !landmark.z.isFinite ||
          landmark.visibility == null ||
          !landmark.visibility!.isFinite) {
        return _trackingLost(timestampUs, insufficient: true);
      }
      if (landmark.visibility! < minConfidence ||
          (landmark.presence != null &&
              (!landmark.presence!.isFinite ||
                  landmark.presence! < minConfidence))) {
        return _trackingLost(timestampUs, lowConfidence: true);
      }
    }

    Joint3DPoint? get(String name) => payload.joints[name];
    final requiredNames = const [
      'leftShoulder',
      'rightShoulder',
      'leftHip',
      'rightHip',
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
    ];
    final required = <Joint3DPoint>[];
    for (final name in requiredNames) {
      final point = get(name);
      if (point == null) {
        return _trackingLost(timestampUs, insufficient: true);
      }
      required.add(point);
    }
    final confidence = _confidence(required);
    if (confidence < minConfidence) {
      return _trackingLost(timestampUs, lowConfidence: true);
    }

    final leftKnee = BiomechanicsEngine.calculateAngle(
      get('leftHip')!,
      get('leftKnee')!,
      get('leftAnkle')!,
      coordinateSpace: payload.coordinateSpace,
    );
    final rightKnee = BiomechanicsEngine.calculateAngle(
      get('rightHip')!,
      get('rightKnee')!,
      get('rightAnkle')!,
      coordinateSpace: payload.coordinateSpace,
    );
    final torso = BiomechanicsEngine.calculateTorsoInclination(
      get('leftShoulder')!,
      get('rightShoulder')!,
      get('leftHip')!,
      get('rightHip')!,
      coordinateSpace: payload.coordinateSpace,
    );
    final leftHip = BiomechanicsEngine.calculateAngle(
      get('leftShoulder')!,
      get('leftHip')!,
      get('leftKnee')!,
      coordinateSpace: payload.coordinateSpace,
    );
    final rightHip = BiomechanicsEngine.calculateAngle(
      get('rightShoulder')!,
      get('rightHip')!,
      get('rightKnee')!,
      coordinateSpace: payload.coordinateSpace,
    );
    if (leftKnee == null ||
        rightKnee == null ||
        leftHip == null ||
        rightHip == null ||
        torso == null) {
      return _trackingLost(timestampUs, insufficient: true);
    }

    if (_lastValidTimestampUs != null &&
        timestampUs - _lastValidTimestampUs! > trackingLossGraceUs) {
      _resetPhaseOnly();
    }

    if (_lossStartedUs != null) {
      if (timestampUs - _lossStartedUs! > trackingLossGraceUs) {
        _resetPhaseOnly();
      }
      _lossStartedUs = null;
    }

    final angle = (leftKnee + rightKnee) / 2.0;
    _validAngles.add(angle);
    if (_validAngles.length > smoothingWindow) _validAngles.removeAt(0);
    final smoothed = _median(_validAngles);
    final hipAngle = (leftHip + rightHip) / 2.0;
    _validHipAngles.add(hipAngle);
    if (_validHipAngles.length > smoothingWindow) {
      _validHipAngles.removeAt(0);
    }
    final smoothedHip = _median(_validHipAngles);
    double? speed;
    String? direction;
    double? hipSpeed;
    String? hipDirection;
    if (_lastSmoothedAngle != null && _lastValidTimestampUs != null) {
      final deltaSeconds = (timestampUs - _lastValidTimestampUs!) / 1000000.0;
      if (deltaSeconds > 0 && deltaSeconds.isFinite) {
        final delta = smoothed - _lastSmoothedAngle!;
        speed = (delta / deltaSeconds).abs();
        direction = _direction(delta);
        if (_lastSmoothedHipAngle != null) {
          final hipDelta = smoothedHip - _lastSmoothedHipAngle!;
          hipSpeed = (hipDelta / deltaSeconds).abs();
          hipDirection = _direction(hipDelta);
        }
      }
    }
    _lastValidTimestampUs = timestampUs;
    _lastSmoothedAngle = smoothed;
    _lastSmoothedHipAngle = smoothedHip;
    final movementSupported =
        direction == null ||
        hipDirection == null ||
        hipDirection == 'STATIONARY' ||
        hipDirection == direction ||
        (hipSpeed != null && hipSpeed < minDirectionSpeed);
    final completed = _advance(
      smoothed,
      direction,
      speed,
      movementSupported: movementSupported,
    );
    final symmetry = _limbSymmetry(leftKnee, rightKnee);
    final verifiedFindings = _verifiedFindings(torso, symmetry);
    final message = _feedback(torso, completed, symmetry);
    _markLatest(
      status: BiomechanicsEvaluationStatus.valid,
      leftKneeAngle: leftKnee,
      rightKneeAngle: rightKnee,
      torsoInclination: torso,
      leftHipAngle: leftHip,
      rightHipAngle: rightHip,
      bilateralKneeSymmetry: symmetry,
    );
    return SquatTemporalResult(
      status: BiomechanicsEvaluationStatus.valid,
      phase: _phase,
      repetitionCount: _repetitionCount,
      completedRep: completed,
      smoothedKneeAngle: smoothed,
      movementDirection: direction,
      movementSpeedDegreesPerSecond: speed,
      torsoInclination: torso,
      leftHipAngle: leftHip,
      rightHipAngle: rightHip,
      bilateralKneeSymmetry: symmetry,
      feedbackEligible: true,
      verifiedFindings: verifiedFindings,
      message: message,
    );
  }

  double _confidence(Iterable<Joint3DPoint> joints) {
    var result = 1.0;
    for (final joint in joints) {
      final value =
          (joint.presence == null
                  ? joint.confidence
                  : math.min(joint.confidence, joint.presence!))
              .toDouble();
      if (!value.isFinite) return 0.0;
      result = math.min(result, value).toDouble();
    }
    return result;
  }

  static double _limbSymmetry(double left, double right) {
    return (1.0 - (left - right).abs() / 180.0).clamp(0.0, 1.0).toDouble();
  }

  SquatTemporalResult _trackingLost(
    int timestampUs, {
    bool lowConfidence = false,
    bool insufficient = false,
  }) {
    if (_lastValidTimestampUs != null &&
        timestampUs - _lastValidTimestampUs! > trackingLossGraceUs) {
      _resetPhaseOnly();
    }
    _lossStartedUs ??= timestampUs;
    if (timestampUs - _lossStartedUs! > trackingLossGraceUs) {
      _resetPhaseOnly();
      _lossStartedUs = timestampUs;
    }
    final status = lowConfidence
        ? BiomechanicsEvaluationStatus.lowConfidence
        : (insufficient
              ? BiomechanicsEvaluationStatus.insufficientData
              : BiomechanicsEvaluationStatus.trackingLost);
    return _unavailable(
      status,
      lowConfidence
          ? 'KEEP BOTH HIPS AND KNEES VISIBLE; TRACKING CONFIDENCE IS TOO LOW.'
          : 'TRACKING PAUSED. STEP BACK AND KEEP YOUR FULL BODY VISIBLE.',
    );
  }

  SquatTemporalResult _unavailable(
    BiomechanicsEvaluationStatus status,
    String message, {
    bool record = true,
  }) {
    if (record) _markLatest(status: status);
    return SquatTemporalResult(
      status: status,
      phase: _phase,
      repetitionCount: _repetitionCount,
      completedRep: false,
      smoothedKneeAngle: null,
      movementDirection: null,
      movementSpeedDegreesPerSecond: null,
      torsoInclination: null,
      leftHipAngle: null,
      rightHipAngle: null,
      bilateralKneeSymmetry: null,
      feedbackEligible: false,
      verifiedFindings: const <String>[],
      message: message,
    );
  }

  TemporalPoseSnapshot _snapshotFor(HumanTrackingPayload payload) {
    return TemporalPoseSnapshot(
      timestampUs: payload.timestampUs,
      sessionId: payload.sessionId,
      skillId: payload.skillId,
      subjectView: payload.subjectView,
      trackingState: payload.trackingState,
      humanDetected: payload.humanDetected,
      trackingConfidence: payload.trackingConfidence,
      landmarks: List<MediaPipePoseLandmark>.unmodifiable(payload.landmarks),
      joints: Map<String, Joint3DPoint>.unmodifiable(payload.joints),
      status: null,
      leftKneeAngle: null,
      rightKneeAngle: null,
      torsoInclination: null,
      leftHipAngle: null,
      rightHipAngle: null,
      bilateralKneeSymmetry: null,
    );
  }

  void _markLatest({
    required BiomechanicsEvaluationStatus status,
    double? leftKneeAngle,
    double? rightKneeAngle,
    double? torsoInclination,
    double? leftHipAngle,
    double? rightHipAngle,
    double? bilateralKneeSymmetry,
  }) {
    if (_frames.isEmpty) return;
    final current = _frames.removeLast();
    _frames.add(
      TemporalPoseSnapshot(
        timestampUs: current.timestampUs,
        sessionId: current.sessionId,
        skillId: current.skillId,
        subjectView: current.subjectView,
        trackingState: current.trackingState,
        humanDetected: current.humanDetected,
        trackingConfidence: current.trackingConfidence,
        landmarks: current.landmarks,
        joints: current.joints,
        status: status,
        leftKneeAngle: leftKneeAngle,
        rightKneeAngle: rightKneeAngle,
        torsoInclination: torsoInclination,
        leftHipAngle: leftHipAngle,
        rightHipAngle: rightHipAngle,
        bilateralKneeSymmetry: bilateralKneeSymmetry,
      ),
    );
  }

  void _resetPhaseOnly() {
    _phase = SquatPhase.standing;
    _validAngles.clear();
    _validHipAngles.clear();
    _lastSmoothedAngle = null;
    _lastSmoothedHipAngle = null;
    _lastValidTimestampUs = null;
    _incompleteCycle = false;
    _lastMessage = '';
  }

  bool _advance(
    double angle,
    String? direction,
    double? speed, {
    required bool movementSupported,
  }) {
    final movingDown =
        movementSupported &&
        direction == 'DESCENDING' &&
        (speed ?? 0.0) >= minDirectionSpeed;
    final movingUp =
        movementSupported &&
        direction == 'ASCENDING' &&
        (speed ?? 0.0) >= minDirectionSpeed;
    if (_phase == SquatPhase.completedRep) {
      if (angle >= standingReturnAngle) _phase = SquatPhase.standing;
      return false;
    }
    if (_phase == SquatPhase.standing) {
      if (angle <= standingExitAngle && movingDown) {
        _phase = SquatPhase.descending;
      }
      return false;
    }
    if (_phase == SquatPhase.descending) {
      if (angle <= bottomAngle) {
        _phase = SquatPhase.bottom;
      } else if (angle >= standingReturnAngle && !movingDown) {
        _phase = SquatPhase.standing;
        _incompleteCycle = true;
      }
      return false;
    }
    if (_phase == SquatPhase.bottom) {
      if (angle >= bottomExitAngle && movingUp) {
        _phase = SquatPhase.ascending;
      }
      return false;
    }
    if (_phase == SquatPhase.ascending) {
      if (angle >= standingReturnAngle) {
        _phase = SquatPhase.completedRep;
        _repetitionCount++;
        return true;
      }
      if (angle <= bottomAngle && !movingUp) _phase = SquatPhase.bottom;
    }
    return false;
  }

  static String _direction(double delta) {
    if (delta < 0) return 'DESCENDING';
    if (delta > 0) return 'ASCENDING';
    return 'STATIONARY';
  }

  String _feedback(double torso, bool completed, double symmetry) {
    final findings = <String>[];
    if (completed) {
      findings.add('SQUAT REP COMPLETED ✓');
    } else {
      switch (_phase) {
        case SquatPhase.descending:
          findings.add('LOWER UNDER CONTROL');
          break;
        case SquatPhase.bottom:
          findings.add('HOLD THE BOTTOM, THEN DRIVE UP');
          break;
        case SquatPhase.ascending:
          findings.add('DRIVE UP TO A STABLE STAND');
          break;
        case SquatPhase.standing:
          if (_incompleteCycle) {
            findings.add('DEPTH NOT REACHED; REPEAT WITH CONTROL');
            _incompleteCycle = false;
          }
          break;
        case SquatPhase.completedRep:
          break;
      }
    }
    if (torso > 45.0) findings.add('REDUCE OBSERVABLE TORSO LEAN');
    if (symmetry < 0.80) findings.add('KEEP BOTH KNEES TRACKING EVENLY');
    final next = findings.join(' • ');
    if (next == _lastMessage) return _lastMessage;
    _lastMessage = next;
    return next;
  }

  List<String> _verifiedFindings(double torso, double symmetry) {
    final findings = <String>[];
    if (_incompleteCycle) findings.add('squat_depth');
    if (torso > 45.0) findings.add('squat_torso_inclination');
    if (symmetry < 0.80) findings.add('squat_bilateral_symmetry');
    return findings;
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}
