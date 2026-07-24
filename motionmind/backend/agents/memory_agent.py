"""
MemoryAgent module for MotionMind backend.

Production-ready Centralized Memory Agent responsible for maintaining shared context,
user profiles, training goals, evaluation session history, detected mistakes, quality scores,
digital twin state, and recommendation logs for all AI agents in MotionMind.

Architecture:
  - Backend agnostic via abstract storage interface (`BaseMemoryStorageAdapter`).
  - Pluggable support for Vector databases (Chroma, Pinecone, Qdrant, pgvector) via `VectorStoreInterface`.
  - Serves unified context to downstream agents (`CoachAgent`, `RecommendationAgent`, `ProgressAgent`).
"""

import math
import logging
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Union
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("MemoryAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ---------------------------------------------------------------------------
# Pydantic Schemas for Shared Memory System
# ---------------------------------------------------------------------------

class UserProfile(BaseModel):
    """User profile and training goals."""
    user_id: str = Field(..., description="Unique user identifier")
    name: str = Field(default="Athlete", description="Athlete display name")
    goals: List[str] = Field(default_factory=lambda: ["Improve form", "Increase depth", "Consistency"], description="Target training goals")
    experience_level: str = Field(default="Intermediate", description="Skill/Experience level")

    model_config = ConfigDict(extra="ignore")


class SessionMemoryRecord(BaseModel):
    """Structured session record held in shared memory."""
    session_id: str = Field(..., description="Unique session identifier")
    user_id: str = Field(..., description="User ID associated with session")
    skill: str = Field(default="general", description="Evaluated skill name")
    quality_score: float = Field(..., ge=0.0, le=100.0, description="Movement quality score")
    mistakes: List[str] = Field(default_factory=list, description="Detected form mistakes")
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    recommendations: Optional[Dict[str, Any]] = Field(default=None, description="Generated workout recommendations")
    coach_feedback: Optional[Dict[str, Any]] = Field(default=None, description="Generated coach feedback")

    model_config = ConfigDict(extra="ignore")


class UserContextResponse(BaseModel):
    """Aggregated full context returned by get_user_context()."""
    user_id: str = Field(..., description="User identifier")
    profile: UserProfile = Field(..., description="User profile and goals")
    digital_twin: Dict[str, Any] = Field(..., description="Digital twin physical metrics")
    latest_session: Optional[SessionMemoryRecord] = Field(default=None, description="Most recent session record")
    average_quality_score: float = Field(default=75.0, description="Overall average quality score")
    common_mistakes: List[str] = Field(default_factory=list, description="Most frequent historical mistakes")
    total_sessions_count: int = Field(default=0, description="Total completed sessions count")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Backend Agnostic Abstract Storage Interfaces (Relational/Document + Vector)
# ---------------------------------------------------------------------------

class BaseMemoryStorageAdapter(ABC):
    """
    Abstract Storage Interface for MemoryAgent.
    Makes MemoryAgent completely backend agnostic (In-Memory, SQL, Mongo, Firebase, Supabase).
    """

    @abstractmethod
    def save_profile(self, profile: UserProfile) -> bool:
        pass

    @abstractmethod
    def get_profile(self, user_id: str) -> Optional[UserProfile]:
        pass

    @abstractmethod
    def save_session(self, record: SessionMemoryRecord) -> bool:
        pass

    @abstractmethod
    def get_history(self, user_id: str, limit: int = 10, skill: Optional[str] = None) -> List[SessionMemoryRecord]:
        pass

    @abstractmethod
    def get_latest(self, user_id: str, skill: Optional[str] = None) -> Optional[SessionMemoryRecord]:
        pass

    @abstractmethod
    def save_digital_twin(self, user_id: str, twin_data: Dict[str, Any]) -> bool:
        pass

    @abstractmethod
    def get_digital_twin(self, user_id: str) -> Optional[Dict[str, Any]]:
        pass


class VectorStoreInterface(ABC):
    """
    Abstract Interface for Vector Databases (Pinecone, ChromaDB, Qdrant, pgvector).
    Allows semantic memory retrieval over unstructured motion feedback and logs.
    """

    @abstractmethod
    def store_vector(self, user_id: str, text: str, vector: List[float], metadata: Dict[str, Any]) -> bool:
        """Stores text embedding vector into vector database."""
        pass

    @abstractmethod
    def query_similar(self, user_id: str, query_vector: List[float], top_k: int = 3) -> List[Dict[str, Any]]:
        """Queries top-k similar historical memory records using vector similarity."""
        pass


class InMemoryMemoryStorageAdapter(BaseMemoryStorageAdapter, VectorStoreInterface):
    """Default high-speed in-memory implementation supporting basic vector search stubs."""

    def __init__(self):
        self._profiles: Dict[str, UserProfile] = {}
        self._sessions: Dict[str, List[SessionMemoryRecord]] = {}
        self._digital_twins: Dict[str, Dict[str, Any]] = {}
        self._vectors: Dict[str, List[Dict[str, Any]]] = {}

    def save_profile(self, profile: UserProfile) -> bool:
        self._profiles[profile.user_id] = profile
        return True

    def get_profile(self, user_id: str) -> Optional[UserProfile]:
        return self._profiles.get(user_id)

    def save_session(self, record: SessionMemoryRecord) -> bool:
        if record.user_id not in self._sessions:
            self._sessions[record.user_id] = []
        self._sessions[record.user_id].append(record)
        return True

    def get_history(self, user_id: str, limit: int = 10, skill: Optional[str] = None) -> List[SessionMemoryRecord]:
        history = self._sessions.get(user_id, [])
        if skill:
            s_norm = skill.strip().lower()
            history = [s for s in history if s_norm in s.skill.lower()]
        # Sort descending by timestamp
        history_sorted = sorted(history, key=lambda x: x.timestamp, reverse=True)
        return history_sorted[:limit]

    def get_latest(self, user_id: str, skill: Optional[str] = None) -> Optional[SessionMemoryRecord]:
        history = self.get_history(user_id=user_id, limit=1, skill=skill)
        return history[0] if history else None

    def save_digital_twin(self, user_id: str, twin_data: Dict[str, Any]) -> bool:
        self._digital_twins[user_id] = twin_data
        return True

    def get_digital_twin(self, user_id: str) -> Optional[Dict[str, Any]]:
        return self._digital_twins.get(user_id)

    # Vector store implementation
    def store_vector(self, user_id: str, text: str, vector: List[float], metadata: Dict[str, Any]) -> bool:
        if user_id not in self._vectors:
            self._vectors[user_id] = []
        self._vectors[user_id].append({
            "text": text,
            "vector": vector,
            "metadata": metadata
        })
        return True

    def query_similar(self, user_id: str, query_vector: List[float], top_k: int = 3) -> List[Dict[str, Any]]:
        records = self._vectors.get(user_id, [])
        if not records or not query_vector:
            return []

        def cosine_sim(v1: List[float], v2: List[float]) -> float:
            dot = sum(a * b for a, b in zip(v1, v2))
            norm1 = math.sqrt(sum(a * a for a in v1))
            norm2 = math.sqrt(sum(b * b for b in v2))
            if norm1 < 1e-6 or norm2 < 1e-6:
                return 0.0
            return dot / (norm1 * norm2)

        scored = [(cosine_sim(query_vector, r["vector"]), r) for r in records if "vector" in r]
        scored.sort(key=lambda x: x[0], reverse=True)
        return [item[1] for item in scored[:top_k]]


# ---------------------------------------------------------------------------
# MemoryAgent Implementation
# ---------------------------------------------------------------------------

class MemoryAgent:
    """
    Centralized Memory Agent for MotionMind.
    
    Responsibilities:
      - Maintain shared memory across all AI agents.
      - Save evaluation sessions, quality scores, mistakes, recommendations, and digital twins.
      - Core methods: save_session(), get_history(), get_latest(), get_user_context().
      - Backend agnostic via abstract storage interface.
      - Vector database ready.
    """

    def __init__(self, storage_adapter: Optional[BaseMemoryStorageAdapter] = None):
        """
        Initialize MemoryAgent with storage adapter.

        Args:
            storage_adapter: Storage backend instance. Defaults to InMemoryMemoryStorageAdapter.
        """
        self.storage = storage_adapter or InMemoryMemoryStorageAdapter()

    def save_session(
        self,
        user_id: str,
        session_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Saves a workout evaluation session into shared memory.

        Args:
            user_id: User identifier.
            session_data: Session dict containing quality_score, mistakes, skill, etc.

        Returns:
            Dict of saved SessionMemoryRecord.
        """
        session_id = session_data.get("session_id") or f"sess_{int(datetime.now(timezone.utc).timestamp() * 1000)}"
        
        record = SessionMemoryRecord(
            session_id=session_id,
            user_id=user_id,
            skill=session_data.get("skill", "general"),
            quality_score=float(session_data.get("quality_score", 75.0)),
            mistakes=list(session_data.get("mistakes", [])),
            timestamp=session_data.get("timestamp") or datetime.now(timezone.utc).isoformat(),
            recommendations=session_data.get("recommendations"),
            coach_feedback=session_data.get("coach_feedback")
        )

        self.storage.save_session(record)
        logger.info(f"MemoryAgent saved session '{session_id}' for user '{user_id}'.")
        return record.model_dump()

    def get_history(
        self,
        user_id: str,
        limit: int = 10,
        skill: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieves historical session records for a user.

        Args:
            user_id: User identifier.
            limit: Maximum records to return.
            skill: Optional skill filter.

        Returns:
            List[Dict[str, Any]]: History records sorted newest to oldest.
        """
        records = self.storage.get_history(user_id=user_id, limit=limit, skill=skill)
        return [r.model_dump() for r in records]

    def get_latest(
        self,
        user_id: str,
        skill: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Retrieves the single most recent session record for a user.

        Args:
            user_id: User identifier.
            skill: Optional skill filter.

        Returns:
            Optional[Dict[str, Any]]: Latest session record or None if empty.
        """
        record = self.storage.get_latest(user_id=user_id, skill=skill)
        return record.model_dump() if record else None

    def get_user_context(self, user_id: str) -> Dict[str, Any]:
        """
        Aggregates complete user memory context (profile, goals, digital twin metrics,
        latest session, average quality score, common mistakes) for other agents to consume.

        Args:
            user_id: User identifier.

        Returns:
            Dict matching UserContextResponse schema.
        """
        # 1. Profile & Goals
        profile = self.storage.get_profile(user_id)
        if not profile:
            profile = UserProfile(user_id=user_id, name=f"Athlete_{user_id[:4]}")
            self.storage.save_profile(profile)

        # 2. Digital Twin Metrics
        twin = self.storage.get_digital_twin(user_id)
        if not twin:
            twin = {
                "strength": 50.0, "balance": 50.0, "coordination": 50.0,
                "mobility": 50.0, "reaction": 50.0, "consistency": 50.0,
                "confidence": 50.0, "fatigue": 0.0
            }
            self.storage.save_digital_twin(user_id, twin)

        # 3. History analytics
        history = self.storage.get_history(user_id=user_id, limit=50)
        latest_record = history[0] if history else None

        avg_score = 75.0
        common_mistakes: List[str] = []

        if history:
            scores = [h.quality_score for h in history]
            avg_score = round(sum(scores) / len(scores), 1)

            # Frequency count of mistakes
            freq: Dict[str, int] = {}
            for h in history:
                for m in h.mistakes:
                    freq[m] = freq.get(m, 0) + 1
            sorted_m = sorted(freq.items(), key=lambda x: x[1], reverse=True)
            common_mistakes = [item[0] for item in sorted_m[:3]]

        context = UserContextResponse(
            user_id=user_id,
            profile=profile,
            digital_twin=twin,
            latest_session=latest_record,
            average_quality_score=avg_score,
            common_mistakes=common_mistakes,
            total_sessions_count=len(history)
        )

        return context.model_dump()
