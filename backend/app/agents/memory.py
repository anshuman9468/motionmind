from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict
from app.schemas import SessionRecord

router = APIRouter(prefix="/memory", tags=["Memory"])

# Simple in-memory session store
_sessions_store: Dict[str, List[SessionRecord]] = {}

class MemoryStorageResponse(BaseModel):
    status: str
    total_stored_sessions: int

class HistoryResponse(BaseModel):
    user_id: str
    sessions: List[SessionRecord]
    cumulative_score: int
    most_common_mistakes: List[str]

@router.post("/store", response_model=MemoryStorageResponse)
async def store_session(record: SessionRecord):
    user_id = record.user_id
    if user_id not in _sessions_store:
        _sessions_store[user_id] = []
        
    _sessions_store[user_id].append(record)
    
    return MemoryStorageResponse(
        status="Success: Posture session stored inside local memory ledger.",
        total_stored_sessions=len(_sessions_store[user_id])
    )

@router.get("/history/{user_id}", response_model=HistoryResponse)
async def get_history(user_id: str):
    sessions = _sessions_store.get(user_id, [])
    
    # Calculate aggregate analytics
    cumulative_score = sum(s.final_score for s in sessions)
    
    # Track mistakes frequency
    mistake_counts = {}
    for s in sessions:
        for mistake in s.mistakes_log:
            mistake_counts[mistake] = mistake_counts.get(mistake, 0) + 1
            
    # Sort and extract top mistakes
    sorted_mistakes = sorted(mistake_counts.keys(), key=lambda k: mistake_counts[k], reverse=True)
    
    return HistoryResponse(
        user_id=user_id,
        sessions=sessions,
        cumulative_score=cumulative_score,
        most_common_mistakes=sorted_mistakes[:3]
    )
