import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.recommendation_agent import RecommendationAgent, RecommendationInput, RecommendationOutput


class TestRecommendationAgent(unittest.TestCase):

    def setUp(self):
        self.agent = RecommendationAgent()

    def test_prompt_template_loaded(self):
        """Verify recommendation_prompt.txt is found and loaded."""
        self.assertIsNotNone(self.agent.prompt_template)
        self.assertIn("{skill}", self.agent.prompt_template)
        self.assertIn("{mistakes}", self.agent.prompt_template)

    def test_recommend_squat(self):
        """Test recommendation output structure for squat skill."""
        result = self.agent.recommend(
            skill="squat",
            detected_mistakes=["Shallow Depth - You are not squatting low enough."],
            quality_score=68
        )

        self.assertIn("drills", result)
        self.assertIn("warmup", result)
        self.assertIn("cooldown", result)
        self.assertIn("next_level", result)

        self.assertIsInstance(result["drills"], list)
        self.assertIsInstance(result["warmup"], list)
        self.assertIsInstance(result["cooldown"], list)
        self.assertIsInstance(result["next_level"], str)

        self.assertGreater(len(result["drills"]), 0)
        self.assertGreater(len(result["warmup"]), 0)
        self.assertGreater(len(result["cooldown"]), 0)
        self.assertGreater(len(result["next_level"]), 0)

    def test_recommend_boxing(self):
        """Test recommendation output structure for boxing skill."""
        result = self.agent.recommend(
            skill="boxing",
            detected_mistakes=["Elbow Flared - Elbow flaring outward."],
            quality_score=75
        )

        self.assertIn("drills", result)
        self.assertIn("warmup", result)
        self.assertIn("cooldown", result)
        self.assertIn("next_level", result)

    def test_pydantic_schema(self):
        """Test Pydantic input and output schemas."""
        inp = RecommendationInput(
            skill="basketball",
            detected_mistakes=["Low Elbow Set Point"],
            quality_score=80
        )
        res_dict = self.agent.recommend(
            skill=inp.skill,
            detected_mistakes=inp.detected_mistakes,
            quality_score=inp.quality_score
        )
        output_model = RecommendationOutput(**res_dict)
        self.assertEqual(output_model.drills, res_dict["drills"])


if __name__ == "__main__":
    unittest.main()
