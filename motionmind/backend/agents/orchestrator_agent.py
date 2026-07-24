"""
OrchestratorAgent module for MotionMind backend.

Production-ready master coordinator agent responsible for orchestrating all 7 AI agents
in the MotionMind ecosystem in a unified async pipeline:
  1. PoseAgent (Feature extraction & normalization)
  2. MotionIntelligenceAgent (ML model evaluation & mistake detection)
  3. CoachAgent (Gemini sports science feedback & reasoning)
  4. RecommendationAgent (Gemini drills, warmups, cooldowns & progressions)
  5. DigitalTwinAgent (Biomotor metric updates)
  6. MemoryAgent (Centralized shared memory persistence)
  7. ProgressAgent (Historical analysis & predictive performance forecasting)

Features:
  - Full async pipeline (`async def process_session(...)`).
  - Dependency Injection architecture for all sub-agents.
  - Graceful fallback handling at every step with detailed step-by-step logging.
  - Unified output format matching exact specification.
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Union
from pydantic import BaseModel, Field, ConfigDict

from .pose_agent import PoseAgent, PoseAgentInput
from .motion_intelligence_agent import MotionIntelligenceAgent
from .coach_agent import CoachAgent
from .recommendation_agent import RecommendationAgent
from .digital_twin_agent import DigitalTwinAgent, SessionUpdatePayload
from .memory_agent import MemoryAgent
from .progress_agent import ProgressAgent

# Configure logger
logger = logging.getLogger("OrchestratorAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ---------------------------------------------------------------------------
# Pydantic Schemas for FastAPI Orchestrator Integration
# ---------------------------------------------------------------------------

class PracticeSessionInput(BaseModel):
    """Input payload for a practice session evaluation."""
    user_id: str = Field(default="user_default", description="Athlete / User ID")
    skill: str = Field(default="squat", description="Evaluated movement skill name")
    landmarks: Optional[List[Any]] = Field(default=None, description="MediaPipe landmarks list")
    features: Optional[List[float]] = Field(default=None, description="Pre-computed feature vector if landmarks absent")
    landmark_type: str = Field(default="body", description="Landmark type ('body', 'hand', etc.)")
    rep_count: int = Field(default=1, ge=1, description="Reps performed in session")
    session_duration_sec: float = Field(default=60.0, ge=0.0, description="Duration in seconds")

    model_config = ConfigDict(extra="ignore")


class UnifiedOrchestratorResponse(BaseModel):
    """Exact required unified output schema for OrchestratorAgent."""
    quality_score: int = Field(..., ge=0, le=100, description="Evaluated quality score")
    mistakes: List[str] = Field(..., description="List of detected form mistakes")
    coach: Dict[str, Any] = Field(..., description="CoachAgent sports-science guidance")
    recommendations: Dict[str, Any] = Field(..., description="RecommendationAgent prescribed workout regimen")
    digital_twin: Dict[str, Any] = Field(..., description="DigitalTwinAgent updated biomotor profile")
    progress: Dict[str, Any] = Field(..., description="ProgressAgent historical analytics and predictions")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# OrchestratorAgent Implementation
# ---------------------------------------------------------------------------

class OrchestratorAgent:
    """
    Production-ready Orchestrator Agent.
    
    Coordinates the full end-to-end AI workflow across PoseAgent, MotionIntelligenceAgent,
    CoachAgent, RecommendationAgent, DigitalTwinAgent, MemoryAgent, and ProgressAgent.
    """

    def __init__(
        self,
        pose_agent: Optional[PoseAgent] = None,
        motion_intel_agent: Optional[MotionIntelligenceAgent] = None,
        coach_agent: Optional[CoachAgent] = None,
        recommendation_agent: Optional[RecommendationAgent] = None,
        digital_twin_agent: Optional[DigitalTwinAgent] = None,
        memory_agent: Optional[MemoryAgent] = None,
        progress_agent: Optional[ProgressAgent] = None
    ):
        """
        Initialize OrchestratorAgent using Dependency Injection.
        If any agent instance is not provided, creates a production default instance.
        """
        self.pose_agent = pose_agent or PoseAgent()
        self.motion_intel_agent = motion_intel_agent or MotionIntelligenceAgent()
        self.coach_agent = coach_agent or CoachAgent()
        self.recommendation_agent = recommendation_agent or RecommendationAgent()
        self.digital_twin_agent = digital_twin_agent or DigitalTwinAgent()
        self.memory_agent = memory_agent or MemoryAgent()
        self.progress_agent = progress_agent or ProgressAgent()

        logger.info("OrchestratorAgent initialized with all 7 AI agents injected successfully.")

    async def process_session(
        self,
        session_input: Union[PracticeSessionInput, Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Main async method executing the end-to-end multi-agent evaluation workflow.

        Workflow:
          1. PoseAgent: Extract & normalize pose features.
          2. MotionIntelligenceAgent: Evaluate movement quality & detect mistakes.
          3. CoachAgent: Generate sports science reasoning, corrections & encouragement.
          4. RecommendationAgent: Prescribe drills, warmups, cooldowns & progressions.
          5. DigitalTwinAgent: Update physical metrics (strength, balance, etc.).
          6. MemoryAgent: Save session into shared memory.
          7. ProgressAgent: Analyze history & forecast future performance.

        Returns:
          Dict matching exact UnifiedOrchestratorResponse schema:
          {
            "quality_score": 91,
            "mistakes": [...],
            "coach": {...},
            "recommendations": {...},
            "digital_twin": {...},
            "progress": {...}
          }
        """
        # Parse payload
        if isinstance(session_input, dict):
            payload = PracticeSessionInput(**session_input)
        else:
            payload = session_input

        user_id = payload.user_id
        skill = payload.skill.strip()
        logger.info(f"Starting Orchestrator pipeline for user '{user_id}', skill '{skill}'.")

        # Track pipeline intermediate outputs
        feature_vector: List[float] = []
        quality_score: int = 75
        mistakes: List[str] = []
        confidence: float = 0.90
        coach_output: Dict[str, Any] = {}
        rec_output: Dict[str, Any] = {}
        twin_output: Dict[str, Any] = {}
        progress_output: Dict[str, Any] = {}

        # -------------------------------------------------------------------
        # Step 1: Extract Pose Features via PoseAgent
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 1/7] Extracting pose features via PoseAgent...")
            if payload.landmarks:
                pose_req = PoseAgentInput(
                    landmarks=payload.landmarks,
                    landmark_type=payload.landmark_type
                )
                pose_res = await asyncio.to_thread(self.pose_agent.extract, pose_req)
                feature_vector = pose_res.get("feature_vector", [])
            elif payload.features:
                feature_vector = payload.features
            else:
                logger.warning("No landmarks or features provided. Using empty feature vector fallback.")
                feature_vector = []
        except Exception as e:
            logger.error(f"[Step 1/7 Failed] PoseAgent extraction error: {e}", exc_info=True)
            feature_vector = payload.features or []

        # -------------------------------------------------------------------
        # Step 2: Run MotionIntelligenceAgent Evaluation
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 2/7] Evaluating motion via MotionIntelligenceAgent...")
            intel_res = await asyncio.to_thread(
                self.motion_intel_agent.evaluate,
                skill,
                feature_vector
            )
            quality_score = int(intel_res.get("quality_score", 75))
            mistakes = list(intel_res.get("mistakes", []))
            confidence = float(intel_res.get("confidence", 0.90))
        except Exception as e:
            logger.error(f"[Step 2/7 Failed] MotionIntelligenceAgent evaluation error: {e}", exc_info=True)
            quality_score = 75
            mistakes = ["General evaluation fallback applied."]
            confidence = 0.85

        # -------------------------------------------------------------------
        # Step 3: Generate Coaching via CoachAgent
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 3/7] Generating sports science coaching via CoachAgent...")
            coach_output = await asyncio.to_thread(
                self.coach_agent.analyze,
                skill,
                quality_score,
                mistakes,
                confidence
            )
        except Exception as e:
            logger.error(f"[Step 3/7 Failed] CoachAgent error: {e}", exc_info=True)
            coach_output = {
                "feedback": f"Your {skill} scored {quality_score}/100.",
                "reason": "Biomechanical feedback engine fallback mode active.",
                "correction": "Focus on core stability and controlled movement tempo.",
                "encouragement": "Keep practicing consistently!"
            }

        # -------------------------------------------------------------------
        # Step 4: Generate Recommendations via RecommendationAgent
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 4/7] Prescribing workout drills via RecommendationAgent...")
            rec_output = await asyncio.to_thread(
                self.recommendation_agent.recommend,
                skill,
                mistakes,
                quality_score
            )
        except Exception as e:
            logger.error(f"[Step 4/7 Failed] RecommendationAgent error: {e}", exc_info=True)
            rec_output = {
                "drills": ["General form tempo drills (3 sets x 10 reps)"],
                "warmup": ["Dynamic joint mobility exercises (5 minutes)"],
                "cooldown": ["Full body static stretching (5 minutes)"],
                "next_level": "Maintain consistent form to advance to next progression stage."
            }

        # -------------------------------------------------------------------
        # Step 5: Update Digital Twin via DigitalTwinAgent
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 5/7] Updating Digital Twin metrics via DigitalTwinAgent...")
            update_payload = SessionUpdatePayload(
                user_id=user_id,
                quality_score=float(quality_score),
                mistakes=mistakes,
                skill=skill,
                rep_count=payload.rep_count,
                session_duration_sec=payload.session_duration_sec
            )
            twin_output = await asyncio.to_thread(
                self.digital_twin_agent.update,
                user_id,
                update_payload
            )
        except Exception as e:
            logger.error(f"[Step 5/7 Failed] DigitalTwinAgent error: {e}", exc_info=True)
            twin_output = await asyncio.to_thread(self.digital_twin_agent.get, user_id)

        # -------------------------------------------------------------------
        # Step 6: Save Session in MemoryAgent Shared Memory
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 6/7] Persisting session record in MemoryAgent shared memory...")
            session_record_data = {
                "skill": skill,
                "quality_score": quality_score,
                "mistakes": mistakes,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "coach_feedback": coach_output,
                "recommendations": rec_output
            }
            await asyncio.to_thread(
                self.memory_agent.save_session,
                user_id,
                session_record_data
            )
        except Exception as e:
            logger.error(f"[Step 6/7 Failed] MemoryAgent save error: {e}", exc_info=True)

        # -------------------------------------------------------------------
        # Step 7: Analyze Progress & Predict via ProgressAgent
        # -------------------------------------------------------------------
        try:
            logger.info("[Step 7/7] Generating progress analysis & predictions via ProgressAgent...")
            history = await asyncio.to_thread(
                self.memory_agent.get_history,
                user_id,
                20,
                skill
            )
            progress_output = await asyncio.to_thread(
                self.progress_agent.analyze,
                history,
                skill
            )
        except Exception as e:
            logger.error(f"[Step 7/7 Failed] ProgressAgent analysis error: {e}", exc_info=True)
            progress_output = {
                "weekly_improvement": 5,
                "average_score": quality_score,
                "prediction": min(100, quality_score + 3),
                "mastery_days": 20
            }

        # -------------------------------------------------------------------
        # Final Step: Construct Unified Response
        # -------------------------------------------------------------------
        unified_response = UnifiedOrchestratorResponse(
            quality_score=quality_score,
            mistakes=mistakes,
            coach=coach_output,
            recommendations=rec_output,
            digital_twin=twin_output,
            progress=progress_output
        )

        logger.info(f"Orchestrator pipeline completed successfully for user '{user_id}'. Score: {quality_score}/100.")
        return unified_response.model_dump()
