"""Confidence-aware geometric measurements for the active backend."""

import math
from typing import Dict, Iterable, Optional, Tuple

from fastapi import APIRouter

from app.agents.exercise_profiles import ExerciseProfile, get_exercise_profile
from app.schemas import (
    BiomechanicsResult,
    CoordinateSpace,
    EvaluationStatus,
    LandmarkPoint,
    PoseInput,
)


router = APIRouter(prefix="/biomechanics", tags=["Biomechanics"])

# Canonical MediaPipe Pose indices.
NOSE = 0
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28

# Compatibility order used by the original mobile/backend contract. This is
# an explicit mapping, not a padding/default-value fallback.
LEGACY_NINE_POINT_ORDER = (
    NOSE,
    LEFT_SHOULDER,
    RIGHT_SHOULDER,
    LEFT_ELBOW,
    LEFT_WRIST,
    RIGHT_ELBOW,
    RIGHT_WRIST,
    LEFT_HIP,
    RIGHT_HIP,
)


def _finite(value: float) -> bool:
    return math.isfinite(value)


def _point_is_finite(point: LandmarkPoint) -> bool:
    return _finite(point.x) and _finite(point.y) and _finite(point.z)


def _landmark_map(pose: PoseInput) -> Dict[int, LandmarkPoint]:
    """Build a canonical map from supplied points without inventing points."""

    points = pose.points()
    if not points:
        return {}

    if all(point.index is not None for point in points):
        indices = [int(point.index) for point in points]
        if len(indices) != len(set(indices)):
            # Multiple values for one canonical index make anatomical identity
            # ambiguous; do not let dictionary insertion order choose one.
            return {}
        return {
            int(point.index): point
            for point in points
            if point.index is not None and _point_is_finite(point)
        }

    # A mixed indexed/unindexed array cannot be mapped safely. Do not infer
    # anatomical identity from its position.
    if any(point.index is not None for point in points):
        return {}

    if len(points) == 33:
        return {
            index: point
            for index, point in enumerate(points)
            if _point_is_finite(point)
        }

    if len(points) == len(LEGACY_NINE_POINT_ORDER):
        return {
            index: point
            for index, point in zip(LEGACY_NINE_POINT_ORDER, points)
            if _point_is_finite(point)
        }

    # Partial unindexed arrays are ambiguous. Returning an empty/partial map
    # forces the quality gate to abstain instead of guessing anatomical labels.
    return {}


def _confidence(point: LandmarkPoint, profile: ExerciseProfile) -> Optional[float]:
    if point.visibility is None:
        return None
    if not _finite(point.visibility):
        return None
    if point.presence is not None and not _finite(point.presence):
        return None
    values = [point.visibility]
    if point.presence is not None:
        values.append(point.presence)
    return min(values)


def _reliable(point: LandmarkPoint, profile: ExerciseProfile) -> bool:
    confidence = _confidence(point, profile)
    if confidence is None:
        return False
    if point.visibility is None or point.visibility < profile.heuristic_visibility_threshold:
        return False
    return point.presence is None or point.presence >= profile.heuristic_presence_threshold


def _vector(point_a: LandmarkPoint, point_b: LandmarkPoint, coordinate_space: CoordinateSpace) -> Tuple[float, float, float]:
    if coordinate_space == CoordinateSpace.WORLD:
        return point_a.x - point_b.x, point_a.y - point_b.y, point_a.z - point_b.z
    # Normalized image landmarks have a relative z, not metric depth. Use only
    # the image plane for geometric angles unless true world landmarks arrive.
    return point_a.x - point_b.x, point_a.y - point_b.y, 0.0


def calculate_angle(
    point_a: LandmarkPoint,
    vertex: LandmarkPoint,
    point_c: LandmarkPoint,
    coordinate_space: CoordinateSpace = CoordinateSpace.NORMALIZED_IMAGE,
) -> Optional[float]:
    """Return angle ABC in degrees, or None for invalid/degenerate geometry."""

    if not all(_point_is_finite(point) for point in (point_a, vertex, point_c)):
        return None
    v1 = _vector(point_a, vertex, coordinate_space)
    v2 = _vector(point_c, vertex, coordinate_space)
    mag1 = math.sqrt(sum(component * component for component in v1))
    mag2 = math.sqrt(sum(component * component for component in v2))
    if mag1 <= 1e-8 or mag2 <= 1e-8:
        return None
    cosine = sum(a * b for a, b in zip(v1, v2)) / (mag1 * mag2)
    if not _finite(cosine):
        return None
    cosine = max(-1.0, min(1.0, cosine))
    result = math.degrees(math.acos(cosine))
    return round(result, 3) if _finite(result) else None


def _midpoint(a: LandmarkPoint, b: LandmarkPoint) -> LandmarkPoint:
    visibility = None if a.visibility is None or b.visibility is None else min(a.visibility, b.visibility)
    presence = None if a.presence is None or b.presence is None else min(a.presence, b.presence)
    return LandmarkPoint(
        x=(a.x + b.x) / 2.0,
        y=(a.y + b.y) / 2.0,
        z=(a.z + b.z) / 2.0,
        visibility=visibility,
        presence=presence,
    )


def calculate_torso_inclination(
    left_shoulder: LandmarkPoint,
    right_shoulder: LandmarkPoint,
    left_hip: LandmarkPoint,
    right_hip: LandmarkPoint,
    coordinate_space: CoordinateSpace = CoordinateSpace.NORMALIZED_IMAGE,
) -> Optional[float]:
    """Angle from the hip-to-shoulder segment to the upright reference axis.

    For normalized image coordinates, y increases downward, so upright is
    ``(0, -1, 0)``. For world coordinates, upright is ``(0, 1, 0)``. This is
    an inclination proxy, not spinal curvature or a center-of-mass estimate.
    """

    shoulder = _midpoint(left_shoulder, right_shoulder)
    hip = _midpoint(left_hip, right_hip)
    if not all(_point_is_finite(point) for point in (shoulder, hip)):
        return None
    dx, dy, dz = _vector(shoulder, hip, coordinate_space)
    reference = (0.0, 1.0, 0.0) if coordinate_space == CoordinateSpace.WORLD else (0.0, -1.0, 0.0)
    magnitude = math.sqrt(dx * dx + dy * dy + dz * dz)
    if magnitude <= 1e-8:
        return None
    cosine = (dx * reference[0] + dy * reference[1] + dz * reference[2]) / magnitude
    if not _finite(cosine):
        return None
    cosine = max(-1.0, min(1.0, cosine))
    result = math.degrees(math.acos(cosine))
    return round(result, 3) if _finite(result) else None


def _base_result(
    pose: PoseInput,
    status: EvaluationStatus,
    reason: str,
    profile: Optional[ExerciseProfile] = None,
    confidence: Optional[float] = None,
    available: Optional[list[str]] = None,
    unavailable: Optional[list[str]] = None,
) -> BiomechanicsResult:
    return BiomechanicsResult(
        status=status,
        data_quality_status=status,
        skill_id=profile.skill_id if profile else pose.skill_id,
        coordinate_space=pose.coordinate_space,
        subject_view=pose.subject_view,
        measurement_confidence=confidence,
        available_measurements=available or [],
        unavailable_measurements=unavailable or [],
        reason=reason,
        on_device_quality_score=pose.on_device_quality_score,
    )


@router.post("", response_model=BiomechanicsResult)
async def calculate_biomechanics(pose: PoseInput):
    profile = get_exercise_profile(pose.skill_id, pose.skill_name)
    points = _landmark_map(pose)

    if profile is None:
        return _base_result(
            pose,
            EvaluationStatus.INSUFFICIENT_DATA,
            "No exercise profile was supplied; measurement context is unknown.",
        )

    if not points or pose.human_detected is False or pose.tracking_state in {
        "SEARCHING_FOR_HUMAN",
        "TRACKING_LOST",
    }:
        return _base_result(
            pose,
            EvaluationStatus.TRACKING_LOST,
            "No tracked person is available for biomechanical measurement.",
            profile,
        )

    if pose.subject_view not in profile.supported_views:
        return _base_result(
            pose,
            EvaluationStatus.UNSUPPORTED_VIEW,
            f"Subject view '{pose.subject_view}' is not supported for {profile.name}.",
            profile,
        )

    missing = [index for index in profile.required_landmarks if index not in points]
    if missing:
        return _base_result(
            pose,
            EvaluationStatus.INSUFFICIENT_DATA,
            f"Required landmarks are missing: {missing}.",
            profile,
            unavailable=[f"landmark_{index}" for index in missing],
        )

    low_confidence = [
        index for index in profile.required_landmarks
        if not _reliable(points[index], profile)
    ]
    if low_confidence:
        confidences = [
            _confidence(points[index], profile)
            for index in profile.required_landmarks
            if _confidence(points[index], profile) is not None
        ]
        return _base_result(
            pose,
            EvaluationStatus.LOW_CONFIDENCE,
            f"Required landmarks do not meet configured visibility/presence thresholds: {low_confidence}.",
            profile,
            confidence=min(confidences) if confidences else None,
            unavailable=[f"landmark_{index}" for index in low_confidence],
        )

    confidence_values = [
        _confidence(points[index], profile)
        for index in profile.required_landmarks
        if _confidence(points[index], profile) is not None
    ]
    measurement_confidence = min(confidence_values) if confidence_values else None
    coordinate_space = pose.coordinate_space
    measurements: Dict[str, Optional[float]] = {
        "left_elbow_angle": calculate_angle(
            points[LEFT_SHOULDER], points[LEFT_ELBOW], points[LEFT_WRIST], coordinate_space
        ) if all(index in points for index in (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST)) else None,
        "right_elbow_angle": calculate_angle(
            points[RIGHT_SHOULDER], points[RIGHT_ELBOW], points[RIGHT_WRIST], coordinate_space
        ) if all(index in points for index in (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST)) else None,
        "left_knee_angle": calculate_angle(
            points[LEFT_HIP], points[LEFT_KNEE], points[LEFT_ANKLE], coordinate_space
        ) if all(index in points for index in (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE)) else None,
        "right_knee_angle": calculate_angle(
            points[RIGHT_HIP], points[RIGHT_KNEE], points[RIGHT_ANKLE], coordinate_space
        ) if all(index in points for index in (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE)) else None,
        "left_hip_angle": calculate_angle(
            points[LEFT_SHOULDER], points[LEFT_HIP], points[LEFT_KNEE], coordinate_space
        ) if all(index in points for index in (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE)) else None,
        "right_hip_angle": calculate_angle(
            points[RIGHT_SHOULDER], points[RIGHT_HIP], points[RIGHT_KNEE], coordinate_space
        ) if all(index in points for index in (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE)) else None,
        "torso_inclination": calculate_torso_inclination(
            points[LEFT_SHOULDER], points[RIGHT_SHOULDER], points[LEFT_HIP], points[RIGHT_HIP], coordinate_space
        ),
    }
    if measurements["left_knee_angle"] is not None and measurements["right_knee_angle"] is not None:
        difference = abs(measurements["left_knee_angle"] - measurements["right_knee_angle"])
        measurements["bilateral_knee_symmetry"] = round(max(0.0, 1.0 - difference / 180.0), 3)
    else:
        measurements["bilateral_knee_symmetry"] = None

    unavailable = [name for name, value in measurements.items() if value is None]
    available = [name for name, value in measurements.items() if value is not None]
    if any(name in unavailable for name in profile.required_measurements):
        return _base_result(
            pose,
            EvaluationStatus.INSUFFICIENT_DATA,
            f"At least one required {profile.name} measurement is geometrically degenerate or unavailable.",
            profile,
            measurement_confidence,
            available,
            unavailable,
        )

    return BiomechanicsResult(
        status=EvaluationStatus.VALID,
        data_quality_status=EvaluationStatus.VALID,
        skill_id=profile.skill_id,
        coordinate_space=coordinate_space,
        subject_view=pose.subject_view,
        measurement_confidence=measurement_confidence,
        available_measurements=available,
        unavailable_measurements=unavailable,
        reason=None,
        left_elbow_angle=measurements["left_elbow_angle"],
        right_elbow_angle=measurements["right_elbow_angle"],
        left_knee_angle=measurements["left_knee_angle"],
        right_knee_angle=measurements["right_knee_angle"],
        left_hip_angle=measurements["left_hip_angle"],
        right_hip_angle=measurements["right_hip_angle"],
        torso_inclination=measurements["torso_inclination"],
        bilateral_knee_symmetry=measurements["bilateral_knee_symmetry"],
        on_device_quality_score=pose.on_device_quality_score,
    )
