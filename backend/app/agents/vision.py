"""Pose quality gate for the active backend.

This endpoint intentionally does not claim to detect movement from one frame.
The Phase 3 temporal router consumes timestamped measurements separately, while
this endpoint keeps frame quality and native tracking state explicit.
"""

from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

from app.agents.exercise_profiles import get_exercise_profile
from app.schemas import EvaluationStatus, PoseInput


router = APIRouter(prefix="/vision", tags=["Vision"])


class VisionResult(BaseModel):
    schema_version: str = "1.0"
    status: EvaluationStatus
    is_moving: Optional[bool] = None
    detected_landmarks_count: int
    tracking_quality_index: Optional[float] = None
    reason: Optional[str] = None


@router.post("", response_model=VisionResult)
async def process_media_pipe(pose: PoseInput):
    points = pose.points()
    profile = get_exercise_profile(pose.skill_id, pose.skill_name)
    if not points:
        return VisionResult(
            status=EvaluationStatus.TRACKING_LOST,
            is_moving=None,
            detected_landmarks_count=0,
            tracking_quality_index=None,
            reason="No landmarks were supplied.",
        )

    if pose.human_detected is False or pose.tracking_state in {
        "SEARCHING_FOR_HUMAN",
        "TRACKING_LOST",
    }:
        return VisionResult(
            status=EvaluationStatus.TRACKING_LOST,
            is_moving=None,
            detected_landmarks_count=len(points),
            tracking_quality_index=None,
            reason="The native tracker reports that the person is not locked.",
        )

    visibility = [point.visibility for point in points if point.visibility is not None]
    if not visibility:
        return VisionResult(
            status=EvaluationStatus.INSUFFICIENT_DATA,
            is_moving=None,
            detected_landmarks_count=len(points),
            tracking_quality_index=None,
            reason="Visibility was not supplied by the pose model.",
        )

    quality = round(min(visibility), 3)
    threshold = profile.heuristic_visibility_threshold if profile else 0.60
    status = EvaluationStatus.VALID if quality >= threshold else EvaluationStatus.LOW_CONFIDENCE
    if pose.tracking_state == "BODY_NOT_CLEAR" and status == EvaluationStatus.VALID:
        status = EvaluationStatus.LOW_CONFIDENCE

    return VisionResult(
        status=status,
        # A single frame cannot establish movement. ``None`` is intentional.
        is_moving=None,
        detected_landmarks_count=len(points),
        tracking_quality_index=quality,
        reason=None if status == EvaluationStatus.VALID else "Landmark visibility is below the configured frame threshold.",
    )
