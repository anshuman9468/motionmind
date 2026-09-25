from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/planner", tags=["Planner"])

class PlannerRequest(BaseModel):
    preferred_skills: List[str]
    experience_level: str

class Lesson(BaseModel):
    title: str
    focus: str
    target_score: int

class RoadmapResponse(BaseModel):
    roadmap_steps: List[str]
    lesson_of_the_day: Lesson

@router.post("", response_model=RoadmapResponse)
async def generate_roadmap(req: PlannerRequest):
    if not req.preferred_skills:
        raise HTTPException(status_code=400, detail="Preferred skills list is required")

    # Generate custom roadmap steps based on experience level
    level = req.experience_level.lower()
    steps = []
    
    if level == "novice":
        steps = [
            f"Introduce fundamental posture structures for {req.preferred_skills[0]}",
            "Establish joint flexibility targets and basic core stance balance",
            "Simulate slow-tempo range-of-motion repetitions"
        ]
        daily_lesson = Lesson(
            title=f"Basic stance alignment for {req.preferred_skills[0]}",
            focus="Focus on keeping joint angles within target limits",
            target_score=500
        )
    elif level == "intermediate":
        steps = [
            f"Calibrate movement acceleration indices for {req.preferred_skills[0]}",
            "Implement high-tempo posture dynamic coordination",
            "Audit body symmetry ratios under load"
        ]
        daily_lesson = Lesson(
            title=f"Tempo coordination and speed for {req.preferred_skills[0]}",
            focus="Focus on maintaining balance above 90%",
            target_score=1000
        )
    else:  # expert / master
        steps = [
            f"Optimize peak biomechanics forces for {req.preferred_skills[0]}",
            "Attain full automation and sync with professional ghost coordinates",
            "Endurance load simulations"
        ]
        daily_lesson = Lesson(
            title=f"Deity trial: Elite speed precision for {req.preferred_skills[0]}",
            focus="Maintain professional similarity above 95% at high velocity",
            target_score=2000
        )
        
    return RoadmapResponse(
        roadmap_steps=steps,
        lesson_of_the_day=daily_lesson
    )
