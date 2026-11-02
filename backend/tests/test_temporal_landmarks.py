"""Landmark-to-temporal integration fixtures.

The state-machine tests use measured angles for breadth. These tests build
canonical landmark geometry first, run the real biomechanics formulas, and
then feed those measurements into the temporal tracker.
"""

import math

from app.agents.biomechanics import calculate_angle, calculate_torso_inclination
from app.agents.temporal import SquatTemporalTracker, TemporalFrame
from app.schemas import CoordinateSpace, EvaluationStatus, LandmarkPoint


def landmarks_for_knee_angle(angle: float) -> dict[int, LandmarkPoint]:
    radians = math.radians(180.0 - angle)
    return {
        11: LandmarkPoint(index=11, x=0.0, y=-1.0, z=0.0, visibility=0.95, presence=0.95),
        12: LandmarkPoint(index=12, x=2.0, y=-1.0, z=0.0, visibility=0.95, presence=0.95),
        23: LandmarkPoint(index=23, x=0.0, y=0.0, z=0.0, visibility=0.95, presence=0.95),
        24: LandmarkPoint(index=24, x=2.0, y=0.0, z=0.0, visibility=0.95, presence=0.95),
        25: LandmarkPoint(index=25, x=0.5, y=0.0, z=0.0, visibility=0.95, presence=0.95),
        26: LandmarkPoint(index=26, x=1.5, y=0.0, z=0.0, visibility=0.95, presence=0.95),
        27: LandmarkPoint(
            index=27,
            x=0.5 + math.cos(radians),
            y=math.sin(radians),
            z=0.0,
            visibility=0.95,
            presence=0.95,
        ),
        28: LandmarkPoint(
            index=28,
            x=1.5 + math.cos(math.radians(angle)),
            y=math.sin(math.radians(angle)),
            z=0.0,
            visibility=0.95,
            presence=0.95,
        ),
    }


def frame_from_landmarks(timestamp_us: int, points: dict[int, LandmarkPoint]) -> TemporalFrame:
    left_knee = (
        calculate_angle(points[23], points[25], points[27], CoordinateSpace.NORMALIZED_IMAGE)
        if all(index in points for index in (23, 25, 27))
        else None
    )
    right_knee = (
        calculate_angle(points[24], points[26], points[28], CoordinateSpace.NORMALIZED_IMAGE)
        if all(index in points for index in (24, 26, 28))
        else None
    )
    left_hip = (
        calculate_angle(points[11], points[23], points[25], CoordinateSpace.NORMALIZED_IMAGE)
        if all(index in points for index in (11, 23, 25))
        else None
    )
    right_hip = (
        calculate_angle(points[12], points[24], points[26], CoordinateSpace.NORMALIZED_IMAGE)
        if all(index in points for index in (12, 24, 26))
        else None
    )
    torso = (
        calculate_torso_inclination(
            points[11], points[12], points[23], points[24], CoordinateSpace.NORMALIZED_IMAGE
        )
        if all(index in points for index in (11, 12, 23, 24))
        else None
    )
    confidence = min(
        point.visibility
        for point in points.values()
        if point.visibility is not None
    )
    return TemporalFrame(
        timestamp_us=timestamp_us,
        session_id="landmark-session",
        skill_id="sk_3",
        status=(
            EvaluationStatus.VALID
            if (
                left_knee is not None
                and right_knee is not None
                and left_hip is not None
                and right_hip is not None
                and torso is not None
            )
            else EvaluationStatus.INSUFFICIENT_DATA
        ),
        subject_view="side",
        measurement_confidence=confidence,
        landmarks=tuple(points.values()),
        left_knee_angle=left_knee,
        right_knee_angle=right_knee,
        left_hip_angle=left_hip,
        right_hip_angle=right_hip,
        torso_inclination=torso,
    )


def test_canonical_landmark_sequence_counts_one_real_squat():
    tracker = SquatTemporalTracker()
    angles = [170, 170, 160, 140, 120, 105, 110, 125, 140, 155, 170, 170]
    results = [
        tracker.process(frame_from_landmarks(i * 100_000, landmarks_for_knee_angle(angle)))
        for i, angle in enumerate(angles)
    ]
    assert tracker.repetition_count == 1
    assert sum(result.completed_rep for result in results) == 1


def test_missing_canonical_knee_landmark_cannot_create_a_rep():
    tracker = SquatTemporalTracker()
    points = landmarks_for_knee_angle(110)
    del points[25]
    result = tracker.process(frame_from_landmarks(0, points))
    assert result.status == EvaluationStatus.INSUFFICIENT_DATA
    assert result.repetition_count == 0
    assert not result.completed_rep


def test_temporal_buffer_is_bounded_and_retains_supplied_landmarks():
    tracker = SquatTemporalTracker(max_buffer_size=2)
    points = landmarks_for_knee_angle(170)
    for index in range(3):
        result = tracker.process(
            frame_from_landmarks(index * 100_000, points)
        )
    assert result.buffer_size == 2
    assert result.landmarks_retained == len(points)


def test_global_camera_translation_without_angle_change_does_not_count():
    tracker = SquatTemporalTracker()
    base = landmarks_for_knee_angle(170)
    results = []
    for index in range(12):
        dx = index * 0.30
        translated = {
            landmark_index: LandmarkPoint(
                x=point.x + dx,
                y=point.y + dx,
                z=point.z,
                visibility=point.visibility,
                presence=point.presence,
            )
            for landmark_index, point in base.items()
        }
        results.append(tracker.process(frame_from_landmarks(index * 100_000, translated)))
    assert tracker.repetition_count == 0
    assert all(not result.completed_rep for result in results)
