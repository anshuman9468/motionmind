import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.coach_agent import CoachAgent, CoachAgentInput, CoachFeedbackResponse


class TestCoachAgent(unittest.TestCase):

    def setUp(self):
        self.agent = CoachAgent()

    def test_prompt_template_loaded(self):
        """Verify coach_prompt.txt is found and loaded."""
        self.assertIsNotNone(self.agent.prompt_template)
        self.assertIn("{skill}", self.agent.prompt_template)
        self.assertIn("{mistakes}", self.agent.prompt_template)

    def test_analyze_squat_feedback(self):
        """Test analyze output structure for squat skill."""
        result = self.agent.analyze(
            skill="squat",
            quality_score=68,
            mistakes=["Shallow Depth - You are not squatting low enough."],
            confidence=0.92
        )

        # Check required schema keys
        self.assertIn("feedback", result)
        self.assertIn("reason", result)
        self.assertIn("correction", result)
        self.assertIn("encouragement", result)

        self.assertIsInstance(result["feedback"], str)
        self.assertIsInstance(result["reason"], str)
        self.assertIsInstance(result["correction"], str)
        self.assertIsInstance(result["encouragement"], str)

        # Ensure sports science reasoning is included
        self.assertGreater(len(result["reason"]), 10)
        self.assertGreater(len(result["correction"]), 10)

    def test_analyze_boxing_feedback(self):
        """Test analyze output structure for boxing skill."""
        result = self.agent.analyze(
            skill="boxing",
            quality_score=75,
            mistakes=["Elbow Flared - Elbow flaring outward during extension."],
            confidence=0.88
        )

        self.assertIn("feedback", result)
        self.assertIn("reason", result)
        self.assertIn("correction", result)
        self.assertIn("encouragement", result)

    def test_pydantic_input_output(self):
        """Test Pydantic schemas validation."""
        inp = CoachAgentInput(
            skill="basketball",
            quality_score=82,
            mistakes=["Low Elbow - Set point is too low."],
            confidence=0.95
        )
        res_dict = self.agent.analyze(
            skill=inp.skill,
            quality_score=inp.quality_score,
            mistakes=inp.mistakes,
            confidence=inp.confidence
        )
        response_model = CoachFeedbackResponse(**res_dict)
        self.assertEqual(response_model.feedback, res_dict["feedback"])


if __name__ == "__main__":
    unittest.main()
