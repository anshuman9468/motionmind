import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "Healthy"
    assert len(response.json()["active_agents"]) == 8

def test_planner():
    payload = {
        "preferred_skills": ["Boxing"],
        "experience_level": "Novice"
    }
    response = client.post("/agents/planner", json=payload)
    assert response.status_code == 200
    assert len(response.json()["roadmap_steps"]) > 0
    assert response.json()["lesson_of_the_day"]["target_score"] == 500

def test_vision():
    payload = {
        "user_id": "usr_test",
        "keypoints": [
            {"x": 0.5, "y": 0.5, "z": 0.0, "visibility": 0.99},
            {"x": 0.6, "y": 0.7, "z": 0.1, "visibility": 0.95}
        ],
        "timestamp": 1234567.89
    }
    response = client.post("/agents/vision", json=payload)
    assert response.status_code == 200
    assert response.json()["detected_joints_count"] == 2
    assert response.json()["tracking_quality_index"] > 0.9

def test_biomechanics():
    payload = {
        "user_id": "usr_test",
        "keypoints": [
            {"x": 0.5, "y": 0.1, "z": 0.0, "visibility": 0.99}, # head
            {"x": 0.45, "y": 0.2, "z": 0.0, "visibility": 0.99}, # shoulder L
            {"x": 0.55, "y": 0.2, "z": 0.0, "visibility": 0.99}, # shoulder R
            {"x": 0.4, "y": 0.3, "z": 0.0, "visibility": 0.99}, # elbow L
            {"x": 0.35, "y": 0.4, "z": 0.0, "visibility": 0.99}, # wrist L
            {"x": 0.6, "y": 0.3, "z": 0.0, "visibility": 0.99}, # elbow R
            {"x": 0.65, "y": 0.4, "z": 0.0, "visibility": 0.99}, # wrist R
            {"x": 0.47, "y": 0.5, "z": 0.0, "visibility": 0.99}, # hip L
            {"x": 0.53, "y": 0.5, "z": 0.0, "visibility": 0.99}  # hip R
        ],
        "timestamp": 1234567.89
    }
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert "elbow_angle" in response.json()
    assert "balance_index" in response.json()

def test_performance():
    payload = {
        "elbow_angle": 120.0,
        "back_angle": 165.0,
        "balance_index": 0.85,
        "center_of_gravity": [0.5, 0.5],
        "velocity": 1.4,
        "acceleration": 0.8,
        "efficiency": 0.88
    }
    response = client.post("/agents/performance", json=payload)
    assert response.status_code == 200
    assert response.json()["is_correct"] is False
    assert len(response.json()["detected_mistakes"]) > 0


def test_on_device_tflite_score_reaches_performance_agent():
    payload = {
        "elbow_angle": 180.0,
        "back_angle": 180.0,
        "balance_index": 1.0,
        "center_of_gravity": [0.5, 0.5],
        "velocity": 1.4,
        "acceleration": 0.8,
        "efficiency": 0.88,
        "on_device_quality_score": 40.0,
    }
    response = client.post("/agents/performance", json=payload)
    assert response.status_code == 200
    # Rule-only quality would produce 1250 XP. The TFLite scalar is blended
    # into the backend score before the agent returns XP.
    assert response.json()["score"] == 1025

def test_coach():
    payload = {
        "detected_mistakes": ["Dominant elbow is flexed too low."],
        "practice_score": 1200
    }
    response = client.post("/agents/coach", json=payload)
    assert response.status_code == 200
    assert "feedback_text" in response.json()
    assert len(response.json()["audio_cues"]) > 0

def test_recommendation():
    payload = {
        "detected_weaknesses": ["Elbow posture issue"],
        "experience_level": "Intermediate"
    }
    response = client.post("/agents/recommendation", json=payload)
    assert response.status_code == 200
    assert len(response.json()["target_drills"]) > 0

def test_twin():
    # Update profile test
    payload = {
        "user_id": "usr_test",
        "recent_mistakes": ["Shoulders out of alignment"],
        "session_scores": [1200, 1400, 1500]
    }
    response = client.post("/agents/twin/update", json=payload)
    assert response.status_code == 200
    assert response.json()["user_id"] == "usr_test"
    
    # Get profile test
    response = client.get("/agents/twin/usr_test")
    assert response.status_code == 200
    assert response.json()["predicted_days_to_mastery"] > 0

def test_memory():
    # Store session
    payload = {
        "session_id": "sess_01",
        "user_id": "usr_test",
        "duration_seconds": 120,
        "calories": 25.5,
        "final_score": 1400,
        "mistakes_log": ["Shoulders out of alignment"]
    }
    response = client.post("/agents/memory/store", json=payload)
    assert response.status_code == 200
    assert response.json()["total_stored_sessions"] == 1
    
    # Get history
    response = client.get("/agents/memory/history/usr_test")
    assert response.status_code == 200
    assert response.json()["cumulative_score"] == 1400
