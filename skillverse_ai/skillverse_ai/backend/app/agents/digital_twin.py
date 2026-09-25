from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from app.schemas import TwinProfile

router = APIRouter(prefix="/twin", tags=["Digital Twin"])

# Simple in-memory profile store for simulation
_profiles = {}

class UpdateProfileRequest(BaseModel):
    user_id: str
    recent_mistakes: List[str]
    session_scores: List[int]

@router.get("/{user_id}", response_model=TwinProfile)
async def get_twin_profile(user_id: str):
    if user_id not in _profiles:
        # Create default initial profile
        _profiles[user_id] = TwinProfile(
            user_id=user_id,
            learning_speed=1.0,
            weaknesses=["Elbow Alignment"],
            predicted_days_to_mastery=45
        )
    return _profiles[user_id]

@router.post("/update", response_model=TwinProfile)
async def update_twin_profile(req: UpdateProfileRequest):
    user_id = req.user_id
    
    # Calculate weakness frequency
    unique_weaknesses = list(set(req.recent_mistakes))
    
    # Update learning speed based on session scores
    avg_score = sum(req.session_scores) / len(req.session_scores) if req.session_scores else 1000
    learning_speed = 1.0
    if avg_score > 1500:
        learning_speed = 1.3 # fast learning rate
    elif avg_score < 700:
        learning_speed = 0.8 # slower learning rate, requires more reps
        
    # Predict days to mastery (faster learning speed reduces required days)
    base_days = 60
    predicted_days = int(base_days / learning_speed)
    
    updated_profile = TwinProfile(
        user_id=user_id,
        learning_speed=round(learning_speed, 2),
        weaknesses=unique_weaknesses if unique_weaknesses else ["None"],
        predicted_days_to_mastery=predicted_days
    )
    
    _profiles[user_id] = updated_profile
    return updated_profile
