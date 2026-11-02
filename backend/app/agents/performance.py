"""Exercise-aware rule evaluation with fail-closed result semantics."""

from fastapi import APIRouter

from app.agents.exercise_profiles import get_exercise_profile
from app.schemas import BiomechanicsResult, EvaluationStatus, PerformanceResult


router = APIRouter(prefix="/performance", tags=["Performance"])


def _unavailable(metrics: BiomechanicsResult, reason: str) -> PerformanceResult:
    profile = get_exercise_profile(metrics.skill_id)
    return PerformanceResult(
        status=metrics.status,
        skill_id=metrics.skill_id,
        quality_score=None,
        xp=None,
        is_correct=None,
        detected_mistakes=[],
        verified_findings=[],
        feedback_eligible=False,
        rules_are_heuristic=True,
        scoring_method=profile.scoring_method if profile else None,
        category=profile.category if profile else None,
        reason=reason,
    )


def _range_check(
    *,
    value: float | None,
    minimum: float,
    maximum: float,
    finding: str,
    label: str,
    mistakes: list[str],
    findings: list[str],
    deduction: float,
) -> float:
    """Apply one explicitly heuristic range check and return its deduction."""

    if value is None:
        return 0.0
    if minimum <= value <= maximum:
        return 0.0
    mistakes.append(
        f"{label} {value:.1f}° is outside the configurable heuristic range "
        f"{minimum:.0f}–{maximum:.0f}°."
    )
    findings.append(finding)
    return deduction


def _evaluate_exercise(metrics: BiomechanicsResult, profile) -> tuple[list[str], list[str], float]:
    """Evaluate only measurements declared by the selected profile.

    These first-pass ranges are deliberately conservative, configurable
    heuristics. They are not a claim of expert technique or model accuracy.
    """

    mistakes: list[str] = []
    findings: list[str] = []
    deduction = 0.0

    if profile.name == "Squats":
        knee_values = (metrics.left_knee_angle, metrics.right_knee_angle)
        if any(value is None for value in knee_values) or metrics.torso_inclination is None:
            return ["Squat scoring requires both knee angles and torso inclination."], [], 100.0
        for side, angle in zip(("Left", "Right"), knee_values):
            deduction += _range_check(
                value=angle,
                minimum=profile.squat_knee_min,
                maximum=profile.squat_knee_max,
                finding="squat_knee_range",
                label=f"{side} knee angle",
                mistakes=mistakes,
                findings=findings,
                deduction=20.0,
            )
        if metrics.torso_inclination > profile.squat_torso_max_inclination:
            mistakes.append(
                f"Torso inclination {metrics.torso_inclination:.1f}° exceeds the "
                f"configurable heuristic limit of {profile.squat_torso_max_inclination:.0f}°."
            )
            findings.append("squat_torso_inclination")
            deduction += 20.0
        if metrics.bilateral_knee_symmetry is not None and metrics.bilateral_knee_symmetry < 0.80:
            mistakes.append(
                f"Bilateral knee symmetry is {metrics.bilateral_knee_symmetry:.2f}, below the configurable heuristic limit of 0.80."
            )
            findings.append("squat_bilateral_symmetry")
            deduction += 15.0
        return mistakes, findings, deduction

    elbow_values = (metrics.left_elbow_angle, metrics.right_elbow_angle)
    if profile.skill_id in {"push_up", "tricep_push_up"}:
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=70.0, maximum=175.0,
                finding=f"{profile.skill_id}_elbow_range", label=f"{side} elbow angle",
                mistakes=mistakes, findings=findings, deduction=15.0,
            )
        if metrics.torso_inclination is not None:
            deduction += _range_check(
                value=metrics.torso_inclination, minimum=0.0, maximum=35.0,
                finding=f"{profile.skill_id}_torso_alignment", label="Torso inclination",
                mistakes=mistakes, findings=findings, deduction=20.0,
            )
    elif profile.skill_id == "seated_chest_fly":
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=70.0, maximum=180.0,
                finding="seated_chest_fly_elbow_range", label=f"{side} elbow angle",
                mistakes=mistakes, findings=findings, deduction=15.0,
            )
        deduction += _range_check(
            value=metrics.torso_inclination, minimum=0.0, maximum=35.0,
            finding="seated_chest_fly_torso", label="Torso inclination",
            mistakes=mistakes, findings=findings, deduction=20.0,
        )
    elif profile.skill_id == "bent_over_row":
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=45.0, maximum=175.0,
                finding="bent_over_row_elbow_range", label=f"{side} elbow angle",
                mistakes=mistakes, findings=findings, deduction=15.0,
            )
        deduction += _range_check(
            value=metrics.torso_inclination, minimum=15.0, maximum=75.0,
            finding="bent_over_row_torso", label="Torso inclination",
            mistakes=mistakes, findings=findings, deduction=20.0,
        )
    elif profile.skill_id == "boxing_jab":
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=60.0, maximum=180.0,
                finding="boxing_jab_elbow_geometry", label=f"{side} elbow angle",
                mistakes=mistakes, findings=findings, deduction=15.0,
            )
        deduction += _range_check(
            value=metrics.torso_inclination, minimum=0.0, maximum=50.0,
            finding="boxing_jab_torso_control", label="Torso inclination",
            mistakes=mistakes, findings=findings, deduction=15.0,
        )
    elif profile.skill_id == "basketball_shooting":
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=80.0, maximum=180.0,
                finding="basketball_shooting_elbow_geometry", label=f"{side} shooting elbow angle",
                mistakes=mistakes, findings=findings, deduction=15.0,
            )
        for side, angle in zip(("Left", "Right"), (metrics.left_knee_angle, metrics.right_knee_angle)):
            deduction += _range_check(
                value=angle, minimum=70.0, maximum=180.0,
                finding="basketball_shooting_knee_geometry", label=f"{side} knee angle",
                mistakes=mistakes, findings=findings, deduction=10.0,
            )
    elif profile.skill_id == "cricket_batting":
        for side, angle in zip(("Left", "Right"), elbow_values):
            deduction += _range_check(
                value=angle, minimum=45.0, maximum=180.0,
                finding="cricket_batting_arm_geometry", label=f"{side} batting elbow angle",
                mistakes=mistakes, findings=findings, deduction=10.0,
            )
        for side, angle in zip(("Left", "Right"), (metrics.left_hip_angle, metrics.right_hip_angle)):
            deduction += _range_check(
                value=angle, minimum=45.0, maximum=180.0,
                finding="cricket_batting_hip_geometry", label=f"{side} hip angle",
                mistakes=mistakes, findings=findings, deduction=10.0,
            )

    return mistakes, findings, deduction


@router.post("", response_model=PerformanceResult)
async def evaluate_performance(metrics: BiomechanicsResult):
    if metrics.status != EvaluationStatus.VALID:
        return _unavailable(
            metrics,
            metrics.reason or "Biomechanical measurements are not reliable enough to score.",
        )

    profile = get_exercise_profile(metrics.skill_id)
    if profile is None:
        return _unavailable(metrics, "No exercise profile is available for this skill.")

    if not profile.rules_implemented:
        return PerformanceResult(
            status=EvaluationStatus.INSUFFICIENT_DATA,
            skill_id=metrics.skill_id,
            quality_score=None,
            xp=None,
            is_correct=None,
            detected_mistakes=[],
            verified_findings=[],
            feedback_eligible=False,
            rules_are_heuristic=True,
            scoring_method=profile.scoring_method,
            category=profile.category,
            reason=(
                f"Measurements are valid, but the {profile.name} rule engine is not implemented yet."
            ),
        )

    mistakes, findings, deduction = _evaluate_exercise(metrics, profile)
    quality_score = max(0.0, min(100.0, 100.0 - deduction))
    return PerformanceResult(
        status=EvaluationStatus.VALID,
        skill_id=metrics.skill_id,
        quality_score=round(quality_score, 1),
        # XP is explicitly separate from the quality score. It is a
        # gamification value, not an accuracy or biomechanical measurement.
        xp=int(round(quality_score * 12.5)),
        is_correct=not mistakes,
        detected_mistakes=mistakes,
        verified_findings=findings,
        feedback_eligible=True,
        rules_are_heuristic=True,
        scoring_method=profile.scoring_method,
        category=profile.category,
        reason=None,
    )
