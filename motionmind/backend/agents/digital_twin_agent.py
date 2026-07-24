"""
DigitalTwinAgent module for MotionMind backend.

Production-ready AI Agent responsible for maintaining, updating, and retrieving a digital
twin profile for every athlete. Tracks 8 core physical/biomotor metrics:
  - strength
  - balance
  - coordination
  - mobility
  - reaction
  - consistency
  - confidence
  - fatigue

Architecture:
  - Uses Pydantic for validation and JSON serialization.
  - Abstract storage interface (`BaseStorageAdapter`) completely decoupled from business logic,
    allowing Firebase, Supabase, PostgreSQL, or Redis adapters to be easily plugged in.
"""

import os
import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Union
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("DigitalTwinAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ---------------------------------------------------------------------------
# Pydantic Schemas for Digital Twin Profile & Session Updates
# ---------------------------------------------------------------------------

class DigitalTwinMetrics(BaseModel):
    """Core biomotor and psychological metrics for an athlete's digital twin."""
    strength: float = Field(default=50.0, ge=0.0, le=100.0, description="Muscular strength rating (0-100)")
    balance: float = Field(default=50.0, ge=0.0, le=100.0, description="Postural & stability rating (0-100)")
    coordination: float = Field(default=50.0, ge=0.0, le=100.0, description="Motor control & kinetic chain sync (0-100)")
    mobility: float = Field(default=50.0, ge=0.0, le=100.0, description="Joint range of motion & flexibility (0-100)")
    reaction: float = Field(default=50.0, ge=0.0, le=100.0, description="Reaction time & movement speed (0-100)")
    consistency: float = Field(default=50.0, ge=0.0, le=100.0, description="Movement pattern repeatability (0-100)")
    confidence: float = Field(default=50.0, ge=0.0, le=100.0, description="Form execution confidence (0-100)")
    fatigue: float = Field(default=0.0, ge=0.0, le=100.0, description="Accumulated neuromuscular fatigue (0-100)")

    model_config = ConfigDict(extra="ignore")


class DigitalTwinProfile(BaseModel):
    """Complete Digital Twin user profile document."""
    user_id: str = Field(..., description="Unique user identifier")
    username: str = Field(default="Athlete", description="Athlete display name")
    metrics: DigitalTwinMetrics = Field(default_factory=DigitalTwinMetrics)
    total_sessions: int = Field(default=0, ge=0, description="Total completed evaluation sessions")
    last_updated: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    model_config = ConfigDict(extra="ignore")


class SessionUpdatePayload(BaseModel):
    """Input payload representing a completed workout evaluation session."""
    user_id: str = Field(..., description="User ID for whom to update digital twin")
    quality_score: float = Field(..., ge=0.0, le=100.0, description="Session quality score (0-100)")
    mistakes: List[str] = Field(default_factory=list, description="List of detected form mistakes")
    skill: str = Field(default="general", description="Evaluated skill name")
    rep_count: int = Field(default=1, ge=1, description="Number of repetitions performed")
    session_duration_sec: float = Field(default=60.0, ge=0.0, description="Session duration in seconds")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Abstract Storage Interface (Decoupled Architecture)
# ---------------------------------------------------------------------------

class BaseStorageAdapter(ABC):
    """
    Abstract Storage Adapter Interface.
    Decouples storage engines (Firebase, Supabase, Postgres, In-Memory) from business logic.
    """

    @abstractmethod
    def save_twin(self, user_id: str, profile_dict: Dict[str, Any]) -> bool:
        """Saves or updates digital twin profile data."""
        pass

    @abstractmethod
    def get_twin(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves digital twin profile data for a given user_id."""
        pass


class InMemoryStorageAdapter(BaseStorageAdapter):
    """Default high-speed in-memory storage adapter for local execution & testing."""

    def __init__(self):
        self._store: Dict[str, Dict[str, Any]] = {}

    def save_twin(self, user_id: str, profile_dict: Dict[str, Any]) -> bool:
        self._store[user_id] = profile_dict
        return True

    def get_twin(self, user_id: str) -> Optional[Dict[str, Any]]:
        return self._store.get(user_id)


class JSONFileStorageAdapter(BaseStorageAdapter):
    """File-backed storage adapter persisting profiles to a local JSON file."""

    def __init__(self, file_path: str = "data/digital_twins.json"):
        self.file_path = file_path
        os.makedirs(os.path.dirname(self.file_path) or ".", exist_ok=True)
        if not os.path.exists(self.file_path):
            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump({}, f)

    def _read_all(self) -> Dict[str, Dict[str, Any]]:
        try:
            with open(self.file_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def _write_all(self, data: Dict[str, Dict[str, Any]]) -> bool:
        try:
            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Failed to write storage file {self.file_path}: {e}")
            return False

    def save_twin(self, user_id: str, profile_dict: Dict[str, Any]) -> bool:
        data = self._read_all()
        data[user_id] = profile_dict
        return self._write_all(data)

    def get_twin(self, user_id: str) -> Optional[Dict[str, Any]]:
        data = self._read_all()
        return data.get(user_id)


# ---------------------------------------------------------------------------
# DigitalTwinAgent Implementation
# ---------------------------------------------------------------------------

class DigitalTwinAgent:
    """
    Production-Ready DigitalTwinAgent.
    
    Responsibilities:
      - Maintain an evolving digital twin profile for every user.
      - Update metrics (strength, balance, coordination, mobility, reaction, consistency, confidence, fatigue) after every session.
      - Abstract storage adapter interface for pluggable backends (Firebase, Supabase, In-Memory).
      - Core methods: create_twin(), update(), get(), save().
    """

    def __init__(self, storage_adapter: Optional[BaseStorageAdapter] = None):
        """
        Initialize DigitalTwinAgent with an abstract storage adapter.

        Args:
            storage_adapter: Concrete implementation of BaseStorageAdapter. Defaults to InMemoryStorageAdapter.
        """
        self.storage = storage_adapter or InMemoryStorageAdapter()

    def create_twin(
        self,
        user_id: str,
        username: str = "Athlete",
        initial_metrics: Optional[Dict[str, float]] = None
    ) -> Dict[str, Any]:
        """
        Creates a new digital twin profile for a user.

        Args:
            user_id: Unique user identifier.
            username: Display name.
            initial_metrics: Optional dict overriding default baseline metrics.

        Returns:
            Dict representation of created DigitalTwinProfile.
        """
        metrics = DigitalTwinMetrics()
        if initial_metrics:
            metrics_dict = metrics.model_dump()
            metrics_dict.update({k: float(v) for k, v in initial_metrics.items() if k in metrics_dict})
            metrics = DigitalTwinMetrics(**metrics_dict)

        profile = DigitalTwinProfile(
            user_id=user_id,
            username=username,
            metrics=metrics,
            total_sessions=0,
            last_updated=datetime.now(timezone.utc).isoformat()
        )

        profile_dict = profile.model_dump()
        self.storage.save_twin(user_id, profile_dict)
        logger.info(f"Created new Digital Twin profile for user_id: {user_id}")
        return profile_dict

    def get(self, user_id: str) -> Dict[str, Any]:
        """
        Retrieves the digital twin profile for a user.
        If profile does not exist, automatically creates a baseline twin profile.

        Args:
            user_id: Unique user identifier.

        Returns:
            Dict representation of DigitalTwinProfile.
        """
        raw = self.storage.get_twin(user_id)
        if not raw:
            logger.info(f"No existing twin profile found for {user_id}. Auto-creating baseline profile.")
            return self.create_twin(user_id)

        profile = DigitalTwinProfile(**raw)
        return profile.model_dump()

    def update(
        self,
        user_id: str,
        session_data: Union[SessionUpdatePayload, Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Updates an athlete's digital twin metrics after a session evaluation.

        Args:
            user_id: User identifier.
            session_data: Session payload containing quality_score, mistakes, rep_count, etc.

        Returns:
            Updated Dict representation of DigitalTwinProfile.
        """
        # Retrieve current profile or create baseline
        current_data = self.get(user_id)
        profile = DigitalTwinProfile(**current_data)

        # Parse session input
        if isinstance(session_data, dict):
            session_data["user_id"] = user_id
            payload = SessionUpdatePayload(**session_data)
        else:
            payload = session_data

        m = profile.metrics
        qs = payload.quality_score
        num_mistakes = len(payload.mistakes)
        mistakes_text = " ".join(payload.mistakes).lower()

        # Biomechanical Metric Adaptive Update (EMA with alpha = 0.20)
        alpha = 0.20

        # 1. Consistency: Driven by session quality score
        m.consistency = round(float((1 - alpha) * m.consistency + alpha * qs), 2)

        # 2. Confidence: Increases with high quality scores, decreases with mistakes
        target_conf = max(0.0, qs - (num_mistakes * 5.0))
        m.confidence = round(float((1 - alpha) * m.confidence + alpha * target_conf), 2)

        # 3. Balance: Affected by posture/wobble/ankle/depth mistakes
        balance_target = qs
        if any(w in mistakes_text for w in ["wobble", "balance", "knee", "shallow", "depth"]):
            balance_target = max(0.0, qs - 15.0)
        m.balance = round(float((1 - alpha) * m.balance + alpha * balance_target), 2)

        # 4. Mobility: Affected by depth or back tilt issues
        mobility_target = qs
        if any(w in mistakes_text for w in ["depth", "shallow", "back", "rounded", "flare"]):
            mobility_target = max(0.0, qs - 12.0)
        m.mobility = round(float((1 - alpha) * m.mobility + alpha * mobility_target), 2)

        # 5. Coordination & Reaction: Dynamic responsiveness
        m.coordination = round(float((1 - alpha) * m.coordination + alpha * (qs * 0.9 + 10.0)), 2)
        m.reaction = round(float((1 - alpha) * m.reaction + alpha * (qs * 0.85 + 15.0)), 2)

        # 6. Strength: Progressive overload factor based on quality and rep volume
        strength_gain = (qs / 100.0) * min(payload.rep_count * 0.5, 5.0)
        m.strength = round(float(min(100.0, m.strength + strength_gain)), 2)

        # 7. Fatigue: Increases with reps and session duration, recovers over time
        added_fatigue = min(30.0, (payload.rep_count * 1.5) + (payload.session_duration_sec / 60.0 * 2.0))
        m.fatigue = round(float(min(100.0, max(0.0, (m.fatigue * 0.5) + added_fatigue))), 2)

        # Increment session count and update timestamp
        profile.total_sessions += 1
        profile.last_updated = datetime.now(timezone.utc).isoformat()

        # Save to abstract storage
        self.save(user_id, profile)

        logger.info(f"Updated Digital Twin for user {user_id}. Total sessions: {profile.total_sessions}")
        return profile.model_dump()

    def save(self, user_id: str, profile: Optional[DigitalTwinProfile] = None) -> bool:
        """
        Persists a digital twin profile document via abstract storage interface.

        Args:
            user_id: Unique user identifier.
            profile: Optional DigitalTwinProfile object to save.

        Returns:
            bool: Success indicator.
        """
        if profile is None:
            current = self.get(user_id)
            profile = DigitalTwinProfile(**current)

        profile_dict = profile.model_dump()
        return self.storage.save_twin(user_id, profile_dict)
