from fastapi.testclient import TestClient

from app.agents.exercise_profiles import get_exercise_profile
from app.main import app


client = TestClient(app)


def _landmarks():
    return [
        {
            "index": index,
            "x": 0.15 + (index % 6) * 0.12,
            "y": 0.10 + (index // 6) * 0.10,
            "z": 0.0,
            "visibility": 0.98,
            "presence": 0.98,
        }
        for index in range(33)
    ]


def _pose(skill_id: str, view: str = "front"):
    return {
        "user_id": "multi-test",
        "session_id": f"session-{skill_id}",
        "skill_id": skill_id,
        "skill_name": skill_id,
        "landmarks": _landmarks(),
        "coordinate_space": "normalized_image",
        "subject_view": view,
        "human_detected": True,
        "tracking_state": "HUMAN_LOCKED",
        "timestamp_us": 100_000,
    }


def test_all_canonical_exercises_resolve_without_a_default_fallback():
    ids = {
        "basketball_shooting",
        "cricket_batting",
        "boxing_jab",
        "squat",
        "push_up",
        "seated_chest_fly",
        "tricep_push_up",
        "bent_over_row",
    }
    assert {get_exercise_profile(identifier).skill_id for identifier in ids} == ids


def test_canonical_boxing_uses_its_own_geometry_rule_profile():
    response = client.post("/agents/biomechanics", json=_pose("boxing_jab"))
    assert response.status_code == 200
    assert response.json()["status"] == "VALID"
    performance = client.post("/agents/performance", json=response.json())
    assert performance.status_code == 200
    data = performance.json()
    assert data["category"] == "sports"
    assert data["scoring_method"] == "heuristic_arm_geometry"
    assert data["feedback_eligible"] is True


def test_generic_temporal_endpoint_rejects_missing_measurements():
    response = client.post(
        "/agents/temporal/analyze",
        json={
            "user_id": "multi-test",
            "session_id": "missing",
            "skill_id": "boxing_jab",
            "timestamp_us": 100_000,
            "subject_view": "front",
            "status": "INSUFFICIENT_DATA",
            "measurement_confidence": 0.0,
        },
    )
    assert response.status_code == 200
    assert response.json()["feedback_eligible"] is False
    assert response.json()["repetition_count"] == 0


def test_session_schema_keeps_exercise_and_uncertainty_metadata():
    response = client.post(
        "/agents/memory/store",
        json={
            "session_id": "multi-session",
            "user_id": "multi-user",
            "duration_seconds": 12,
            "mistakes_log": [],
            "exercise_id": "push_up",
            "category": "GYM",
            "tracking_quality": 0.82,
            "valid_frames": 5,
            "rejected_frames": 2,
            "confidence_reasons": ["one elbow occluded"],
            "verified_findings": [],
            "subject_view": "side",
        },
    )
    assert response.status_code == 200
    history = client.get("/agents/memory/history/multi-user")
    assert history.status_code == 200
    assert history.json()["sessions"][0]["exercise_id"] == "push_up"
