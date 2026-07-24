import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from agents.pose_agent import PoseAgent, PoseAgentInput, PoseAgentOutput, LandmarkItem


class TestPoseAgent(unittest.TestCase):

    def setUp(self):
        self.agent = PoseAgent(default_visibility_threshold=0.5)

    def test_pose_agent_body_extraction(self):
        mock_landmarks = []
        for i in range(33):
            mock_landmarks.append({
                "x": 0.5 + 0.01 * (i % 5),
                "y": 0.5 + 0.02 * (i % 3),
                "z": 0.1 * (i % 2),
                "visibility": 0.9 if i != 15 else 0.2  # landmark 15 low visibility
            })

        payload = PoseAgentInput(
            landmarks=mock_landmarks,
            landmark_type="body",
            visibility_threshold=0.5
        )

        result = self.agent.extract(payload)

        # Check required schema keys
        self.assertIn("feature_vector", result)
        self.assertIn("landmarks", result)
        self.assertIn("visibility", result)

        self.assertIsInstance(result["feature_vector"], list)
        self.assertIsInstance(result["landmarks"], list)
        self.assertIsInstance(result["visibility"], list)

        self.assertEqual(len(result["landmarks"]), 33)
        self.assertEqual(len(result["visibility"]), 33)
        self.assertGreater(len(result["feature_vector"]), 0)

        # Low visibility landmark 15 zeroed out
        self.assertEqual(result["landmarks"][15], [0.0, 0.0, 0.0])
        self.assertEqual(result["visibility"][15], 0.2)

    def test_pose_agent_hand_extraction(self):
        mock_landmarks = []
        for i in range(21):
            mock_landmarks.append([0.1 * i, 0.2 * i, 0.05 * i, 0.95])

        result = self.agent.extract({
            "landmarks": mock_landmarks,
            "landmark_type": "hand",
            "visibility_threshold": 0.4
        })

        self.assertIn("feature_vector", result)
        self.assertIn("landmarks", result)
        self.assertIn("visibility", result)

        self.assertEqual(len(result["landmarks"]), 21)
        self.assertEqual(len(result["visibility"]), 21)
        self.assertGreater(len(result["feature_vector"]), 0)

    def test_pose_agent_methods_direct_call(self):
        coords = [[0.0, 0.0, 0.0], [1.0, 2.0, 0.5], [0.5, 1.0, 0.2]]
        vis = [0.9, 0.8, 0.7]

        # Test normalize()
        norm_coords, norm_vis = self.agent.normalize(coords, vis, landmark_type="body")
        self.assertEqual(len(norm_coords), 3)
        self.assertEqual(len(norm_vis), 3)

        # Test build_feature_vector()
        feat_vec = self.agent.build_feature_vector(norm_coords, norm_vis, landmark_type="body")
        self.assertIsInstance(feat_vec, list)
        self.assertGreater(len(feat_vec), 0)


if __name__ == "__main__":
    unittest.main()
