"""
ProgressAgent module for MotionMind backend.

Production-ready AI Agent responsible for analyzing historical athlete training sessions,
calculating progress metrics (weekly improvement, average score, mistake frequency, skill progression),
and forecasting future performance (expected score prediction, mastery timeframe, plateau probability).

Architecture:
  - Keep prediction logic (`ProgressPredictiveEngine`) modularly separate from analytics logic (`ProgressAnalyticsEngine`).
  - Uses Pydantic for validation and JSON serialization.
"""

import math
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Union, Optional
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("ProgressAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ---------------------------------------------------------------------------
# Pydantic Schemas for FastAPI Integration
# ---------------------------------------------------------------------------

class SessionRecord(BaseModel):
    """Pydantic model representing a single historical training session."""
    quality_score: float = Field(..., ge=0.0, le=100.0, description="Session quality score")
    timestamp: Optional[str] = Field(default=None, description="ISO 8601 timestamp string")
    mistakes: List[str] = Field(default_factory=list, description="List of detected mistakes in session")
    skill: str = Field(default="general", description="Skill name performed")
    rep_count: int = Field(default=1, ge=1, description="Reps completed")

    model_config = ConfigDict(extra="ignore")


class ProgressInput(BaseModel):
    """Input payload schema for ProgressAgent analysis."""
    user_id: str = Field(..., description="Unique user identifier")
    sessions: List[SessionRecord] = Field(..., description="List of historical session records")
    skill: Optional[str] = Field(default=None, description="Optional target skill to filter by")

    model_config = ConfigDict(extra="ignore")


class ProgressOutput(BaseModel):
    """Exact required JSON response schema for ProgressAgent."""
    weekly_improvement: int = Field(..., description="Percentage or point improvement over past week")
    average_score: int = Field(..., ge=0, le=100, description="Average quality score across sessions")
    prediction: int = Field(..., ge=0, le=100, description="Predicted score for next session")
    mastery_days: int = Field(..., ge=0, description="Estimated days remaining until achieving mastery (>=95 score)")
    
    # Extended analytical fields for comprehensive reporting
    plateau_probability: float = Field(default=0.0, ge=0.0, le=1.0, description="Probability of hitting a training plateau")
    mistake_frequency: Dict[str, int] = Field(default_factory=dict, description="Frequency count of detected form mistakes")
    skill_progression: List[float] = Field(default_factory=list, description="Historical score trajectory")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Analytics Engine (Decoupled Module)
# ---------------------------------------------------------------------------

class ProgressAnalyticsEngine:
    """
    Decoupled Analytics Engine responsible strictly for historical data calculations.
    """

    @staticmethod
    def calculate_average_score(scores: List[float]) -> float:
        """Calculates arithmetic mean of quality scores."""
        if not scores:
            return 70.0
        return sum(scores) / len(scores)

    @staticmethod
    def calculate_weekly_improvement(sessions: List[SessionRecord]) -> float:
        """
        Calculates improvement rate between recent 7-day window vs prior window.
        """
        if not sessions or len(sessions) < 2:
            return 5.0  # Baseline improvement default for new users

        now = datetime.now(timezone.utc)
        recent_scores: List[float] = []
        older_scores: List[float] = []

        for s in sessions:
            dt = None
            if s.timestamp:
                try:
                    dt = datetime.fromisoformat(s.timestamp.replace("Z", "+00:00"))
                except Exception:
                    dt = None

            if dt:
                days_ago = (now - dt).total_seconds() / 86400.0
                if days_ago <= 7.0:
                    recent_scores.append(s.quality_score)
                elif days_ago <= 14.0:
                    older_scores.append(s.quality_score)
            else:
                recent_scores.append(s.quality_score)

        if recent_scores and older_scores:
            avg_recent = sum(recent_scores) / len(recent_scores)
            avg_older = sum(older_scores) / len(older_scores)
            diff = avg_recent - avg_older
            return diff
        elif len(sessions) >= 2:
            # Fallback: Compare second half vs first half of sessions list
            mid = len(sessions) // 2
            first_half_avg = sum(s.quality_score for s in sessions[:mid]) / mid
            second_half_avg = sum(s.quality_score for s in sessions[mid:]) / (len(sessions) - mid)
            return second_half_avg - first_half_avg

        return 5.0

    @staticmethod
    def calculate_mistake_frequency(sessions: List[SessionRecord]) -> Dict[str, int]:
        """Calculates frequency dictionary of detected form mistakes."""
        freq: Dict[str, int] = {}
        for s in sessions:
            for m in s.mistakes:
                clean_m = m.strip()
                if clean_m:
                    freq[clean_m] = freq.get(clean_m, 0) + 1
        return freq


# ---------------------------------------------------------------------------
# Predictive Engine (Decoupled Module)
# ---------------------------------------------------------------------------

class ProgressPredictiveEngine:
    """
    Decoupled Predictive Engine responsible strictly for forecasting future scores,
    mastery timeframes, and plateau probabilities.
    """

    @staticmethod
    def predict_next_score(scores: List[float], weekly_imp: float) -> float:
        """
        Predicts expected score for upcoming session using weighted moving trend.
        """
        if not scores:
            return 75.0

        if len(scores) == 1:
            return min(100.0, scores[0] + 3.0)

        # Exponentially Weighted Moving Average (EWMA)
        alpha = 0.4
        ewma = scores[0]
        for val in scores[1:]:
            ewma = alpha * val + (1 - alpha) * ewma

        # Add positive momentum factor
        momentum = max(-3.0, min(5.0, weekly_imp * 0.2))
        predicted = ewma + momentum
        return float(min(100.0, max(0.0, predicted)))

    @staticmethod
    def estimate_mastery_days(current_avg: float, weekly_imp: float, target_score: float = 95.0) -> int:
        """
        Estimates number of days remaining until athlete reaches mastery score (default 95).
        """
        if current_avg >= target_score:
            return 0

        gap = target_score - current_avg
        # Daily improvement rate (assuming ~3 sessions per week)
        daily_rate = max(0.2, (weekly_imp / 7.0))
        
        estimated_days = math.ceil(gap / daily_rate)
        return int(min(365, max(1, estimated_days)))

    @staticmethod
    def calculate_plateau_probability(scores: List[float]) -> float:
        """
        Calculates probability (0.0 to 1.0) of hitting a learning plateau.
        High plateau probability occurs when recent scores show low variance and zero growth.
        """
        if len(scores) < 3:
            return 0.10

        recent_subset = scores[-5:]
        variance = float(math.pow(float(math.sqrt(sum((x - sum(recent_subset)/len(recent_subset))**2 for x in recent_subset) / len(recent_subset))), 2))
        growth = recent_subset[-1] - recent_subset[0]

        if variance < 4.0 and growth <= 1.0:
            # High plateau risk: stagnant scores with minimal variance
            return 0.75
        elif variance < 8.0 and growth <= 3.0:
            return 0.40
        else:
            return 0.15


# ---------------------------------------------------------------------------
# ProgressAgent Orchestrator
# ---------------------------------------------------------------------------

class ProgressAgent:
    """
    Production-Ready ProgressAgent.
    
    Responsibilities:
      - Analyzes previous workout sessions.
      - Calculates weekly improvement, average score, mistake frequency, and skill progression.
      - Predicts expected next score, mastery days, and plateau probability.
      - Keeps analytics logic completely decoupled from prediction logic.
    """

    def __init__(self):
        self.analytics_engine = ProgressAnalyticsEngine()
        self.predictive_engine = ProgressPredictiveEngine()

    def analyze(
        self,
        sessions: Union[List[SessionRecord], List[Dict[str, Any]]],
        skill_filter: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Main entry point to process historical session data and generate progress report.

        Args:
            sessions: List of SessionRecord objects or session dicts.
            skill_filter: Optional skill name to filter history.

        Returns:
            Dict matching required schema:
            {
              "weekly_improvement": 12,
              "average_score": 84,
              "prediction": 91,
              "mastery_days": 18
            }
        """
        # Parse inputs into SessionRecord models
        parsed_sessions: List[SessionRecord] = []
        for item in sessions:
            if isinstance(item, SessionRecord):
                parsed_sessions.append(item)
            elif isinstance(item, dict):
                parsed_sessions.append(SessionRecord(**item))

        # Filter by skill if requested
        if skill_filter:
            sf = skill_filter.strip().lower()
            filtered = [s for s in parsed_sessions if sf in s.skill.lower()]
            if filtered:
                parsed_sessions = filtered

        if not parsed_sessions:
            logger.warning("No sessions provided to ProgressAgent. Returning baseline defaults.")
            return ProgressOutput(
                weekly_improvement=5,
                average_score=75,
                prediction=78,
                mastery_days=30,
                plateau_probability=0.1,
                mistake_frequency={},
                skill_progression=[]
            ).model_dump()

        scores = [s.quality_score for s in parsed_sessions]

        # 1. Analytics Calculations (Analytics Engine)
        avg_score_raw = self.analytics_engine.calculate_average_score(scores)
        weekly_imp_raw = self.analytics_engine.calculate_weekly_improvement(parsed_sessions)
        mistake_freq = self.analytics_engine.calculate_mistake_frequency(parsed_sessions)

        # 2. Predictive Calculations (Predictive Engine)
        predicted_score_raw = self.predictive_engine.predict_next_score(scores, weekly_imp_raw)
        mastery_days_raw = self.predictive_engine.estimate_mastery_days(avg_score_raw, weekly_imp_raw)
        plateau_prob = self.predictive_engine.calculate_plateau_probability(scores)

        # Round outputs to integer values for clean output schema compliance
        output = ProgressOutput(
            weekly_improvement=int(round(weekly_imp_raw)),
            average_score=int(round(avg_score_raw)),
            prediction=int(round(predicted_score_raw)),
            mastery_days=int(mastery_days_raw),
            plateau_probability=round(plateau_prob, 2),
            mistake_frequency=mistake_freq,
            skill_progression=[round(s, 1) for s in scores]
        )

        return output.model_dump()
