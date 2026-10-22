import os
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
import google.generativeai as genai
from app.schemas import CoachResponse

router = APIRouter(prefix="/coach", tags=["Coach"])

class CoachRequest(BaseModel):
    detected_mistakes: List[str]
    practice_score: int

@router.post("", response_model=CoachResponse)
async def generate_coach_feedback(req: CoachRequest):
    # Retrieve GEMINI_API_KEY from env
    api_key = os.getenv("GEMINI_API_KEY")
    
    # Prompt construction
    prompt = (
        "You are Hercules AI, an ancient Greek trainer and elite biomechanics coach. "
        "Your task is to analyze these posture mistakes: "
        f"{', '.join(req.detected_mistakes) if req.detected_mistakes else 'No mistakes. Form is flawless.'}. "
        f"The user achieved a practice score of {req.practice_score} XP. "
        "Construct a response in JSON format matching this structure:\n"
        "{\n"
        "  \"feedback_text\": \"Short explanation of errors and corrections\",\n"
        "  \"audio_cues\": [\"Cue 1\", \"Cue 2\"],\n"
        "  \"motivation\": \"A powerful motivational sentence invoking Greek mythology\"\n"
        "}\n"
        "Keep the responses concise and vocal-friendly."
    )

    if api_key:
        try:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-1.5-flash')
            response = model.generate_content(
                prompt,
                generation_config={"response_mime_type": "application/json"}
            )
            # Parse response
            import json
            data = json.loads(response.text.strip())
            return CoachResponse(
                feedback_text=data.get("feedback_text", "Form corrections requested."),
                audio_cues=data.get("audio_cues", ["Adjust alignment"]),
                motivation=data.get("motivation", "Awake the strength of Olympus!")
            )
        except Exception as e:
            # Fallback on Gemini errors
            debug_err = str(e)
    
    # Elegant simulated fallback generator (if API key is missing or calls fail)
    if not req.detected_mistakes:
        return CoachResponse(
            feedback_text="Your technique is flawless! Your joints are fully synchronized with the divine templates.",
            audio_cues=["Flawless execution", "Maintain this posture"],
            motivation="By the gods, you demonstrate the balance and posture of Apollo himself!"
        )
    
    cues = []
    explanations = []
    
    for mistake in req.detected_mistakes:
        if "elbow" in mistake.lower():
            cues.append("Raise your elbow.")
            explanations.append("Keep your elbow elevated above your torso to maintain peak mechanical force.")
        if "back" in mistake.lower() or "spine" in mistake.lower():
            cues.append("Straighten your back.")
            explanations.append("Avoid leaning or curving your spine to prevent injury and keep core stability.")
        if "balance" in mistake.lower() or "gravity" in mistake.lower():
            cues.append("Rebalance your center of gravity.")
            explanations.append("Redistribute your body weight evenly across your target center point.")

    if not cues:
        cues = ["Focus on alignment"]
        explanations = ["Review your target outline coordinates."]

    feedback = " ".join(explanations)
    return CoachResponse(
        feedback_text=feedback,
        audio_cues=cues,
        motivation="Remember: Hercules did not build his strength in one day. Focus, realign your joints, and conquer the next trial!"
    )
