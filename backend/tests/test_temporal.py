"""Deterministic Phase 3 temporal tracker tests.

These tests validate state-machine behavior; they are not a claim of
real-world exercise accuracy.
"""

from app.agents.temporal import (
    MAX_ACTIVE_TRACKERS,
    SquatTemporalTracker,
    TemporalFrame,
    _tracker_for,
    _trackers,
)
from app.schemas import EvaluationStatus, LandmarkPoint, SquatPhase


def sample(
    timestamp_us: int,
    angle: float | None,
    *,
    status: EvaluationStatus = EvaluationStatus.VALID,
    view: str = "side",
    skill: str = "sk_3",
    confidence: float | None = 0.95,
    torso: float | None = 10.0,
    hip_angle: float | None = None,
    omit_hips: bool = False,
    omit_landmarks: bool = False,
    landmark_visibility: float = 0.95,
) -> TemporalFrame:
    measured_hip = None if omit_hips else (angle if hip_angle is None else hip_angle)
    landmarks = tuple(
        LandmarkPoint(
            index=index,
            x=float(index) / 32.0,
            y=0.5,
            z=0.0,
            visibility=landmark_visibility,
            presence=landmark_visibility,
        )
        for index in (11, 12, 23, 24, 25, 26, 27, 28)
    )
    return TemporalFrame(
        timestamp_us=timestamp_us,
        session_id="s1",
        skill_id=skill,
        status=status,
        landmarks=() if omit_landmarks else landmarks,
        subject_view=view,
        measurement_confidence=confidence,
        left_knee_angle=angle,
        right_knee_angle=angle,
        left_hip_angle=measured_hip,
        right_hip_angle=measured_hip,
        torso_inclination=torso,
    )


def complete_squat(start_us: int = 0, step_us: int = 100_000) -> list[TemporalFrame]:
    # Extra samples make the median window explicit and exercise hysteresis.
    angles = [170, 170, 160, 140, 120, 105, 110, 125, 140, 155, 170, 170]
    return [sample(start_us + index * step_us, angle) for index, angle in enumerate(angles)]


def run(tracker: SquatTemporalTracker, frames: list[TemporalFrame]):
    return [tracker.process(frame) for frame in frames]


def test_one_complete_squat_counts_once():
    tracker = SquatTemporalTracker()
    results = run(tracker, complete_squat())
    assert tracker.repetition_count == 1
    assert sum(result.completed_rep for result in results) == 1
    observed_phases = {result.phase for result in results}
    assert {
        SquatPhase.STANDING,
        SquatPhase.DESCENDING,
        SquatPhase.BOTTOM,
        SquatPhase.ASCENDING,
        SquatPhase.COMPLETED_REP,
    }.issubset(observed_phases)
    assert results[-1].phase in {SquatPhase.COMPLETED_REP, SquatPhase.STANDING}


def test_multiple_consecutive_squats_count_each_completed_cycle():
    tracker = SquatTemporalTracker()
    offset = len(complete_squat()) * 100_000
    frames = complete_squat() + [
        sample(offset + index * 100_000, angle)
        for index, angle in enumerate([160, 140, 120, 105, 110, 125, 140, 155, 170, 170])
    ]
    results = run(tracker, frames)
    assert tracker.repetition_count == 2
    assert sum(result.completed_rep for result in results) == 2


def test_five_complete_squats_count_once_each():
    tracker = SquatTemporalTracker()
    frames = []
    timestamp = 0
    for _ in range(5):
        for frame in complete_squat(start_us=timestamp):
            frames.append(frame)
            timestamp = frame.timestamp_us + 100_000
    results = run(tracker, frames)
    assert tracker.repetition_count == 5
    assert sum(result.completed_rep for result in results) == 5


def test_incomplete_partial_squat_is_not_counted():
    tracker = SquatTemporalTracker()
    results = run(tracker, [sample(i * 100_000, angle) for i, angle in enumerate([170, 160, 145, 135, 145, 160, 170, 170])])
    assert tracker.repetition_count == 0
    assert not any(result.completed_rep for result in results)
    assert any("depth" in item.lower() for result in results for item in result.feedback)


def test_pause_at_bottom_keeps_bottom_phase_without_duplicate_count():
    tracker = SquatTemporalTracker()
    frames = complete_squat()[:6] + [
        sample(600_000 + index * 200_000, 105) for index in range(3)
    ] + [sample(1_300_000 + i * 100_000, a) for i, a in enumerate([130, 145, 165, 170])]
    results = run(tracker, frames)
    assert any(result.phase == SquatPhase.BOTTOM for result in results)
    assert tracker.repetition_count == 1


def test_slow_and_fast_sequences_use_timestamps_not_frame_count():
    slow = SquatTemporalTracker()
    fast = SquatTemporalTracker()
    assert run(slow, complete_squat(step_us=500_000))[-1].repetition_count == 1
    moving = run(fast, complete_squat(step_us=20_000))
    assert moving[-1].repetition_count == 1
    assert any(result.movement_speed_degrees_per_second is not None for result in moving)


def test_noisy_angles_are_smoothed_and_still_count_once():
    tracker = SquatTemporalTracker()
    noisy = [170, 168, 160, 147, 140, 118, 122, 108, 114, 130, 127, 145, 158, 164, 171, 168]
    results = run(tracker, [sample(i * 100_000, angle) for i, angle in enumerate(noisy)])
    assert tracker.repetition_count == 1
    assert all(result.smoothed_knee_angle is None or result.smoothed_knee_angle == result.smoothed_knee_angle for result in results)


def test_missing_knee_landmarks_abstain_without_counting():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:5])
    lost = tracker.process(sample(600_000, None, status=EvaluationStatus.INSUFFICIENT_DATA))
    assert lost.status == EvaluationStatus.INSUFFICIENT_DATA
    assert not lost.completed_rep
    assert tracker.repetition_count == 0


def test_missing_hip_measurements_abstain_without_counting():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, omit_hips=True))
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_missing_canonical_landmarks_abstain_even_with_angles():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, omit_landmarks=True))
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_duplicate_canonical_landmark_indices_abstain():
    tracker = SquatTemporalTracker()
    frame = sample(0, 170)
    duplicate = TemporalFrame(
        timestamp_us=frame.timestamp_us,
        session_id=frame.session_id,
        skill_id=frame.skill_id,
        status=frame.status,
        landmarks=frame.landmarks + (frame.landmarks[0],),
        subject_view=frame.subject_view,
        measurement_confidence=frame.measurement_confidence,
        left_knee_angle=frame.left_knee_angle,
        right_knee_angle=frame.right_knee_angle,
        left_hip_angle=frame.left_hip_angle,
        right_hip_angle=frame.right_hip_angle,
        torso_inclination=frame.torso_inclination,
    )
    result = tracker.process(duplicate)
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_low_landmark_confidence_is_reported_as_low_confidence():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, landmark_visibility=0.2))
    assert result.status == EvaluationStatus.LOW_CONFIDENCE
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_low_confidence_landmarks_abstain():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, confidence=0.2))
    assert result.status == EvaluationStatus.LOW_CONFIDENCE
    assert result.repetition_count == 0


def test_temporary_tracking_loss_recovers_without_fabricating_a_frame():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:8])
    lost = tracker.process(sample(850_000, None, status=EvaluationStatus.TRACKING_LOST))
    assert lost.status == EvaluationStatus.TRACKING_LOST
    recovered = tracker.process(sample(900_000, 155))
    assert recovered.completed_rep is False
    assert recovered.buffer_size == 10


def test_extended_tracking_loss_resets_partial_phase():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:7])
    tracker.process(sample(800_000, None, status=EvaluationStatus.TRACKING_LOST))
    reset = tracker.process(sample(2_000_000, None, status=EvaluationStatus.TRACKING_LOST))
    assert reset.phase == SquatPhase.STANDING
    assert reset.repetition_count == 0
    assert not reset.completed_rep


def test_first_invalid_frame_after_extended_gap_resets_partial_phase():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:7])
    reset = tracker.process(
        sample(2_000_000, None, status=EvaluationStatus.TRACKING_LOST)
    )
    assert reset.phase == SquatPhase.STANDING
    assert reset.repetition_count == 0
    assert not reset.completed_rep


def test_large_timestamp_gap_resets_even_when_no_invalid_callback_arrived():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:7])
    result = tracker.process(sample(2_000_000, 170))
    assert result.phase == SquatPhase.STANDING
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_duplicate_timestamps_do_not_advance_state_or_count():
    tracker = SquatTemporalTracker()
    tracker.process(sample(0, 170))
    duplicate = tracker.process(sample(0, 105))
    assert duplicate.status == EvaluationStatus.INSUFFICIENT_DATA
    assert tracker.repetition_count == 0
    assert tracker.phase == SquatPhase.STANDING


def test_irregular_intervals_still_produce_real_speed():
    tracker = SquatTemporalTracker()
    timestamps = [0, 31_000, 211_000, 222_000, 900_000, 1_450_000, 1_453_000, 1_700_000, 2_001_000, 2_900_000, 3_100_000, 3_900_000]
    results = run(tracker, [sample(ts, angle) for ts, angle in zip(timestamps, [170, 170, 160, 140, 120, 105, 110, 125, 140, 155, 170, 170])])
    assert tracker.repetition_count == 1
    assert any(result.movement_speed_degrees_per_second is not None for result in results)


def test_camera_movement_without_valid_measurements_never_counts():
    tracker = SquatTemporalTracker()
    results = run(tracker, [sample(i * 100_000, None, status=EvaluationStatus.TRACKING_LOST) for i in range(20)])
    assert tracker.repetition_count == 0
    assert all(not result.completed_rep for result in results)


def test_wrong_exercise_is_explicitly_unsupported():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, skill="sk_boxing"))
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.repetition_count == 0


def test_unsupported_exercise_resets_a_partial_squat_phase():
    tracker = SquatTemporalTracker()
    run(tracker, complete_squat()[:6])
    assert tracker.phase == SquatPhase.BOTTOM
    result = tracker.process(sample(600_000, 105, skill="sk_boxing"))
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.phase == SquatPhase.STANDING
    assert result.repetition_count == 0


def test_temporal_findings_are_machine_readable_and_measurement_backed():
    tracker = SquatTemporalTracker()
    result = tracker.process(
        sample(0, 170, torso=55.0)
    )
    assert result.status == EvaluationStatus.VALID
    assert "squat_torso_inclination" in result.verified_findings
    assert "squat_bilateral_symmetry" not in result.verified_findings

    partial = SquatTemporalTracker()
    partial_results = run(
        partial,
        [sample(i * 100_000, angle) for i, angle in enumerate([170, 160, 145, 135, 145, 160, 170])],
    )
    assert "squat_depth" in partial_results[-1].verified_findings


def test_active_tracker_registry_is_bounded():
    original = dict(_trackers)
    _trackers.clear()
    try:
        for index in range(MAX_ACTIVE_TRACKERS + 5):
            _tracker_for(("user", f"session-{index}", "sk_3"))
        assert len(_trackers) == MAX_ACTIVE_TRACKERS
        assert ("user", "session-0", "sk_3") not in _trackers
    finally:
        _trackers.clear()
        _trackers.update(original)


def test_wrong_view_is_rejected():
    tracker = SquatTemporalTracker()
    result = tracker.process(sample(0, 170, view="front"))
    assert result.status == EvaluationStatus.UNSUPPORTED_VIEW
    assert result.repetition_count == 0


def test_invalid_sequence_and_repeated_standing_do_not_count():
    tracker = SquatTemporalTracker()
    results = run(tracker, [sample(i * 100_000, 170) for i in range(20)])
    assert tracker.repetition_count == 0
    assert all(result.phase == SquatPhase.STANDING for result in results)


def test_feedback_is_stable_and_does_not_claim_unsupported_metrics():
    tracker = SquatTemporalTracker()
    results = run(tracker, complete_squat())
    feedback = [tuple(result.feedback) for result in results if result.feedback]
    assert feedback
    assert not any("spine" in item.lower() or "force" in item.lower() for row in feedback for item in row)


def test_bilateral_knee_asymmetry_produces_observable_alignment_feedback():
    tracker = SquatTemporalTracker()
    result = tracker.process(
        TemporalFrame(
            timestamp_us=0,
            session_id="s1",
            skill_id="sk_3",
            status=EvaluationStatus.VALID,
            landmarks=sample(0, 170).landmarks,
            subject_view="side",
            measurement_confidence=0.95,
            left_knee_angle=170.0,
            right_knee_angle=80.0,
            left_hip_angle=170.0,
            right_hip_angle=170.0,
            torso_inclination=10.0,
        )
    )
    assert result.bilateral_knee_symmetry == 0.5
    assert any("knees" in item.lower() for item in result.feedback)


def test_contradictory_hip_direction_pauses_knee_phase_transition():
    tracker = SquatTemporalTracker()
    tracker.process(sample(0, 170, hip_angle=170))
    result = tracker.process(sample(100_000, 140, hip_angle=200))
    assert result.status == EvaluationStatus.VALID
    assert result.phase == SquatPhase.STANDING
    assert tracker.repetition_count == 0
