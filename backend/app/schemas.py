"""Versioned API contracts shared by the mobile client and agent routers.

The important invariant in this module is that unavailable measurements are
represented by ``None`` and a status/reason, never by a plausible default
number.  The active mobile path sends canonical MediaPipe landmark indices;
``keypoints`` remains as a compatibility input for the old nine-point tests.
"""

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


class EvaluationStatus(str, Enum):
    VALID = "VALID"
    LOW_CONFIDENCE = "LOW_CONFIDENCE"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    UNSUPPORTED_VIEW = "UNSUPPORTED_VIEW"
    TRACKING_LOST = "TRACKING_LOST"


class SquatPhase(str, Enum):
    """Observable squat phases emitted by the temporal state machine."""

    STANDING = "STANDING"
    DESCENDING = "DESCENDING"
    BOTTOM = "BOTTOM"
    ASCENDING = "ASCENDING"
    COMPLETED_REP = "COMPLETED_REP"


class CoordinateSpace(str, Enum):
    NORMALIZED_IMAGE = "normalized_image"
    WORLD = "world"


class LandmarkPoint(BaseModel):
    """One MediaPipe Pose landmark, optionally carrying its canonical index."""

    index: Optional[int] = Field(default=None, ge=0, le=32)
    x: float
    y: float
    z: float
    visibility: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    presence: Optional[float] = Field(default=None, ge=0.0, le=1.0)


class PoseInput(BaseModel):
    schema_version: str = "1.0"
    user_id: str
    session_id: Optional[str] = None
    skill_id: str = "unknown"
    skill_name: Optional[str] = None

    # ``landmarks`` is the canonical field. ``keypoints`` is retained only so
    # older callers fail closed rather than requiring fabricated values.
    landmarks: List[LandmarkPoint] = Field(default_factory=list)
    keypoints: List[LandmarkPoint] = Field(default_factory=list)

    coordinate_space: CoordinateSpace = CoordinateSpace.NORMALIZED_IMAGE
    image_width: Optional[int] = Field(default=None, gt=0)
    image_height: Optional[int] = Field(default=None, gt=0)
    timestamp_us: Optional[int] = Field(default=None, ge=0)
    # Deprecated compatibility timestamp. It is not used for derivatives.
    timestamp: Optional[float] = None
    camera_facing: Optional[str] = None
    subject_view: str = "unknown"
    mirrored: Optional[bool] = None
    rotation_degrees: Optional[int] = None
    human_detected: Optional[bool] = None
    tracking_state: Optional[str] = None
    on_device_quality_score: Optional[float] = Field(default=None, ge=0.0, le=100.0)

    def points(self) -> List[LandmarkPoint]:
        """Return only landmarks supplied by the caller, without padding."""

        return self.landmarks if self.landmarks else self.keypoints


class BiomechanicsResult(BaseModel):
    schema_version: str = "1.0"
    status: EvaluationStatus
    data_quality_status: EvaluationStatus
    skill_id: str
    coordinate_space: CoordinateSpace
    subject_view: str
    measurement_confidence: Optional[float] = None
    available_measurements: List[str] = Field(default_factory=list)
    unavailable_measurements: List[str] = Field(default_factory=list)
    reason: Optional[str] = None

    # Supported geometric measurements. ``None`` means unavailable, not zero.
    left_elbow_angle: Optional[float] = None
    right_elbow_angle: Optional[float] = None
    left_knee_angle: Optional[float] = None
    right_knee_angle: Optional[float] = None
    left_hip_angle: Optional[float] = None
    right_hip_angle: Optional[float] = None
    torso_inclination: Optional[float] = None
    bilateral_knee_symmetry: Optional[float] = None
    on_device_quality_score: Optional[float] = None


class PerformanceResult(BaseModel):
    schema_version: str = "1.0"
    status: EvaluationStatus
    skill_id: str
    quality_score: Optional[float] = None
    xp: Optional[int] = None
    is_correct: Optional[bool] = None
    detected_mistakes: List[str] = Field(default_factory=list)
    verified_findings: List[str] = Field(default_factory=list)
    feedback_eligible: bool = False
    rules_are_heuristic: bool = True
    scoring_method: Optional[str] = None
    category: Optional[str] = None
    reason: Optional[str] = None


class CoachResponse(BaseModel):
    feedback_text: str
    audio_cues: List[str]
    motivation: str


class RecommendationResponse(BaseModel):
    warmups: List[str]
    cooldowns: List[str]
    target_drills: List[str]


class TwinProfile(BaseModel):
    user_id: str
    learning_speed: float
    weaknesses: List[str]
    predicted_days_to_mastery: int


class SessionRecord(BaseModel):
    session_id: str
    user_id: str
    duration_seconds: int
    calories: Optional[float] = None
    final_score: Optional[float] = None
    mistakes_log: List[str]
    repetitions: Optional[int] = None
    exercise_id: Optional[str] = None
    category: Optional[str] = None
    tracking_quality: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    valid_frames: Optional[int] = Field(default=None, ge=0)
    rejected_frames: Optional[int] = Field(default=None, ge=0)
    processing_latency_ms: Optional[float] = Field(default=None, ge=0)
    confidence_reasons: List[str] = Field(default_factory=list)
    verified_findings: List[str] = Field(default_factory=list)
    camera_facing: Optional[str] = None
    subject_view: Optional[str] = None
    schema_version: str = "1.0"


class TemporalPoseInput(BaseModel):
    """One timestamped, already measured pose sample.

    The temporal service intentionally consumes measurements produced by the
    confidence-gated biomechanics service.  It does not accept pixels or
    manufacture missing angles.  Nullable angle fields are required so a lost
    track can be represented without sentinel numbers.
    """

    schema_version: str = "1.0"
    user_id: str
    session_id: str
    skill_id: str
    timestamp_us: int = Field(ge=0)
    subject_view: str = "unknown"
    status: EvaluationStatus
    measurement_confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    landmarks: List[LandmarkPoint] = Field(default_factory=list)
    left_knee_angle: Optional[float] = None
    right_knee_angle: Optional[float] = None
    left_hip_angle: Optional[float] = None
    right_hip_angle: Optional[float] = None
    left_elbow_angle: Optional[float] = None
    right_elbow_angle: Optional[float] = None
    torso_inclination: Optional[float] = None
    bilateral_knee_symmetry: Optional[float] = Field(default=None, ge=0.0, le=1.0)


class TemporalAnalysisResult(BaseModel):
    schema_version: str = "1.0"
    status: EvaluationStatus
    skill_id: str
    session_id: str
    phase: SquatPhase
    phase_label: Optional[str] = None
    repetition_count: int = 0
    completed_rep: bool = False
    smoothed_knee_angle: Optional[float] = None
    movement_direction: Optional[str] = None
    movement_speed_degrees_per_second: Optional[float] = None
    torso_inclination: Optional[float] = None
    left_hip_angle: Optional[float] = None
    right_hip_angle: Optional[float] = None
    bilateral_knee_symmetry: Optional[float] = None
    feedback_eligible: bool = False
    feedback: List[str] = Field(default_factory=list)
    # IDs emitted only by the deterministic temporal rule layer. These are
    # explanatory findings, not model-accuracy labels.
    verified_findings: List[str] = Field(default_factory=list)
    reason: Optional[str] = None
    buffer_size: int = 0
    landmarks_retained: int = 0
