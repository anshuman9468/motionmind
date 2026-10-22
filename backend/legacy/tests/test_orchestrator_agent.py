import unittest
import asyncio
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.orchestrator_agent import (
    OrchestratorAgent,
    PracticeSessionInput,
    UnifiedOrchestratorResponse
)


class TestOrchestratorAgent(unittest.TestCase):

    def setUp(self):
        self.orchestrator = OrchestratorAgent()
        self.test_user = "user_orch_999"

    def test_full_pipeline_execution(self):
        """Test full 7-agent async pipeline execution."""
        mock_landmarks = []
        for i in range(33):
            mock_landmarks.append({
                "x": 0.5 + 0.01 * (i % 5),
                "y": 0.5 + 0.02 * (i % 3),
                "z": 0.1 * (i % 2),
                "visibility": 0.95
            })

        payload = PracticeSessionInput(
            user_id=self.test_user,
            skill="squat",
            landmarks=mock_landmarks,
            rep_count=5,
            session_duration_sec=90.0
        )

        # Run async pipeline
        result = asyncio.run(self.orchestrator.process_session(payload))

        # Verify top-level JSON keys match exact requirement
        self.assertIn("quality_score", result)
        self.assertIn("mistakes", result)
        self.assertIn("coach", result)
        self.assertIn("recommendations", result)
        self.assertIn("digital_twin", result)
        self.assertIn("progress", result)

        self.assertIsInstance(result["quality_score"], int)
        self.assertIsInstance(result["mistakes"], list)
        self.assertIsInstance(result["coach"], dict)
        self.assertIsInstance(result["recommendations"], dict)
        self.assertIsInstance(result["digital_twin"], dict)
        self.assertIsInstance(result["progress"], dict)

        # Sub-dictionary key verification
        self.assertIn("feedback", result["coach"])
        self.assertIn("reason", result["coach"])

        self.assertIn("drills", result["recommendations"])
        self.assertIn("warmup", result["recommendations"])

        self.assertIn("metrics", result["digital_twin"])
        self.assertIn("average_score", result["progress"])

    def test_pipeline_with_features_input(self):
        """Test pipeline when pre-computed features are passed instead of landmarks."""
        payload = PracticeSessionInput(
            user_id="user_feat_1",
            skill="boxing",
            features=[0.5, 0.6, 0.7, 0.8, 0.9]
        )

        result = asyncio.run(self.orchestrator.process_session(payload))
        self.assertIn("quality_score", result)
        self.assertIn("coach", result)
        self.assertIn("digital_twin", result)

    def test_pydantic_response_model(self):
        """Test UnifiedOrchestratorResponse validation."""
        payload = PracticeSessionInput(user_id="user_pydantic", skill="basketball")
        res_dict = asyncio.run(self.orchestrator.process_session(payload))
        
        response_model = UnifiedOrchestratorResponse(**res_dict)
        self.assertEqual(response_model.quality_score, res_dict["quality_score"])


if __name__ == "__main__":
    unittest.main()
