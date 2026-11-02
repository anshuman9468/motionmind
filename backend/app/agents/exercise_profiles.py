"""The single backend exercise registry.

The values in this module describe *observable* body geometry only.  Angles
and phase thresholds are configurable heuristics and are not expert-validated
accuracy claims.  In particular, the sport profiles do not infer a ball,
bat, load, contact event, force, or injury risk from pose landmarks.
"""

from dataclasses import dataclass
from typing import Optional, Tuple


@dataclass(frozen=True)
class ExerciseProfile:
    skill_id: str
    name: str
    required_landmarks: Tuple[int, ...]
    required_measurements: Tuple[str, ...]
    supported_views: Tuple[str, ...]
    rules_implemented: bool
    heuristic_visibility_threshold: float = 0.60
    heuristic_presence_threshold: float = 0.50
    squat_knee_min: float = 70.0
    squat_knee_max: float = 130.0
    squat_torso_max_inclination: float = 45.0
    category: str = "gym"
    phases: Tuple[str, ...] = ()
    scoring_method: str = "unsupported"
    notes: str = ""


SQUAT_PROFILE = ExerciseProfile(
    skill_id="squat",
    name="Squats",
    required_landmarks=(11, 12, 23, 24, 25, 26, 27, 28),
    required_measurements=("left_knee_angle", "right_knee_angle", "torso_inclination"),
    supported_views=("front", "rear", "side", "unknown"),
    rules_implemented=True,
    category="gym",
    phases=("READY", "DESCENDING", "BOTTOM", "ASCENDING", "COMPLETED_REP"),
    scoring_method="heuristic_squat_geometry",
    notes="Side/front/rear body geometry; initial thresholds are configurable heuristics.",
)

BOXING_PROFILE = ExerciseProfile(
    skill_id="boxing_jab",
    name="Boxing Jab",
    required_landmarks=(0, 11, 12, 13, 14, 15, 16, 23, 24),
    required_measurements=("left_elbow_angle", "right_elbow_angle"),
    supported_views=("front", "rear", "side", "unknown"),
    rules_implemented=True,
    category="sports",
    phases=("GUARD", "PUNCH_INITIATION", "EXTENSION", "RECOVERY"),
    scoring_method="heuristic_arm_geometry",
    notes="Guard and arm geometry only; punch outcome and impact are unsupported.",
)

# Historical aliases remain measurement-only so older clients cannot silently
# gain a new score. New mobile sessions use ``boxing_jab`` explicitly.
LEGACY_BOXING_PROFILE = ExerciseProfile(
    skill_id="sk_boxing",
    name="Boxing (legacy)",
    required_landmarks=BOXING_PROFILE.required_landmarks,
    required_measurements=BOXING_PROFILE.required_measurements,
    supported_views=BOXING_PROFILE.supported_views,
    rules_implemented=False,
    category="sports",
    phases=BOXING_PROFILE.phases,
    scoring_method="unsupported_legacy_alias",
    notes="Use boxing_jab for the exercise-specific profile.",
)

BASKETBALL_PROFILE = ExerciseProfile(
    skill_id="basketball_shooting",
    name="Basketball Shooting",
    required_landmarks=(11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28),
    required_measurements=("left_elbow_angle", "right_elbow_angle", "torso_inclination"),
    supported_views=("front", "rear", "side", "unknown"),
    rules_implemented=True,
    category="sports",
    phases=("SETUP", "LOADING", "EXTENSION", "FOLLOW_THROUGH", "RECOVERY"),
    scoring_method="heuristic_shooting_arm_geometry",
    notes="Observable shooting-arm, knee, and torso geometry; shot outcome is unsupported.",
)

CRICKET_PROFILE = ExerciseProfile(
    skill_id="cricket_batting",
    name="Cricket Batting",
    required_landmarks=(11, 12, 13, 14, 15, 16, 23, 24, 25, 26),
    required_measurements=("left_elbow_angle", "right_elbow_angle", "left_hip_angle", "right_hip_angle", "torso_inclination"),
    supported_views=("front", "rear", "side"),
    rules_implemented=True,
    category="sports",
    phases=("STANCE", "PREPARATION", "SWING_INITIATION", "FOLLOW_THROUGH", "RECOVERY"),
    scoring_method="heuristic_batting_geometry",
    notes="Batting stance and body rotation proxies only; bat/ball events are unsupported.",
)

PUSH_UP_PROFILE = ExerciseProfile(
    skill_id="push_up",
    name="Push-Ups",
    required_landmarks=(11, 12, 13, 14, 15, 16, 23, 24, 27, 28),
    required_measurements=("left_elbow_angle", "right_elbow_angle", "torso_inclination"),
    supported_views=("side", "front", "rear"),
    rules_implemented=True,
    category="gym",
    phases=("READY", "LOWERING", "BOTTOM", "PRESSING", "COMPLETED_REP"),
    scoring_method="heuristic_pushup_geometry",
)

CHEST_FLY_PROFILE = ExerciseProfile(
    skill_id="seated_chest_fly",
    name="Seated Chest Fly",
    required_landmarks=(11, 12, 13, 14, 15, 16, 23, 24),
    required_measurements=("left_elbow_angle", "right_elbow_angle", "torso_inclination"),
    supported_views=("front", "rear", "side"),
    rules_implemented=True,
    category="gym",
    phases=("READY", "OPENING", "OPEN", "CLOSING", "COMPLETED_REP"),
    scoring_method="heuristic_arm_geometry",
    notes="Body geometry only; machine settings and resistance are unsupported.",
)

TRICEP_PUSH_UP_PROFILE = ExerciseProfile(
    skill_id="tricep_push_up",
    name="Tricep Push-Ups",
    required_landmarks=PUSH_UP_PROFILE.required_landmarks,
    required_measurements=PUSH_UP_PROFILE.required_measurements,
    supported_views=PUSH_UP_PROFILE.supported_views,
    rules_implemented=True,
    category="gym",
    phases=("READY", "LOWERING", "BOTTOM", "PRESSING", "COMPLETED_REP"),
    scoring_method="heuristic_triceps_geometry",
)

BENT_OVER_ROW_PROFILE = ExerciseProfile(
    skill_id="bent_over_row",
    name="Bent-Over Row",
    required_landmarks=(11, 12, 13, 14, 15, 16, 23, 24, 25, 26),
    required_measurements=("left_elbow_angle", "right_elbow_angle", "left_hip_angle", "right_hip_angle", "torso_inclination"),
    supported_views=("side", "front", "rear"),
    rules_implemented=True,
    category="gym",
    phases=("READY", "ARM_EXTENSION", "ROWING", "TOP", "RETURNING", "COMPLETED_REP"),
    scoring_method="heuristic_row_geometry",
    notes="Initial interpretation is a bent-over rowing motion; load and grip are unsupported.",
)


_PROFILES = {
    "sk_squat": SQUAT_PROFILE,
    "sk_3": SQUAT_PROFILE,  # Existing squat profile identifier.
    "squat": SQUAT_PROFILE,
    "sk_boxing": LEGACY_BOXING_PROFILE,
    "boxing": BOXING_PROFILE,
    "boxing_jab": BOXING_PROFILE,
    "sk_basketball": BASKETBALL_PROFILE,
    "basketball": BASKETBALL_PROFILE,
    "basketball_shooting": BASKETBALL_PROFILE,
    "cricket_batting": CRICKET_PROFILE,
    "push_up": PUSH_UP_PROFILE,
    "seated_chest_fly": CHEST_FLY_PROFILE,
    "tricep_push_up": TRICEP_PUSH_UP_PROFILE,
    "bent_over_row": BENT_OVER_ROW_PROFILE,
    "sk_1": BASKETBALL_PROFILE,  # Existing basketball skill identifier.
}


def get_exercise_profile(skill_id: str, skill_name: Optional[str] = None) -> Optional[ExerciseProfile]:
    """Resolve an explicit skill id/name without silently choosing a default."""

    normalized_id = (skill_id or "").strip().lower()
    if normalized_id in _PROFILES:
        profile = _PROFILES[normalized_id]
        # Existing catalog ids are reused for different historical screens;
        # an explicit skill name wins when it disambiguates them.
        normalized_name = (skill_name or "").lower()
        # Keep an explicitly supplied historical ID stable. The new canonical
        # IDs below are the only IDs that opt into their exercise profiles.
        if normalized_id == "sk_boxing":
            return LEGACY_BOXING_PROFILE
        if "boxing" in normalized_name:
            return BOXING_PROFILE
        if "cricket" in normalized_name or "batting" in normalized_name:
            return CRICKET_PROFILE
        if "basket" in normalized_name or "shoot" in normalized_name:
            return BASKETBALL_PROFILE
        if "squat" in normalized_name or "powerlift" in normalized_name:
            return SQUAT_PROFILE
        if "push" in normalized_name:
            return TRICEP_PUSH_UP_PROFILE if "tricep" in normalized_name else PUSH_UP_PROFILE
        if "chest" in normalized_name or "fly" in normalized_name:
            return CHEST_FLY_PROFILE
        if "row" in normalized_name or "bent" in normalized_name:
            return BENT_OVER_ROW_PROFILE
        return profile

    normalized_name = (skill_name or normalized_id).lower()
    if "boxing" in normalized_name or "jab" in normalized_name:
        return BOXING_PROFILE
    if "cricket" in normalized_name or "batting" in normalized_name:
        return CRICKET_PROFILE
    if "basket" in normalized_name or "shoot" in normalized_name:
        return BASKETBALL_PROFILE
    if "squat" in normalized_name or "powerlift" in normalized_name:
        return SQUAT_PROFILE
    if "tricep" in normalized_name:
        return TRICEP_PUSH_UP_PROFILE
    if "push" in normalized_name:
        return PUSH_UP_PROFILE
    if "chest" in normalized_name or "fly" in normalized_name:
        return CHEST_FLY_PROFILE
    if "row" in normalized_name or "bent" in normalized_name:
        return BENT_OVER_ROW_PROFILE
    return None
