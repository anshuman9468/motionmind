import os
import json
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from app.schemas import CoachResponse, EvaluationStatus

try:
    # google-generativeai is deprecated. The maintained google-genai package
    # exposes the client through ``google.genai``.
    from google import genai
    from google.genai import types as genai_types
except ImportError:  # pragma: no cover - optional dependency in offline runs
    genai = None
    genai_types = None

router = APIRouter(prefix="/coach", tags=["Coach"])

class CoachRequest(BaseModel):
    detected_mistakes: List[str]
    practice_score: Optional[int] = None
    analysis_status: Optional[EvaluationStatus] = None
    skill_id: Optional[str] = None
    quality_score: Optional[float] = None
    phase: Optional[str] = None
    confidence_status: Optional[EvaluationStatus] = None
    verified_findings: List[str] = Field(default_factory=list)
    verified_measurements: Dict[str, float] = Field(default_factory=dict)

@router.post("", response_model=CoachResponse)
async def generate_coach_feedback(req: CoachRequest):
    if req.analysis_status != EvaluationStatus.VALID or req.quality_score is None:
        return CoachResponse(
            feedback_text=(
                "I cannot verify technique from this frame yet. Reposition so your "
                "required joints are visible, then try again."
            ),
            audio_cues=["Step back and show your full body", "Hold still briefly"],
            motivation="Reliable feedback starts with a clear, trackable pose.",
        )

    # Retrieve GEMINI_API_KEY from env
    api_key = os.getenv("GEMINI_API_KEY")
    
    # Prompt construction
    prompt = (
        "You are Hercules AI, an ancient Greek trainer and elite biomechanics coach. "
        "Your task is to explain only these verified technique findings: "
        f"{', '.join(req.verified_findings or req.detected_mistakes) if (req.verified_findings or req.detected_mistakes) else 'No verified findings.'}. "
        f"Verified measurements (use only as context): {req.verified_measurements}. "
        f"The measured heuristic quality score is {req.quality_score}. "
        f"The observed phase is {req.phase or 'not available'} and the confidence status is {req.confidence_status or 'not available'}. "
        "Do not invent angles, measurements, injuries, or diagnoses. "
        "Construct a response in JSON format matching this structure:\n"
        "{\n"
        "  \"feedback_text\": \"Short explanation of errors and corrections\",\n"
        "  \"audio_cues\": [\"Cue 1\", \"Cue 2\"],\n"
        "  \"motivation\": \"A powerful motivational sentence invoking Greek mythology\"\n"
        "}\n"
        "Keep the responses concise and vocal-friendly."
    )

    if api_key and genai is not None:
        try:
            client = genai.Client(api_key=api_key)
            config = (
                genai_types.GenerateContentConfig(
                    response_mime_type="application/json",
                )
                if genai_types is not None
                else {"response_mime_type": "application/json"}
            )
            response = client.models.generate_content(
                model=os.getenv("GEMINI_MODEL", "gemini-2.0-flash"),
                contents=prompt,
                config=config,
            )
            data = json.loads((getattr(response, "text", "") or "").strip())
            return CoachResponse(
                feedback_text=data.get("feedback_text", "Form corrections requested."),
                audio_cues=data.get("audio_cues", ["Adjust alignment"]),
                motivation=data.get("motivation", "Awake the strength of Olympus!")
            )
        except Exception:
            # Fallback on Gemini errors
            pass
    
    # Elegant simulated fallback generator (if API key is missing or calls fail)
    if not req.detected_mistakes and not req.verified_findings:
        return CoachResponse(
            feedback_text="No verified technique issue was detected in this valid frame. Maintain the position and continue steadily.",
            audio_cues=["Maintain alignment", "Continue steadily"],
            motivation="Consistent, controlled practice builds reliable progress."
        )
    
    # The deterministic rule engine is the source of truth. Do not infer
    # spine, balance, force, injury, or other unsupported findings from free
    # text that may have come from an older caller. Only explain finding IDs
    # emitted by the active exercise profiles.
    finding_messages = {
        "squat_depth": (
            "The measured squat did not reach the configured depth range.",
            "Use a controlled descent and work toward your configured depth target.",
        ),
        "squat_knee_range": (
            "Keep both knees within the configured squat range.",
            "Control the descent and adjust depth to the measured knee-angle target.",
        ),
        "squat_torso_inclination": (
            "Reduce observable torso lean.",
            "Keep the trunk controlled while the measured shoulder-to-hip angle is evaluated.",
        ),
        "squat_bilateral_symmetry": (
            "Keep both knees tracking evenly.",
            "Use the measured left/right knee difference to guide a more even descent.",
        ),
        "boxing_jab_elbow_geometry": (
            "Keep the punching elbow in the measured guard or extension range.",
            "Extend and recover the arm smoothly; impact and force are not measured.",
        ),
        "boxing_jab_torso_control": (
            "Keep the observable torso controlled during the jab.",
            "Return to a stable guard before the next punch.",
        ),
        "basketball_shooting_elbow_geometry": (
            "Use the measured shooting-arm elbow alignment as your cue.",
            "Keep the elbow path controlled through extension; ball outcome is not measured.",
        ),
        "basketball_shooting_knee_geometry": (
            "Keep the observable knee bend consistent with the selected shooting phase.",
            "Load and extend under control; jump result is not measured.",
        ),
        "cricket_batting_arm_geometry": (
            "Keep the visible batting-arm geometry controlled.",
            "Use a smooth preparation and follow-through; bat and ball events are not measured.",
        ),
        "cricket_batting_hip_geometry": (
            "Keep the observable hip alignment controlled during the batting motion.",
            "Use the measured torso and hip proxy without assuming bat contact or shot placement.",
        ),
        "push_up_elbow_range": (
            "Keep both elbows in the configured push-up geometry range.",
            "Lower and press with a controlled elbow path.",
        ),
        "push_up_torso_alignment": (
            "Keep the visible body line controlled during the push-up.",
            "Brace the torso without allowing the measured shoulder-to-hip line to sag.",
        ),
        "tricep_push_up_elbow_range": (
            "Keep the elbows close and within the configured triceps geometry range.",
            "Use a controlled close-grip descent and press.",
        ),
        "tricep_push_up_torso_alignment": (
            "Keep the visible body line controlled during the close-grip push-up.",
            "Move as one unit through the measured range.",
        ),
        "seated_chest_fly_elbow_range": (
            "Keep both elbows in the measured chest-fly range.",
            "Open and close the arms without swinging the elbows.",
        ),
        "seated_chest_fly_torso": (
            "Keep the seated torso stable.",
            "The camera can evaluate body geometry, not machine load or resistance.",
        ),
        "bent_over_row_elbow_range": (
            "Use a controlled elbow pull and return.",
            "Keep the visible elbows within the configured row geometry range.",
        ),
        "bent_over_row_torso": (
            "Maintain the configured bent-over torso orientation.",
            "Keep the torso steady while the elbows travel; load and back injury risk are not measured.",
        ),
    }
    cues = []
    explanations = []
    for finding in req.verified_findings:
        message = finding_messages.get(finding)
        if message is not None:
            cues.append(message[0])
            explanations.append(message[1])

    if not cues:
        return CoachResponse(
            feedback_text=(
                "The frame is valid, but no supported correction was identified "
                "by the deterministic rule engine."
            ),
            audio_cues=["Continue with controlled movement"],
            motivation="Consistent, measured practice builds reliable progress.",
        )

    feedback = " ".join(explanations)
    return CoachResponse(
        feedback_text=feedback,
        audio_cues=cues,
        motivation="Remember: Hercules did not build his strength in one day. Focus, realign your joints, and conquer the next trial!"
    )
