import 'dart:math' as math;

import '../models/exercise_registry.dart';
import '../models/skill_biomechanics.dart';
import 'biomechanics_engine.dart';

/// A small, bounded, exercise-aware temporal tracker for the non-squat
/// profiles. Thresholds are configurable starting heuristics; they are not
/// expert validation or a claim that every body type moves identically.
class ExerciseTemporalResult {
  const ExerciseTemporalResult({
    required this.status,
    required this.phaseLabel,
    required this.repetitionCount,
    required this.completedCycle,
    required this.feedbackEligible,
    required this.message,
    required this.feedback,
    required this.verifiedFindings,
    this.primarySignal,
    this.movementDirection,
  });

  const ExerciseTemporalResult.initial(String exercise)
    : status = BiomechanicsEvaluationStatus.trackingLost,
      phaseLabel = 'READY',
      repetitionCount = 0,
      completedCycle = false,
      feedbackEligible = false,
      message = 'SHOW THE REQUIRED BODY PARTS TO BEGIN $exercise TRACKING.',
      feedback = const [],
      verifiedFindings = const [],
      primarySignal = null,
      movementDirection = null;

  final BiomechanicsEvaluationStatus status;
  final String phaseLabel;
  final int repetitionCount;
  final bool completedCycle;
  final bool feedbackEligible;
  final String message;
  final List<String> feedback;
  final List<String> verifiedFindings;
  final double? primarySignal;
  final String? movementDirection;
}

class ExerciseTemporalTracker {
  ExerciseTemporalTracker(this.exercise)
    : _result = ExerciseTemporalResult.initial(exercise.name);

  final ExerciseDefinition exercise;
  static const _minConfidence = 0.60;
  static const _windowSize = 3;
  static const _maxBufferSize = 120;
  final List<int> _timestamps = <int>[];
  final List<double> _signals = <double>[];
  ExerciseTemporalResult _result;
  int? _lastTimestampUs;
  double? _lastSmoothed;
  double? _baseline;
  int _phase = 0;
  int _repetitions = 0;

  ExerciseTemporalResult get result => _result;

  void reset({bool keepRepetitions = true}) {
    final count = keepRepetitions ? _repetitions : 0;
    _timestamps.clear();
    _signals.clear();
    _lastTimestampUs = null;
    _lastSmoothed = null;
    _baseline = null;
    _phase = 0;
    _repetitions = count;
    _result = ExerciseTemporalResult.initial(exercise.name);
  }

  ExerciseTemporalResult resetAfterInterruption(String message) {
    reset();
    _result = ExerciseTemporalResult(
      status: BiomechanicsEvaluationStatus.trackingLost,
      phaseLabel: _phaseName(0),
      repetitionCount: _repetitions,
      completedCycle: false,
      feedbackEligible: false,
      message: message,
      feedback: const [],
      verifiedFindings: const [],
    );
    return _result;
  }

  ExerciseTemporalResult process(HumanTrackingPayload payload) {
    if (payload.timestampUs <= 0 ||
        (_lastTimestampUs != null &&
            payload.timestampUs <= _lastTimestampUs!)) {
      return _unavailable(
        'FRAME TIMESTAMP UNAVAILABLE; TEMPORAL ANALYSIS PAUSED.',
      );
    }
    _lastTimestampUs = payload.timestampUs;
    if (!payload.humanDetected ||
        payload.trackingState != HumanDetectionState.humanLocked) {
      reset();
      return _unavailable(
        'MOVE BACK SLIGHTLY AND KEEP THE REQUIRED BODY PARTS VISIBLE.',
      );
    }

    final required = _requiredJoints;
    for (final name in required) {
      final joint = payload.joints[name];
      if (joint == null ||
          ![
            joint.x,
            joint.y,
            joint.z,
            joint.confidence,
          ].every((value) => value.isFinite) ||
          joint.confidence < _minConfidence ||
          (joint.presence != null && joint.presence! < _minConfidence)) {
        return _unavailable(
          'KEEP THE REQUIRED BODY PARTS VISIBLE TO CONTINUE.',
        );
      }
    }

    final signal = _signal(payload);
    if (signal == null || !signal.isFinite) {
      return _unavailable('HOLD A STEADY POSE SO MOVEMENT CAN BE MEASURED.');
    }
    _signals.add(signal);
    if (_signals.length > _windowSize) _signals.removeAt(0);
    _timestamps.add(payload.timestampUs);
    if (_timestamps.length > _maxBufferSize) _timestamps.removeAt(0);
    final smoothed = _median(_signals);
    final delta = _lastSmoothed == null ? 0.0 : smoothed - _lastSmoothed!;
    _lastSmoothed = smoothed;
    if (_baseline == null) _baseline = smoothed;
    final direction = delta.abs() < 1.0
        ? 'STATIONARY'
        : delta < 0
        ? 'DESCENDING'
        : 'ASCENDING';

    final completed = _advance(smoothed, delta);
    final feedback = <String>[];
    if (_phase > 0 && !completed) feedback.add(_phaseInstruction);
    if (completed) feedback.add('${exercise.name} movement cycle completed.');
    _result = ExerciseTemporalResult(
      status: BiomechanicsEvaluationStatus.valid,
      phaseLabel: _phaseName(_phase),
      repetitionCount: _repetitions,
      completedCycle: completed,
      feedbackEligible: true,
      message: feedback.isEmpty ? 'TRACKING READY' : feedback.last,
      feedback: feedback,
      verifiedFindings: const [],
      primarySignal: smoothed,
      movementDirection: direction,
    );
    return _result;
  }

  List<String> get _requiredJoints {
    switch (exercise.id) {
      case 'seated_chest_fly':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftWrist',
          'rightWrist',
          'leftHip',
          'rightHip',
        ];
      case 'boxing_jab':
      case 'push_up':
      case 'tricep_push_up':
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
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
        ];
      default:
        return const [
          'leftShoulder',
          'rightShoulder',
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
        ];
    }
  }

  double? _angle(HumanTrackingPayload payload, String a, String b, String c) {
    final first = payload.joints[a];
    final vertex = payload.joints[b];
    final last = payload.joints[c];
    if (first == null || vertex == null || last == null) return null;
    return BiomechanicsEngine.calculateAngle(
      first,
      vertex,
      last,
      coordinateSpace: payload.coordinateSpace,
    );
  }

  double? _signal(HumanTrackingPayload payload) {
    switch (exercise.id) {
      case 'seated_chest_fly':
        final leftShoulder = payload.joints['leftShoulder'];
        final rightShoulder = payload.joints['rightShoulder'];
        final leftWrist = payload.joints['leftWrist'];
        final rightWrist = payload.joints['rightWrist'];
        if ([
          leftShoulder,
          rightShoulder,
          leftWrist,
          rightWrist,
        ].any((point) => point == null))
          return null;
        final shoulderWidth = _distance(leftShoulder!, rightShoulder!);
        if (shoulderWidth <= 1e-8) return null;
        return _distance(leftWrist!, rightWrist!) / shoulderWidth;
      default:
        final left = _angle(payload, 'leftShoulder', 'leftElbow', 'leftWrist');
        final right = _angle(
          payload,
          'rightShoulder',
          'rightElbow',
          'rightWrist',
        );
        if (left == null && right == null) return null;
        return ((left ?? right!) + (right ?? left!)) / 2.0;
    }
  }

  bool _advance(double signal, double delta) {
    final isChest = exercise.id == 'seated_chest_fly';
    final low = isChest ? 1.35 : 115.0;
    final high = isChest ? 2.00 : 155.0;
    final returnThreshold = isChest ? 1.50 : 150.0;
    if (_phase == 0) {
      if ((isChest && signal <= low) || (!isChest && signal >= high))
        _phase = 1;
      return false;
    }
    if (_phase == 1) {
      if ((isChest && signal >= high) || (!isChest && signal <= low))
        _phase = 2;
      return false;
    }
    if (_phase == 2) {
      if ((isChest && signal <= returnThreshold && delta < 0) ||
          (!isChest && signal >= returnThreshold && delta > 0)) {
        _phase = 0;
        _repetitions++;
        return true;
      }
    }
    return false;
  }

  String get _phaseInstruction {
    switch (exercise.id) {
      case 'boxing_jab':
        return _phase == 1
            ? 'EXTEND THE JAB UNDER CONTROL.'
            : 'RETURN TO A STABLE GUARD.';
      case 'seated_chest_fly':
        return _phase == 1
            ? 'OPEN THE ARMS WITH CONTROL.'
            : 'CLOSE THE ARMS WITHOUT SWINGING.';
      case 'bent_over_row':
        return _phase == 1
            ? 'PULL THE ELBOWS BACK.'
            : 'LOWER WITH A STEADY TORSO.';
      default:
        return _phase == 1
            ? 'LOWER UNDER CONTROL.'
            : 'PRESS BACK TO THE START.';
    }
  }

  String _phaseName(int phase) {
    if (phase == 0) return exercise.phases.first;
    if (phase == 1)
      return exercise.phases.length > 1 ? exercise.phases[1] : 'MOVING';
    if (phase == 2)
      return exercise.phases.length > 2 ? exercise.phases[2] : 'RETURNING';
    return exercise.phases.last;
  }

  ExerciseTemporalResult _unavailable(String message) {
    // A rejected frame cannot bridge a partial cycle. Keep the completed
    // count, but clear the smoothing/state evidence before recovery.
    _signals.clear();
    _lastSmoothed = null;
    _baseline = null;
    _phase = 0;
    _result = ExerciseTemporalResult(
      status: BiomechanicsEvaluationStatus.insufficientData,
      phaseLabel: _phaseName(_phase),
      repetitionCount: _repetitions,
      completedCycle: false,
      feedbackEligible: false,
      message: message,
      feedback: const [],
      verifiedFindings: const [],
    );
    return _result;
  }

  static double _distance(Joint3DPoint a, Joint3DPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}
