import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_ai/features/practice/models/skill_biomechanics.dart';
import 'package:skillverse_ai/features/practice/services/tracking_stability_filter.dart';

HumanTrackingPayload _locked(int timestampUs) {
  return HumanTrackingPayload(
    humanDetected: true,
    trackingState: HumanDetectionState.humanLocked,
    trackingConfidence: 0.95,
    multiplePeopleCount: 1,
    selectedPersonId: 'primary_user_1',
    joints: const {'leftHip': Joint3DPoint(x: 0.4, y: 0.5, z: 0.0)},
    timestampUs: timestampUs,
  );
}

HumanTrackingPayload _lost(int timestampUs) {
  return HumanTrackingPayload(
    humanDetected: false,
    trackingState: HumanDetectionState.searchingForHuman,
    trackingConfidence: 0.0,
    multiplePeopleCount: 0,
    selectedPersonId: 'primary_user_1',
    joints: const {},
    timestampUs: timestampUs,
  );
}

void main() {
  test('requires consecutive good frames before locking', () {
    final filter = TrackingStabilityFilter(
      lockFrameCount: 2,
      lossFrameCount: 5,
    );

    final first = filter.update(_locked(100));
    expect(first.locked, isFalse);
    expect(first.shouldProcess, isFalse);

    final second = filter.update(_locked(200));
    expect(second.locked, isTrue);
    expect(second.justLocked, isTrue);
    expect(second.shouldProcess, isTrue);
  });

  test('holds a stable display through a short detector dropout', () {
    final filter = TrackingStabilityFilter(
      lockFrameCount: 2,
      lossFrameCount: 5,
    );
    filter.update(_locked(100));
    final locked = filter.update(_locked(200));

    for (var i = 0; i < 4; i++) {
      final grace = filter.update(_lost(300 + i * 100));
      expect(grace.locked, isTrue);
      expect(grace.gracePeriod, isTrue);
      expect(grace.shouldProcess, isFalse);
      expect(grace.displayPayload, same(locked.displayPayload));
    }

    final terminal = filter.update(_lost(700));
    expect(terminal.locked, isFalse);
    expect(terminal.justLost, isTrue);
    expect(terminal.gracePeriod, isFalse);
    expect(terminal.shouldProcess, isTrue);
  });

  test('requires a fresh lock after a sustained loss', () {
    final filter = TrackingStabilityFilter(
      lockFrameCount: 2,
      lossFrameCount: 2,
    );
    filter.update(_locked(100));
    filter.update(_locked(200));
    filter.update(_lost(300));
    filter.update(_lost(400));

    final firstRecovery = filter.update(_locked(500));
    expect(firstRecovery.locked, isFalse);
    expect(firstRecovery.shouldProcess, isFalse);
    final secondRecovery = filter.update(_locked(600));
    expect(secondRecovery.locked, isTrue);
    expect(secondRecovery.justLocked, isTrue);
  });
}
