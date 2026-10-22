from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import shutil
import os
from typing import List, Optional

from ml.inference import MultiSkillEvaluator
from agents.pose_agent import PoseAgent, PoseAgentInput, PoseAgentOutput
from agents.coach_agent import CoachAgent, CoachAgentInput, CoachFeedbackResponse
from agents.recommendation_agent import RecommendationAgent, RecommendationInput, RecommendationOutput
from agents.digital_twin_agent import DigitalTwinAgent, DigitalTwinProfile, SessionUpdatePayload
from agents.progress_agent import ProgressAgent, ProgressInput, ProgressOutput
from agents.memory_agent import MemoryAgent, SessionMemoryRecord, UserContextResponse
from agents.orchestrator_agent import OrchestratorAgent, PracticeSessionInput, UnifiedOrchestratorResponse

app = FastAPI(title="MotionMind API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

evaluator = None
pose_agent = PoseAgent()
coach_agent = CoachAgent()
recommendation_agent = RecommendationAgent()
digital_twin_agent = DigitalTwinAgent()
progress_agent = ProgressAgent()
memory_agent = MemoryAgent()

orchestrator_agent = OrchestratorAgent(
    pose_agent=pose_agent,
    coach_agent=coach_agent,
    recommendation_agent=recommendation_agent,
    digital_twin_agent=digital_twin_agent,
    memory_agent=memory_agent,
    progress_agent=progress_agent
)

@app.on_event("startup")
def load_models():
    global evaluator
    try:
        evaluator = MultiSkillEvaluator()
        print("ML Models loaded successfully.")
    except Exception as e:
        print(f"Warning: ML Models not loaded. {e}")

@app.get("/")
def read_root():
    return {"message": "Welcome to MotionMind API"}

@app.post("/session/process", response_model=UnifiedOrchestratorResponse)
async def process_practice_session(payload: PracticeSessionInput):
    """
    Master Orchestration endpoint coordinating all 7 AI agents in an end-to-end workflow:
    Extract Pose -> ML Evaluate -> Coach -> Recommend -> Update Twin -> Save Memory -> Forecast Progress.
    """
    try:
        result = await orchestrator_agent.process_session(payload)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/pose/extract", response_model=PoseAgentOutput)
async def extract_pose_features(payload: PoseAgentInput):
    """
    FastAPI endpoint for PoseAgent to process MediaPipe keypoints,
    normalize coordinates, remove noise, and return spatial feature vectors.
    """
    try:
        result = pose_agent.extract(payload)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/coach/feedback", response_model=CoachFeedbackResponse)
async def generate_coach_feedback(payload: CoachAgentInput):
    """
    FastAPI endpoint for CoachAgent utilizing Gemini to generate sports-science biomechanical feedback,
    mistake explanations, corrective drills, and encouragement.
    """
    try:
        result = coach_agent.analyze(
            skill=payload.skill,
            quality_score=payload.quality_score,
            mistakes=payload.mistakes,
            confidence=payload.confidence
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/recommendation/generate", response_model=RecommendationOutput)
async def generate_recommendations(payload: RecommendationInput):
    """
    FastAPI endpoint for RecommendationAgent utilizing Gemini to prescribe drills,
    dynamic warmups, static cooldowns, and difficulty progressions.
    """
    try:
        result = recommendation_agent.recommend(
            skill=payload.skill,
            detected_mistakes=payload.detected_mistakes,
            quality_score=payload.quality_score
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/digital-twin/{user_id}", response_model=DigitalTwinProfile)
async def get_digital_twin(user_id: str):
    """
    FastAPI endpoint to retrieve an athlete's digital twin profile.
    """
    try:
        return digital_twin_agent.get(user_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/digital-twin/update", response_model=DigitalTwinProfile)
async def update_digital_twin(payload: SessionUpdatePayload):
    """
    FastAPI endpoint to update an athlete's digital twin metrics after a session.
    """
    try:
        return digital_twin_agent.update(payload.user_id, payload)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/progress/analyze", response_model=ProgressOutput)
async def analyze_progress(payload: ProgressInput):
    """
    FastAPI endpoint for ProgressAgent to analyze historical sessions, calculate weekly improvement,
    predict next scores, estimate mastery timeframe, and evaluate plateau risks.
    """
    try:
        return progress_agent.analyze(sessions=payload.sessions, skill_filter=payload.skill)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/memory/session/save")
async def save_session_memory(user_id: str, session_data: dict):
    """
    FastAPI endpoint for MemoryAgent to save evaluation session into shared memory.
    """
    try:
        return memory_agent.save_session(user_id, session_data)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/memory/history/{user_id}")
async def get_memory_history(user_id: str, limit: int = 10, skill: Optional[str] = None):
    """
    FastAPI endpoint for MemoryAgent to retrieve user session history.
    """
    try:
        return memory_agent.get_history(user_id, limit=limit, skill=skill)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/memory/latest/{user_id}")
async def get_memory_latest(user_id: str, skill: Optional[str] = None):
    """
    FastAPI endpoint for MemoryAgent to retrieve latest user session.
    """
    try:
        return memory_agent.get_latest(user_id, skill=skill)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/memory/context/{user_id}", response_model=UserContextResponse)
async def get_memory_user_context(user_id: str):
    """
    FastAPI endpoint for MemoryAgent to retrieve unified user context for all agents.
    """
    try:
        return memory_agent.get_user_context(user_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/evaluate")
async def evaluate_video(file: UploadFile = File(...), skill: str = Form("squat")):
    global evaluator
    if not evaluator:
        raise HTTPException(status_code=500, detail="ML Models not loaded on server.")

    temp_video_path = f"temp_{file.filename}"
    with open(temp_video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        results = evaluator.evaluate(temp_video_path, skill=skill)

        if os.path.exists(temp_video_path):
            os.remove(temp_video_path)

        if "error" in results:
            raise HTTPException(status_code=400, detail=results["error"])

        return results

    except Exception as e:
        if os.path.exists(temp_video_path):
            os.remove(temp_video_path)
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
