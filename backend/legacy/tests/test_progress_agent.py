import unittest
import sys
import os
from datetime import datetime, timezone, timedelta

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.progress_agent import (
    ProgressAgent,
    ProgressInput,
    ProgressOutput,
    SessionRecord,
    ProgressAnalyticsEngine,
    ProgressPredictiveEngine
)


class TestProgressAgent(unittest.TestCase):

    def setUp(self):
        self.agent = ProgressAgent()
        
        # Create mock historical session sequence
        now = datetime.now(timezone.utc)
        self.mock_sessions = [
            SessionRecord(
                quality_score=70.0,
                timestamp=(now - timedelta(days=12)).isoformat(),
                mistakes=["Shallow Depth"],
                skill="squat"
            ),
            SessionRecord(
                quality_score=75.0,
                timestamp=(now - timedelta(days=10)).isoformat(),
                mistakes=["Shallow Depth"],
                skill="squat"
            ),
            SessionRecord(
                quality_score=82.0,
                timestamp=(now - timedelta(days=5)).isoformat(),
                mistakes=["Back Rounded"],
                skill="squat"
            ),
            SessionRecord(
                quality_score=88.0,
                timestamp=(now - timedelta(days=2)).isoformat(),
                mistakes=[],
                skill="squat"
            ),
            SessionRecord(
                quality_score=91.0,
                timestamp=(now - timedelta(days=1)).isoformat(),
                mistakes=[],
                skill="squat"
            )
        ]

    def test_progress_agent_output_schema(self):
        """Test ProgressAgent generates exact required JSON keys and format."""
        result = self.agent.analyze(self.mock_sessions)

        self.assertIn("weekly_improvement", result)
        self.assertIn("average_score", result)
        self.assertIn("prediction", result)
        self.assertIn("mastery_days", result)

        self.assertIsInstance(result["weekly_improvement"], int)
        self.assertIsInstance(result["average_score"], int)
        self.assertIsInstance(result["prediction"], int)
        self.assertIsInstance(result["mastery_days"], int)

        self.assertEqual(result["average_score"], 81)
        self.assertGreater(result["prediction"], 80)
        self.assertGreaterEqual(result["mastery_days"], 0)

    def test_decoupled_analytics_engine(self):
        """Test ProgressAnalyticsEngine independently."""
        scores = [70.0, 80.0, 90.0]
        avg = ProgressAnalyticsEngine.calculate_average_score(scores)
        self.assertEqual(avg, 80.0)

        freq = ProgressAnalyticsEngine.calculate_mistake_frequency(self.mock_sessions)
        self.assertEqual(freq.get("Shallow Depth"), 2)
        self.assertEqual(freq.get("Back Rounded"), 1)

    def test_decoupled_predictive_engine(self):
        """Test ProgressPredictiveEngine independently."""
        scores = [70.0, 75.0, 82.0, 88.0, 91.0]
        pred = ProgressPredictiveEngine.predict_next_score(scores, weekly_imp=12.0)
        self.assertGreater(pred, 85.0)
        self.assertLessEqual(pred, 100.0)

        days = ProgressPredictiveEngine.estimate_mastery_days(current_avg=81.0, weekly_imp=12.0, target_score=95.0)
        self.assertGreater(days, 0)

        plateau = ProgressPredictiveEngine.calculate_plateau_probability([80.0, 80.0, 80.5, 80.2])
        self.assertGreater(plateau, 0.50)

    def test_pydantic_input_validation(self):
        """Test FastAPI payload parsing."""
        inp = ProgressInput(
            user_id="usr_555",
            sessions=self.mock_sessions,
            skill="squat"
        )
        res_dict = self.agent.analyze(inp.sessions, skill_filter=inp.skill)
        output_model = ProgressOutput(**res_dict)
        self.assertEqual(output_model.average_score, res_dict["average_score"])


if __name__ == "__main__":
    unittest.main()
