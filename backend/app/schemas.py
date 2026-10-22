from pydantic import BaseModel
from typing import List, Tuple, Dict, Any, Optional

class JointPoint(BaseModel):
    x: float
    y: float
    z: float
    visibility: float

class PoseInput(BaseModel):
    user_id: str
    keypoints: List[JointPoint]
    # The phone runs MotionMind's compact TFLite quality model locally and
    # sends only its scalar result, never camera pixels.
    on_device_quality_score: Optional[float] = None
    timestamp: float

class BiomechanicsResult(BaseModel):
    elbow_angle: float
    back_angle: float
    balance_index: float
    center_of_gravity: Tuple[float, float]
    velocity: float
    acceleration: float
    efficiency: float
    on_device_quality_score: Optional[float] = None

class PerformanceResult(BaseModel):
    score: int
    is_correct: bool
    detected_mistakes: List[str]

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
    learning_speed: float # e.g. 1.2x multiplier
    weaknesses: List[str]
    predicted_days_to_mastery: int

class SessionRecord(BaseModel):
    session_id: str
    user_id: str
    duration_seconds: int
    calories: float
    final_score: int
    mistakes_log: List[str]
