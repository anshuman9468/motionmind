import unittest
import sys
import os
import shutil
import tempfile

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.digital_twin_agent import (
    DigitalTwinAgent,
    DigitalTwinProfile,
    DigitalTwinMetrics,
    SessionUpdatePayload,
    InMemoryStorageAdapter,
    JSONFileStorageAdapter
)


class TestDigitalTwinAgent(unittest.TestCase):

    def setUp(self):
        self.in_memory_agent = DigitalTwinAgent(storage_adapter=InMemoryStorageAdapter())
        self.test_user_id = "user_test_123"

    def test_create_twin(self):
        """Test twin creation with baseline metrics."""
        profile = self.in_memory_agent.create_twin(
            user_id=self.test_user_id,
            username="Test Athlete",
            initial_metrics={"strength": 60.0, "balance": 70.0}
        )

        self.assertEqual(profile["user_id"], self.test_user_id)
        self.assertEqual(profile["username"], "Test Athlete")
        self.assertEqual(profile["metrics"]["strength"], 60.0)
        self.assertEqual(profile["metrics"]["balance"], 70.0)
        self.assertEqual(profile["metrics"]["coordination"], 50.0)

    def test_get_twin_autocreate(self):
        """Test retrieving twin auto-creates baseline if absent."""
        profile = self.in_memory_agent.get("new_user_999")
        self.assertEqual(profile["user_id"], "new_user_999")
        self.assertEqual(profile["total_sessions"], 0)
        self.assertIn("strength", profile["metrics"])

    def test_update_twin_metrics(self):
        """Test updating metrics after a workout session."""
        self.in_memory_agent.create_twin(self.test_user_id)

        update_payload = SessionUpdatePayload(
            user_id=self.test_user_id,
            quality_score=85.0,
            mistakes=["Shallow Depth"],
            skill="squat",
            rep_count=10,
            session_duration_sec=120.0
        )

        updated_profile = self.in_memory_agent.update(self.test_user_id, update_payload)

        self.assertEqual(updated_profile["total_sessions"], 1)
        metrics = updated_profile["metrics"]

        # Check all 8 required metrics exist
        for key in ["strength", "balance", "coordination", "mobility", "reaction", "consistency", "confidence", "fatigue"]:
            self.assertIn(key, metrics)
            self.assertGreaterEqual(metrics[key], 0.0)
            self.assertLessEqual(metrics[key], 100.0)

    def test_json_file_storage_adapter(self):
        """Test abstract file-backed storage adapter."""
        temp_dir = tempfile.mkdtemp()
        try:
            file_path = os.path.join(temp_dir, "test_twins.json")
            adapter = JSONFileStorageAdapter(file_path=file_path)
            agent = DigitalTwinAgent(storage_adapter=adapter)

            agent.create_twin("user_file_1", username="Persisted Athlete")
            retrieved = agent.get("user_file_1")
            self.assertEqual(retrieved["username"], "Persisted Athlete")
        finally:
            shutil.rmtree(temp_dir)


if __name__ == "__main__":
    unittest.main()
