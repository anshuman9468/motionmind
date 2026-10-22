from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
from app.schemas import RecommendationResponse

router = APIRouter(prefix="/recommendation", tags=["Recommendation"])

class RecommendationRequest(BaseModel):
    detected_weaknesses: List[str]
    experience_level: str

@router.post("", response_model=RecommendationResponse)
async def generate_recommendations(req: RecommendationRequest):
    warmups = ["5 min Dynamic Shoulder Rotations", "3 min Core Activation Plank"]
    cooldowns = ["5 min Static Hamstring Stretch", "3 min Child's Pose Breathing"]
    drills = []

    # Map weaknesses to specific biomechanical correction drills
    has_elbow_weakness = any("elbow" in w.lower() for w in req.detected_weaknesses)
    has_back_weakness = any("back" in w.lower() or "spine" in w.lower() for w in req.detected_weaknesses)
    has_balance_weakness = any("balance" in w.lower() or "gravity" in w.lower() for w in req.detected_weaknesses)

    if has_elbow_weakness:
        drills.append("Ares Arm Extension: 3 sets of 15 repetitions focusing on slow-tempo extension")
        warmups.append("Wrists & Elbows rotation")
    
    if has_back_weakness:
        drills.append("Atlas Core Lock: 4 sets of 30-second structural dead-hangs")
        warmups.append("Cat-Cow spine flexes")
        cooldowns.append("Deep lumbar flexion release")

    if has_balance_weakness:
        drills.append("Poseidon Balance Stand: Single-leg targeting holds on a balance pad")
        drills.append("Hestia Meditative Alignment: Slow closed-eye stance calibrations")

    # Add fallback default drills if list is empty
    if not drills:
        drills = ["Olympus Trial Run: 3 sets of dynamic pose-switching matches"]

    return RecommendationResponse(
        warmups=warmups,
        cooldowns=cooldowns,
        target_drills=drills
    )
