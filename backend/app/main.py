from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.agents import (
    skill_planner,
    vision,
    biomechanics,
    performance,
    coach,
    recommendation,
    digital_twin,
    memory
)

app = FastAPI(
    title="SkillVerse Agentic AI Posture API",
    description="Multi-Agent physical stance correction API executing Skill Planner, Vision, Biomechanics, Performance, Coach, Recommendation, Digital Twin, and Memory ledgers.",
    version="1.0.0"
)

# Enable CORS for local development requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount cooperative agent routers
app.include_router(skill_planner.router, prefix="/agents")
app.include_router(vision.router, prefix="/agents")
app.include_router(biomechanics.router, prefix="/agents")
app.include_router(performance.router, prefix="/agents")
app.include_router(coach.router, prefix="/agents")
app.include_router(recommendation.router, prefix="/agents")
app.include_router(digital_twin.router, prefix="/agents")
app.include_router(memory.router, prefix="/agents")

@app.get("/")
def read_root():
    return {
        "status": "Healthy",
        "system": "SkillVerse Agentic API Cluster",
        "active_agents": [
            "Skill Planner Agent",
            "Vision Agent",
            "Biomechanics Agent",
            "Performance Agent",
            "Coach Agent",
            "Recommendation Agent",
            "Digital Twin Agent",
            "Memory Agent"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
