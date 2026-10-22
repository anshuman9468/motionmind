import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.memory_agent import (
    MemoryAgent,
    UserProfile,
    SessionMemoryRecord,
    UserContextResponse,
    InMemoryMemoryStorageAdapter
)


class TestMemoryAgent(unittest.TestCase):

    def setUp(self):
        self.adapter = InMemoryMemoryStorageAdapter()
        self.agent = MemoryAgent(storage_adapter=self.adapter)
        self.user_id = "user_mem_1"

    def test_save_and_get_latest_session(self):
        """Test save_session and get_latest."""
        sess = self.agent.save_session(self.user_id, {
            "skill": "squat",
            "quality_score": 85.0,
            "mistakes": ["Shallow Depth"],
            "coach_feedback": {"feedback": "Good depth attempt"}
        })

        self.assertIsNotNone(sess["session_id"])
        latest = self.agent.get_latest(self.user_id)
        self.assertIsNotNone(latest)
        self.assertEqual(latest["quality_score"], 85.0)
        self.assertEqual(latest["skill"], "squat")

    def test_get_history(self):
        """Test get_history with limit and skill filter."""
        self.agent.save_session(self.user_id, {"skill": "squat", "quality_score": 70.0, "mistakes": []})
        self.agent.save_session(self.user_id, {"skill": "boxing", "quality_score": 80.0, "mistakes": []})
        self.agent.save_session(self.user_id, {"skill": "squat", "quality_score": 90.0, "mistakes": []})

        all_history = self.agent.get_history(self.user_id, limit=10)
        self.assertEqual(len(all_history), 3)

        squat_history = self.agent.get_history(self.user_id, limit=10, skill="squat")
        self.assertEqual(len(squat_history), 2)

    def test_get_user_context(self):
        """Test get_user_context returns complete aggregated context."""
        self.agent.save_session(self.user_id, {
            "skill": "squat",
            "quality_score": 80.0,
            "mistakes": ["Shallow Depth", "Back Rounded"]
        })
        self.agent.save_session(self.user_id, {
            "skill": "squat",
            "quality_score": 90.0,
            "mistakes": ["Shallow Depth"]
        })

        ctx = self.agent.get_user_context(self.user_id)

        self.assertIn("profile", ctx)
        self.assertIn("digital_twin", ctx)
        self.assertIn("latest_session", ctx)
        self.assertIn("average_quality_score", ctx)
        self.assertIn("common_mistakes", ctx)

        self.assertEqual(ctx["user_id"], self.user_id)
        self.assertEqual(ctx["average_quality_score"], 85.0)
        self.assertIn("Shallow Depth", ctx["common_mistakes"])

    def test_vector_store_interface(self):
        """Test vector storage and cosine similarity search stub."""
        vec1 = [0.1, 0.2, 0.3, 0.4]
        vec2 = [0.1, 0.2, 0.35, 0.41]
        vec3 = [-0.9, -0.8, -0.7, -0.6]

        self.adapter.store_vector(self.user_id, "Good squat form", vec1, {"type": "squat"})
        self.adapter.store_vector(self.user_id, "Slight depth error", vec2, {"type": "squat"})
        self.adapter.store_vector(self.user_id, "Boxing jab flare", vec3, {"type": "boxing"})

        results = self.adapter.query_similar(self.user_id, query_vector=[0.1, 0.2, 0.3, 0.4], top_k=2)
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["text"], "Good squat form")


if __name__ == "__main__":
    unittest.main()
