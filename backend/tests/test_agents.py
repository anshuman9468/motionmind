import math

from fastapi.testclient import TestClient

from app.agents.biomechanics import calculate_angle
from app.main import app
from app.schemas import CoordinateSpace, LandmarkPoint


client = TestClient(app)


def test_geometry_uses_world_z_only_when_world_coordinates_are_declared():
    a = LandmarkPoint(x=1, y=0, z=1, visibility=1, presence=1)
    vertex = LandmarkPoint(x=0, y=0, z=0, visibility=1, presence=1)
    c = LandmarkPoint(x=0, y=1, z=0, visibility=1, presence=1)
    assert calculate_angle(a, vertex, c, CoordinateSpace.NORMALIZED_IMAGE) == 90.0
    assert calculate_angle(a, vertex, c, CoordinateSpace.WORLD) == 90.0


def test_geometry_returns_none_for_zero_length_vectors():
    point = LandmarkPoint(x=0, y=0, z=0, visibility=1, presence=1)
    other = LandmarkPoint(x=1, y=0, z=0, visibility=1, presence=1)
    assert calculate_angle(point, point, other) is None


def squat_payload(**overrides):
    coordinates = {
        11: (0.40, 0.10),
        12: (0.60, 0.10),
        13: (0.30, 0.20),
        14: (0.70, 0.20),
        15: (0.20, 0.30),
        16: (0.80, 0.30),
        23: (0.40, 0.40),
        24: (0.60, 0.40),
        25: (0.40, 0.60),
        26: (0.60, 0.60),
        27: (0.60, 0.60),
        28: (0.40, 0.60),
    }
    landmarks = [
        {
            "index": index,
            "x": coordinates.get(index, (0.5, 0.5))[0],
            "y": coordinates.get(index, (0.5, 0.5))[1],
            "z": 0.0,
            "visibility": 0.99,
            "presence": 0.99,
        }
        for index in range(33)
    ]
    payload = {
        "schema_version": "1.0",
        "user_id": "usr_test",
        "session_id": "session_test",
        "skill_id": "sk_3",
        "skill_name": "Bodyweight Squat",
        "landmarks": landmarks,
        "coordinate_space": "normalized_image",
        "image_width": 1080,
        "image_height": 1920,
        "timestamp_us": 123456789,
        "camera_facing": "back",
        "subject_view": "front",
        "mirrored": False,
        "rotation_degrees": 0,
        "human_detected": True,
        "tracking_state": "HUMAN_LOCKED",
    }
    payload.update(overrides)
    return payload


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "Healthy"
    assert len(response.json()["active_agents"]) == 9


def test_temporal_endpoint_counts_a_valid_squat_and_exposes_phase():
    timestamps = [i * 100_000 for i in range(12)]
    angles = [170, 170, 160, 140, 120, 105, 110, 125, 140, 155, 170, 170]
    responses = []
    for timestamp, angle in zip(timestamps, angles):
        response = client.post(
            "/agents/temporal/squat",
            json={
                "user_id": "temporal_test",
                "session_id": "temporal_session",
                "skill_id": "sk_3",
                "timestamp_us": timestamp,
                "subject_view": "side",
                "status": "VALID",
                "measurement_confidence": 0.95,
                "landmarks": squat_payload()["landmarks"],
                "left_knee_angle": angle,
                "right_knee_angle": angle,
                "left_hip_angle": angle,
                "right_hip_angle": angle,
                "torso_inclination": 10,
            },
        )
        assert response.status_code == 200
        responses.append(response.json())
    assert responses[-1]["repetition_count"] == 1
    assert sum(result["completed_rep"] for result in responses) == 1
    assert responses[-1]["landmarks_retained"] == 33
    assert isinstance(responses[-1]["verified_findings"], list)


def test_temporal_state_isolated_by_exercise_identity():
    timestamps = [i * 100_000 for i in range(12)]
    angles = [170, 170, 160, 140, 120, 105, 110, 125, 140, 155, 170, 170]
    for timestamp, angle in zip(timestamps, angles):
        response = client.post(
            "/agents/temporal/squat",
            json={
                "user_id": "temporal_isolation",
                "session_id": "shared_session",
                "skill_id": "sk_3",
                "timestamp_us": timestamp,
                "subject_view": "side",
                "status": "VALID",
                "measurement_confidence": 0.95,
                "landmarks": squat_payload()["landmarks"],
                "left_knee_angle": angle,
                "right_knee_angle": angle,
                "left_hip_angle": angle,
                "right_hip_angle": angle,
                "torso_inclination": 10,
            },
        )
        assert response.status_code == 200

    boxing = client.post(
        "/agents/temporal/squat",
        json={
            "user_id": "temporal_isolation",
            "session_id": "shared_session",
            "skill_id": "sk_boxing",
            "timestamp_us": 2_000_000,
            "subject_view": "side",
            "status": "VALID",
            "measurement_confidence": 0.95,
            "landmarks": squat_payload()["landmarks"],
            "left_knee_angle": 105,
            "right_knee_angle": 105,
            "left_hip_angle": 105,
            "right_hip_angle": 105,
            "torso_inclination": 10,
        },
    )
    assert boxing.status_code == 200
    assert boxing.json()["status"] == "INSUFFICIENT_DATA"
    assert boxing.json()["repetition_count"] == 0


def test_temporal_reset_endpoint_clears_all_exercise_trackers_for_session():
    response = client.post(
        "/agents/temporal/squat",
        json={
            "user_id": "temporal_reset",
            "session_id": "reset_session",
            "skill_id": "sk_3",
            "timestamp_us": 1,
            "subject_view": "side",
            "status": "VALID",
            "measurement_confidence": 0.95,
            "landmarks": squat_payload()["landmarks"],
            "left_knee_angle": 170,
            "right_knee_angle": 170,
            "left_hip_angle": 170,
            "right_hip_angle": 170,
            "torso_inclination": 10,
        },
    )
    assert response.status_code == 200
    reset = client.delete("/agents/temporal/squat/temporal_reset/reset_session")
    assert reset.status_code == 200
    assert reset.json() == {"status": "reset"}

    after_reset = client.post(
        "/agents/temporal/squat",
        json={
            "user_id": "temporal_reset",
            "session_id": "reset_session",
            "skill_id": "sk_3",
            "timestamp_us": 2,
            "subject_view": "side",
            "status": "VALID",
            "measurement_confidence": 0.95,
            "landmarks": squat_payload()["landmarks"],
            "left_knee_angle": 170,
            "right_knee_angle": 170,
            "left_hip_angle": 170,
            "right_hip_angle": 170,
            "torso_inclination": 10,
        },
    )
    assert after_reset.status_code == 200
    assert after_reset.json()["repetition_count"] == 0


def test_planner():
    response = client.post(
        "/agents/planner",
        json={"preferred_skills": ["Boxing"], "experience_level": "Novice"},
    )
    assert response.status_code == 200
    assert len(response.json()["roadmap_steps"]) > 0
    assert response.json()["lesson_of_the_day"]["target_score"] == 500


def test_vision_reports_frame_quality_without_claiming_motion():
    response = client.post(
        "/agents/vision",
        json={
            "user_id": "usr_test",
            "skill_id": "unknown",
            "keypoints": [
                {"x": 0.5, "y": 0.5, "z": 0.0, "visibility": 0.99},
                {"x": 0.6, "y": 0.7, "z": 0.1, "visibility": 0.95},
            ],
            "timestamp": 1234567.89,
        },
    )
    assert response.status_code == 200
    assert response.json()["status"] == "VALID"
    assert response.json()["is_moving"] is None
    assert response.json()["detected_landmarks_count"] == 2
    assert response.json()["tracking_quality_index"] > 0.9


def test_biomechanics_uses_canonical_indices_and_geometry():
    response = client.post("/agents/biomechanics", json=squat_payload())
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "VALID"
    assert math.isclose(data["left_knee_angle"], 90.0, abs_tol=0.01)
    assert math.isclose(data["right_knee_angle"], 90.0, abs_tol=0.01)
    assert math.isclose(data["torso_inclination"], 0.0, abs_tol=0.01)
    assert data["bilateral_knee_symmetry"] == 1.0
    assert "velocity" not in data
    assert "center_of_gravity" not in data


def test_performance_scores_only_valid_squat_measurements():
    biomechanics = client.post("/agents/biomechanics", json=squat_payload()).json()
    response = client.post("/agents/performance", json=biomechanics)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "VALID"
    assert data["feedback_eligible"] is True
    assert data["quality_score"] == 100.0
    assert data["xp"] == 1250
    assert data["is_correct"] is True


def test_low_confidence_never_becomes_a_successful_score():
    payload = squat_payload()
    payload["landmarks"][25]["visibility"] = 0.2
    biomechanics = client.post("/agents/biomechanics", json=payload).json()
    assert biomechanics["status"] == "LOW_CONFIDENCE"
    assert biomechanics["left_knee_angle"] is None
    performance = client.post("/agents/performance", json=biomechanics).json()
    assert performance["status"] == "LOW_CONFIDENCE"
    assert performance["quality_score"] is None
    assert performance["xp"] is None
    assert performance["feedback_eligible"] is False


def test_missing_landmark_abstains_without_padding():
    payload = squat_payload()
    payload["landmarks"] = [landmark for landmark in payload["landmarks"] if landmark["index"] != 25]
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "INSUFFICIENT_DATA"
    assert response.json()["left_knee_angle"] is None


def test_duplicate_canonical_landmark_abstains_without_overwriting():
    payload = squat_payload()
    payload["landmarks"].append(dict(payload["landmarks"][25]))
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "TRACKING_LOST"
    assert response.json()["left_knee_angle"] is None


def test_low_presence_is_not_treated_as_visible():
    payload = squat_payload()
    payload["landmarks"][26]["presence"] = 0.1
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "LOW_CONFIDENCE"
    assert response.json()["right_knee_angle"] is None


def test_missing_optional_elbow_measurement_is_explicitly_unavailable():
    payload = squat_payload()
    payload["landmarks"] = [landmark for landmark in payload["landmarks"] if landmark["index"] != 13]
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "VALID"
    assert response.json()["left_elbow_angle"] is None
    assert "left_elbow_angle" in response.json()["unavailable_measurements"]


def test_empty_landmarks_report_tracking_lost():
    payload = squat_payload(landmarks=[], human_detected=False, tracking_state="SEARCHING_FOR_HUMAN")
    response = client.post("/agents/vision", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "TRACKING_LOST"
    biomechanics = client.post("/agents/biomechanics", json=payload)
    assert biomechanics.json()["status"] == "TRACKING_LOST"


def test_nonfinite_coordinate_is_rejected_from_measurement():
    payload = squat_payload()
    payload["landmarks"][25]["x"] = float("nan")
    response = client.post("/agents/biomechanics", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "INSUFFICIENT_DATA"
    assert response.json()["left_knee_angle"] is None


def test_degenerate_geometry_is_unavailable():
    payload = squat_payload()
    for index in (23, 25, 27):
        payload["landmarks"][index]["x"] = 0.4
        payload["landmarks"][index]["y"] = 0.6
    response = client.post("/agents/biomechanics", json=payload)
    assert response.json()["status"] == "INSUFFICIENT_DATA"
    assert response.json()["left_knee_angle"] is None


def test_unsupported_view_is_explicit():
    response = client.post(
        "/agents/biomechanics",
        json=squat_payload(subject_view="top_down"),
    )
    assert response.status_code == 200
    assert response.json()["status"] == "UNSUPPORTED_VIEW"


def test_unknown_exercise_does_not_default_to_a_profile():
    response = client.post(
        "/agents/biomechanics",
        json=squat_payload(skill_id="unlisted_skill", skill_name="Mystery movement"),
    )
    assert response.status_code == 200
    assert response.json()["status"] == "INSUFFICIENT_DATA"


def test_non_squat_profiles_do_not_receive_squat_rules():
    payload = squat_payload(skill_id="sk_boxing", skill_name="Boxing Guard")
    response = client.post("/agents/biomechanics", json=payload)
    assert response.json()["status"] == "VALID"
    performance = client.post("/agents/performance", json=response.json())
    assert performance.status_code == 200
    assert performance.json()["quality_score"] is None
    assert performance.json()["feedback_eligible"] is False


def test_coach_handles_uncertain_analysis_without_claiming_flawless_form():
    response = client.post(
        "/agents/coach",
        json={
            "detected_mistakes": [],
            "practice_score": None,
            "analysis_status": "LOW_CONFIDENCE",
            "quality_score": None,
            "verified_measurements": {},
        },
    )
    assert response.status_code == 200
    assert "cannot verify" in response.json()["feedback_text"].lower()


def test_coach_receives_only_verified_measurements_for_valid_analysis():
    response = client.post(
        "/agents/coach",
        json={
            "detected_mistakes": ["Left knee is outside the configured range."],
            "practice_score": 1000,
            "analysis_status": "VALID",
            "quality_score": 80.0,
            "verified_findings": ["squat_knee_range"],
            "verified_measurements": {"left_knee_angle": 145.0},
        },
    )
    assert response.status_code == 200
    assert "feedback_text" in response.json()


def test_coach_explains_temporal_depth_finding_without_inventing_measurements():
    response = client.post(
        "/agents/coach",
        json={
            "detected_mistakes": [],
            "analysis_status": "VALID",
            "quality_score": 80.0,
            "verified_findings": ["squat_depth"],
            "verified_measurements": {"left_knee_angle": 135.0},
        },
    )
    assert response.status_code == 200
    text = response.json()["feedback_text"].lower()
    assert "depth" in text
    assert "injury" not in text


def test_coach_ignores_unsupported_free_text_findings():
    response = client.post(
        "/agents/coach",
        json={
            "detected_mistakes": ["possible spine injury and balance failure"],
            "analysis_status": "VALID",
            "quality_score": 80.0,
            "verified_findings": [],
            "verified_measurements": {},
        },
    )
    assert response.status_code == 200
    text = response.json()["feedback_text"].lower()
    assert "spine" not in text
    assert "injury" not in text
    assert "gravity" not in text


def test_twin():
    response = client.post(
        "/agents/twin/update",
        json={
            "user_id": "usr_test",
            "recent_mistakes": ["Shoulders out of alignment"],
            "session_scores": [1200, 1400, 1500],
        },
    )
    assert response.status_code == 200
    assert response.json()["user_id"] == "usr_test"
    response = client.get("/agents/twin/usr_test")
    assert response.status_code == 200
    assert response.json()["predicted_days_to_mastery"] > 0


def test_memory_accepts_sessions_without_a_score():
    response = client.post(
        "/agents/memory/store",
        json={
            "session_id": "sess_no_score",
            "user_id": "usr_memory",
            "duration_seconds": 120,
            "mistakes_log": [],
        },
    )
    assert response.status_code == 200
    history = client.get("/agents/memory/history/usr_memory")
    assert history.status_code == 200
    assert history.json()["cumulative_score"] == 0
