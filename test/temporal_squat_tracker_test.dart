import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_ai/features/practice/models/skill_biomechanics.dart';
import 'package:skillverse_ai/features/practice/services/temporal_squat_tracker.dart';
import 'package:skillverse_ai/features/practice/services/biomechanics_engine.dart';

HumanTrackingPayload payload(
  int timestampUs,
  double kneeAngle, {
  double landmarkConfidence = 0.95,
  double trackingConfidence = 0.95,
}) {
  final radians = kneeAngle * math.pi / 180.0;
  final joints = <String, Joint3DPoint>{
    'leftShoulder': const Joint3DPoint(
      x: 0.1,
      y: 0.1,
      z: 0.0,
      confidence: 0.95,
    ),
    'rightShoulder': const Joint3DPoint(
      x: 0.9,
      y: 0.1,
      z: 0.0,
      confidence: 0.95,
    ),
    'leftHip': const Joint3DPoint(x: 0.1, y: 0.5, z: 0.0, confidence: 0.95),
    'rightHip': const Joint3DPoint(x: 0.9, y: 0.5, z: 0.0, confidence: 0.95),
    'leftKnee': const Joint3DPoint(x: 0.3, y: 0.5, z: 0.0, confidence: 0.95),
    'rightKnee': const Joint3DPoint(x: 0.7, y: 0.5, z: 0.0, confidence: 0.95),
    'leftAnkle': Joint3DPoint(
      x: 0.3 - 0.2 * math.cos(radians),
      y: 0.5 + 0.2 * math.sin(radians),
      z: 0.0,
      confidence: 0.95,
    ),
    'rightAnkle': Joint3DPoint(
      x: 0.7 + 0.2 * math.cos(radians),
      y: 0.5 + 0.2 * math.sin(radians),
      z: 0.0,
      confidence: 0.95,
    ),
  };
  final landmarks = <MediaPipePoseLandmark>[
    for (final entry in <int, String>{
      11: 'leftShoulder',
      12: 'rightShoulder',
      23: 'leftHip',
      24: 'rightHip',
      25: 'leftKnee',
      26: 'rightKnee',
      27: 'leftAnkle',
      28: 'rightAnkle',
    }.entries)
      MediaPipePoseLandmark(
        index: entry.key,
        x: joints[entry.value]!.x,
        y: joints[entry.value]!.y,
        z: joints[entry.value]!.z,
        visibility: landmarkConfidence,
        presence: landmarkConfidence,
      ),
  ];
  return HumanTrackingPayload(
    humanDetected: true,
    trackingState: HumanDetectionState.humanLocked,
    trackingConfidence: trackingConfidence,
    multiplePeopleCount: 1,
    selectedPersonId: 'primary_user_1',
    joints: joints,
    landmarks: landmarks,
    timestampUs: timestampUs,
    sessionId: 'flutter-test-session',
    skillId: 'sk_3',
    subjectView: 'side',
  );
}

void main() {
  test('local tracker counts one measured squat exactly once', () {
    final tracker = SquatTemporalTracker();
    // Include two stable standing samples after ascent so the three-sample
    // median filter can observe the return to the standing threshold.
    final angles = [
      170.0,
      170.0,
      160.0,
      140.0,
      120.0,
      105.0,
      110.0,
      125.0,
      140.0,
      155.0,
      170.0,
      170.0,
      170.0,
    ];
    final results = [
      for (var i = 0; i < angles.length; i++)
        tracker.process(payload((i + 1) * 100000, angles[i])),
    ];

    expect(tracker.repetitionCount, 1);
    expect(results.where((result) => result.completedRep), hasLength(1));
    expect(results.map((result) => result.phase), contains(SquatPhase.bottom));
  });

  test('local tracker accepts the canonical exercise registry id', () {
    final tracker = SquatTemporalTracker();
    final angles = [
      170.0,
      170.0,
      160.0,
      140.0,
      120.0,
      105.0,
      110.0,
      125.0,
      140.0,
      155.0,
      170.0,
      170.0,
      170.0,
    ];
    final results = <SquatTemporalResult>[];
    for (var i = 0; i < angles.length; i++) {
      final frame = payload((i + 1) * 100000, angles[i]);
      results.add(
        tracker.process(
          HumanTrackingPayload(
            humanDetected: frame.humanDetected,
            trackingState: frame.trackingState,
            trackingConfidence: frame.trackingConfidence,
            multiplePeopleCount: frame.multiplePeopleCount,
            selectedPersonId: frame.selectedPersonId,
            joints: frame.joints,
            landmarks: frame.landmarks,
            timestampUs: frame.timestampUs,
            sessionId: frame.sessionId,
            skillId: 'squat',
            subjectView: frame.subjectView,
          ),
        ),
      );
    }
    expect(results.last.repetitionCount, 1);
    expect(results.where((result) => result.completedRep), hasLength(1));
  });

  test('local tracker counts five complete canonical squats once each', () {
    final tracker = SquatTemporalTracker();
    final angles = [
      170.0,
      170.0,
      160.0,
      140.0,
      120.0,
      105.0,
      110.0,
      125.0,
      140.0,
      155.0,
      170.0,
      170.0,
    ];
    final completed = <SquatTemporalResult>[];
    var timestamp = 100000;
    for (var repetition = 0; repetition < 5; repetition++) {
      for (final angle in angles) {
        final frame = payload(timestamp, angle);
        completed.add(
          tracker.process(
            HumanTrackingPayload(
              humanDetected: frame.humanDetected,
              trackingState: frame.trackingState,
              trackingConfidence: frame.trackingConfidence,
              multiplePeopleCount: frame.multiplePeopleCount,
              selectedPersonId: frame.selectedPersonId,
              joints: frame.joints,
              landmarks: frame.landmarks,
              timestampUs: frame.timestampUs,
              sessionId: frame.sessionId,
              skillId: 'squat',
              subjectView: frame.subjectView,
            ),
          ),
        );
        timestamp += 100000;
      }
    }
    expect(tracker.repetitionCount, 5);
    expect(completed.where((result) => result.completedRep), hasLength(5));
  });

  test('local tracker abstains when a required knee is missing', () {
    final tracker = SquatTemporalTracker();
    final missing = payload(100000, 120);
    final joints = Map<String, Joint3DPoint>.from(missing.joints)
      ..remove('leftKnee');
    final invalid = HumanTrackingPayload(
      humanDetected: missing.humanDetected,
      trackingState: missing.trackingState,
      trackingConfidence: missing.trackingConfidence,
      multiplePeopleCount: missing.multiplePeopleCount,
      selectedPersonId: missing.selectedPersonId,
      joints: joints,
      timestampUs: missing.timestampUs,
      sessionId: missing.sessionId,
      skillId: missing.skillId,
      subjectView: missing.subjectView,
    );

    final result = tracker.process(invalid);
    expect(result.status, BiomechanicsEvaluationStatus.insufficientData);
    expect(result.completedRep, isFalse);
    expect(result.repetitionCount, 0);
  });

  test('local tracker reports low-confidence landmarks explicitly', () {
    final tracker = SquatTemporalTracker();
    final result = tracker.process(
      payload(100000, 170, landmarkConfidence: 0.2),
    );

    expect(result.status, BiomechanicsEvaluationStatus.lowConfidence);
    expect(result.completedRep, isFalse);
    expect(result.repetitionCount, 0);
  });

  test('local tracker rejects low aggregate tracking confidence', () {
    final tracker = SquatTemporalTracker();
    final result = tracker.process(
      payload(100000, 170, trackingConfidence: 0.20),
    );

    expect(result.status, BiomechanicsEvaluationStatus.lowConfidence);
    expect(result.repetitionCount, 0);
    expect(result.completedRep, isFalse);
  });

  test('local tracker does not count an implausible one-frame angle jump', () {
    final tracker = SquatTemporalTracker();
    final angles = [170.0, 170.0, 160.0, 140.0, 5.0, 170.0, 170.0];
    final results = [
      for (var i = 0; i < angles.length; i++)
        tracker.process(payload((i + 1) * 100000, angles[i])),
    ];

    expect(tracker.repetitionCount, 0);
    expect(results.every((result) => !result.completedRep), isTrue);
  });
}
