"""
PoseAgent module for MotionMind backend.

Production-ready agent responsible for accepting MediaPipe body and hand keypoints,
cleaning noise/low-visibility coordinates, normalizing spatial positions, and generating
rich geometric and spatial feature vectors for downstream downstream evaluation/analytics.

Note: This agent does NOT perform ML model inference.
"""

import logging
import math
from typing import List, Dict, Any, Union, Tuple, Optional
import numpy as np
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("PoseAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ---------------------------------------------------------------------------
# Pydantic Schemas for FastAPI Integration
# ---------------------------------------------------------------------------

class LandmarkItem(BaseModel):
    """Pydantic model representing a single 3D landmark with visibility."""
    x: float = Field(..., description="X coordinate (normalized or pixel space)")
    y: float = Field(..., description="Y coordinate (normalized or pixel space)")
    z: float = Field(default=0.0, description="Z coordinate (depth)")
    visibility: float = Field(default=1.0, ge=0.0, le=1.0, description="MediaPipe confidence / visibility score")

    model_config = ConfigDict(extra="ignore")


class PoseAgentInput(BaseModel):
    """FastAPI request schema for PoseAgent feature extraction."""
    landmarks: List[Union[LandmarkItem, Dict[str, Any], List[float]]] = Field(
        ...,
        description="List of landmarks. Can be objects with x,y,z,visibility or coordinate tuples [x,y,z,vis]"
    )
    landmark_type: str = Field(
        default="body",
        description="Type of landmarks: 'body', 'hand', 'hand_left', or 'hand_right'"
    )
    visibility_threshold: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Minimum visibility score below which keypoints are treated as noisy"
    )

    model_config = ConfigDict(extra="ignore")


class PoseAgentOutput(BaseModel):
    """FastAPI response schema matching exact required output format."""
    feature_vector: List[float] = Field(..., description="Extracted numerical feature vector")
    landmarks: List[List[float]] = Field(..., description="Cleaned and normalized 3D landmark coordinates [[x,y,z], ...]")
    visibility: List[float] = Field(..., description="Per-landmark visibility confidence scores")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# PoseAgent Implementation
# ---------------------------------------------------------------------------

class PoseAgent:
    """
    Production-ready agent that processes raw MediaPipe body and hand landmarks.
    
    Responsibilities:
      - Receive MediaPipe keypoints (body or hand)
      - Remove noisy / low-confidence values
      - Normalize coordinates (scale & origin alignment)
      - Build feature vectors (joint angles, relative distances, spatial statistics)
      - Return structured output without performing ML inference
    """

    SUPPORTED_TYPES = {"body", "hand", "hand_left", "hand_right"}

    def __init__(self, default_visibility_threshold: float = 0.5):
        """
        Initialize PoseAgent with default parameters.

        Args:
            default_visibility_threshold: Default score threshold for filtering low visibility landmarks.
        """
        self.default_visibility_threshold = default_visibility_threshold

    # -----------------------------------------------------------------------
    # Core Public Interface Methods
    # -----------------------------------------------------------------------

    def extract(self, data: Union[PoseAgentInput, Dict[str, Any], List[Any]]) -> Dict[str, Any]:
        """
        Main entry point. Receives MediaPipe keypoints payload, performs noise filtering,
        normalizes coordinates, builds feature vectors, and returns structured result.

        Args:
            data: Input payload (PoseAgentInput, dict, or raw list of landmarks)

        Returns:
            Dict[str, Any] matching the schema:
            {
                "feature_vector": [...],
                "landmarks": [...],
                "visibility": [...]
            }
        """
        try:
            landmarks_raw, visibility_raw, landmark_type, vis_threshold = self._parse_input(data)

            # Step 1: Remove noisy values
            clean_coords, clean_vis = self._remove_noise(
                landmarks_raw,
                visibility_raw,
                threshold=vis_threshold
            )

            # Step 2: Normalize coordinates
            normalized_coords, clean_vis = self.normalize(
                landmarks=clean_coords,
                visibility=clean_vis,
                landmark_type=landmark_type
            )

            # Step 3: Build feature vector
            feature_vec = self.build_feature_vector(
                landmarks=normalized_coords,
                visibility=clean_vis,
                landmark_type=landmark_type
            )

            response = PoseAgentOutput(
                feature_vector=feature_vec,
                landmarks=normalized_coords,
                visibility=clean_vis
            )

            return response.model_dump()

        except Exception as e:
            logger.error(f"Error extracting features in PoseAgent: {e}", exc_info=True)
            # Return safe baseline fallback output
            return PoseAgentOutput(
                feature_vector=[],
                landmarks=[],
                visibility=[]
            ).model_dump()

    def normalize(
        self,
        landmarks: List[List[float]],
        visibility: Optional[List[float]] = None,
        landmark_type: str = "body"
    ) -> Tuple[List[List[float]], List[float]]:
        """
        Translates landmark origin to a landmark-specific reference center (e.g. mid-hip for body,
        wrist for hand) and scales coordinates by torso height / hand length so keypoint values
        are invariant to scale and frame positioning.

        Args:
            landmarks: List of [x, y, z] coordinates for each keypoint.
            visibility: Optional list of visibility confidence scores.
            landmark_type: Type of pose data ('body', 'hand', 'hand_left', 'hand_right').

        Returns:
            Tuple of (normalized_landmarks, visibility_list)
        """
        if not landmarks:
            return [], []

        coords = np.array(landmarks, dtype=np.float32)
        if coords.ndim != 2 or coords.shape[1] < 2:
            raise ValueError(f"Landmarks array must be of shape (N, 2) or (N, 3). Got shape {coords.shape}")

        if coords.shape[1] == 2:
            # Pad Z dimension with 0 if missing
            coords = np.pad(coords, ((0, 0), (0, 1)), mode='constant', constant_values=0.0)

        num_points = len(coords)
        vis = visibility if visibility and len(visibility) == num_points else [1.0] * num_points

        l_type = landmark_type.lower()
        
        # Determine reference center (origin offset) and scale factor
        origin = np.zeros(3, dtype=np.float32)
        scale = 1.0

        if "hand" in l_type:
            # Hand landmark layout (21 points)
            # Wrist is landmark 0, Middle MCP is landmark 9
            origin = coords[0].copy()
            if num_points > 9:
                hand_span = np.linalg.norm(coords[9] - coords[0])
                if hand_span > 1e-6:
                    scale = hand_span
                else:
                    scale = np.max(np.ptp(coords, axis=0)) or 1.0
            else:
                scale = np.max(np.ptp(coords, axis=0)) or 1.0

        else:
            # Body landmark layout (33 points)
            # 23: Left Hip, 24: Right Hip, 11: Left Shoulder, 12: Right Shoulder
            if num_points >= 25:
                # Center origin at mid-hip
                mid_hip = (coords[23] + coords[24]) / 2.0
                origin = mid_hip.copy()

                # Scale by torso length (mid-hip to mid-shoulder)
                if num_points >= 13:
                    mid_shoulder = (coords[11] + coords[12]) / 2.0
                    torso_height = np.linalg.norm(mid_shoulder - mid_hip)
                    if torso_height > 1e-6:
                        scale = torso_height
                    else:
                        scale = np.max(np.ptp(coords, axis=0)) or 1.0
                else:
                    scale = np.max(np.ptp(coords, axis=0)) or 1.0
            else:
                # Fallback center of mass for partial body
                origin = np.mean(coords, axis=0)
                scale = np.max(np.ptp(coords, axis=0)) or 1.0

        if scale <= 1e-6:
            scale = 1.0

        # Translate and scale valid keypoints; keep untracked [0,0,0] as [0,0,0]
        normalized_list: List[List[float]] = []
        for pt, v in zip(coords, vis):
            if np.all(pt == 0.0) or v < self.default_visibility_threshold:
                normalized_list.append([0.0, 0.0, 0.0])
            else:
                norm_pt = (pt - origin) / scale
                normalized_list.append([round(float(val), 6) for val in norm_pt])

        clean_vis = [round(float(v), 4) for v in vis]
        return normalized_list, clean_vis

    def build_feature_vector(
        self,
        landmarks: List[List[float]],
        visibility: List[float],
        landmark_type: str = "body"
    ) -> List[float]:
        """
        Computes spatial and geometric feature vector (angles, distances, relative offsets)
        from normalized landmarks and visibility values.

        Args:
            landmarks: Cleaned, normalized [x, y, z] landmarks list.
            visibility: Visibility confidence list.
            landmark_type: Type of landmark ('body', 'hand', etc.)

        Returns:
            List[float]: Flat numerical feature vector ready for downstream analysis.
        """
        if not landmarks:
            return []

        coords = np.array(landmarks, dtype=np.float32)
        num_points = len(coords)
        features: List[float] = []

        # 1. Flattened relative 3D coordinate positions
        features.extend(coords.flatten().tolist())

        l_type = landmark_type.lower()

        if "hand" in l_type and num_points >= 21:
            # --- Hand-Specific Geometric Features ---
            
            # Finger flex angles (MCP-PIP-DIP and PIP-DIP-TIP for 5 fingers)
            # Hand indices:
            # Thumb: 1-2-3-4
            # Index: 5-6-7-8
            # Middle: 9-10-11-12
            # Ring: 13-14-15-16
            # Pinky: 17-18-19-20
            finger_chains = [
                (1, 2, 3), (2, 3, 4),      # Thumb
                (5, 6, 7), (6, 7, 8),      # Index
                (9, 10, 11), (10, 11, 12),  # Middle
                (13, 14, 15), (14, 15, 16), # Ring
                (17, 18, 19), (18, 19, 20)  # Pinky
            ]
            for a, b, c in finger_chains:
                angle = self._calculate_3d_angle(coords[a], coords[b], coords[c])
                features.append(angle)

            # Fingertip to wrist distances (Landmarks 4, 8, 12, 16, 20 relative to 0)
            fingertips = [4, 8, 12, 16, 20]
            for tip in fingertips:
                dist = float(np.linalg.norm(coords[tip] - coords[0]))
                features.append(dist)

            # Spread distances between adjacent fingertips
            for i in range(len(fingertips) - 1):
                spread = float(np.linalg.norm(coords[fingertips[i]] - coords[fingertips[i+1]]))
                features.append(spread)

        else:
            # --- Body-Specific Geometric Features ---
            if num_points >= 33:
                # Key body joint angles
                body_angles = [
                    (11, 13, 15),  # Left Elbow
                    (12, 14, 16),  # Right Elbow
                    (23, 11, 13),  # Left Shoulder
                    (24, 12, 14),  # Right Shoulder
                    (11, 23, 25),  # Left Hip
                    (12, 24, 26),  # Right Hip
                    (23, 25, 27),  # Left Knee
                    (24, 26, 28),  # Right Knee
                    (25, 27, 31),  # Left Ankle
                    (26, 28, 32)   # Right Ankle
                ]
                for a, b, c in body_angles:
                    angle = self._calculate_3d_angle(coords[a], coords[b], coords[c])
                    features.append(angle)

                # Pairwise spatial distances
                key_pairs = [
                    (15, 16),  # Wrist-to-Wrist distance
                    (27, 28),  # Ankle-to-Ankle distance
                    (15, 11),  # L-Wrist to L-Shoulder
                    (16, 12),  # R-Wrist to R-Shoulder
                    (27, 23),  # L-Ankle to L-Hip
                    (28, 24),  # R-Ankle to R-Hip
                    (11, 12),  # Shoulder width
                    (23, 24)   # Hip width
                ]
                for p1, p2 in key_pairs:
                    dist = float(np.linalg.norm(coords[p1] - coords[p2]))
                    features.append(dist)

                # Torso vertical tilt angle
                mid_shoulder = (coords[11] + coords[12]) / 2.0
                mid_hip = (coords[23] + coords[24]) / 2.0
                torso_vec = mid_shoulder - mid_hip
                vert_vec = np.array([0.0, -1.0, 0.0], dtype=np.float32)
                tilt_angle = self._vector_angle(torso_vec, vert_vec)
                features.append(tilt_angle)

        # Summary statistics
        if visibility:
            features.append(float(np.mean(visibility)))
            features.append(float(np.sum(np.array(visibility) >= self.default_visibility_threshold) / max(1, len(visibility))))
        else:
            features.extend([1.0, 1.0])

        # Clean NaN or Inf values
        cleaned_features = [0.0 if (math.isnan(v) or math.isinf(v)) else round(float(v), 6) for v in features]
        return cleaned_features

    # -----------------------------------------------------------------------
    # Internal Helper / Noise Removal Methods
    # -----------------------------------------------------------------------

    def _remove_noise(
        self,
        landmarks: List[List[float]],
        visibility: List[float],
        threshold: float
    ) -> Tuple[List[List[float]], List[float]]:
        """
        Filters out low-visibility keypoints and replaces noisy / NaN values with safe projections.

        Args:
            landmarks: Raw 3D coordinate list.
            visibility: Confidence/visibility list.
            threshold: Visibility threshold below which coordinates are treated as noisy.

        Returns:
            Tuple of (cleaned_landmarks, cleaned_visibility)
        """
        clean_landmarks: List[List[float]] = []
        clean_visibility: List[float] = []

        coords = np.array(landmarks, dtype=np.float32)
        
        # Replace non-finite coordinates (NaN/Inf) with zero
        coords = np.nan_to_num(coords, nan=0.0, posinf=0.0, neginf=0.0)

        for idx in range(len(coords)):
            pt = coords[idx].tolist()
            vis = visibility[idx] if idx < len(visibility) else 1.0
            
            # Sanitize visibility
            if math.isnan(vis) or math.isinf(vis):
                vis = 0.0
            else:
                vis = float(np.clip(vis, 0.0, 1.0))

            # Outlier truncation (clip extreme coordinate spikes)
            pt = [float(np.clip(val, -100.0, 100.0)) for val in pt]

            # Low visibility suppression
            if vis < threshold:
                # Soft zeroing of untracked keypoint coordinates
                pt = [0.0, 0.0, 0.0]

            clean_landmarks.append(pt)
            clean_visibility.append(vis)

        return clean_landmarks, clean_visibility

    def _parse_input(
        self,
        data: Union[PoseAgentInput, Dict[str, Any], List[Any]]
    ) -> Tuple[List[List[float]], List[float], str, float]:
        """
        Parses flexible input formats (Pydantic objects, dicts, raw landmark lists)
        into normalized Python lists for processing.
        """
        landmark_type = "body"
        vis_threshold = self.default_visibility_threshold
        raw_list: List[Any] = []

        if isinstance(data, PoseAgentInput):
            raw_list = data.landmarks
            landmark_type = data.landmark_type
            vis_threshold = data.visibility_threshold
        elif isinstance(data, dict):
            raw_list = data.get("landmarks", [])
            landmark_type = data.get("landmark_type", "body")
            vis_threshold = data.get("visibility_threshold", self.default_visibility_threshold)
        elif isinstance(data, list):
            raw_list = data
        else:
            raise ValueError(f"Unsupported input type for PoseAgent: {type(data)}")

        landmarks: List[List[float]] = []
        visibility: List[float] = []

        for item in raw_list:
            if isinstance(item, LandmarkItem):
                landmarks.append([item.x, item.y, item.z])
                visibility.append(item.visibility)
            elif isinstance(item, dict):
                x = float(item.get("x", 0.0))
                y = float(item.get("y", 0.0))
                z = float(item.get("z", 0.0))
                vis = float(item.get("visibility", item.get("presence", 1.0)))
                landmarks.append([x, y, z])
                visibility.append(vis)
            elif isinstance(item, (list, tuple)):
                x = float(item[0]) if len(item) > 0 else 0.0
                y = float(item[1]) if len(item) > 1 else 0.0
                z = float(item[2]) if len(item) > 2 else 0.0
                vis = float(item[3]) if len(item) > 3 else 1.0
                landmarks.append([x, y, z])
                visibility.append(vis)
            else:
                landmarks.append([0.0, 0.0, 0.0])
                visibility.append(0.0)

        return landmarks, visibility, landmark_type, vis_threshold

    @staticmethod
    def _calculate_3d_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
        """Calculates 3D angle (in degrees) at vertex B given points A, B, C."""
        ba = a - b
        bc = c - b
        norm_ba = np.linalg.norm(ba)
        norm_bc = np.linalg.norm(bc)
        if norm_ba < 1e-6 or norm_bc < 1e-6:
            return 0.0
        cosine = np.dot(ba, bc) / (norm_ba * norm_bc)
        cosine = np.clip(cosine, -1.0, 1.0)
        angle = float(np.arccos(cosine) * 180.0 / np.pi)
        return round(angle, 4)

    @staticmethod
    def _vector_angle(v1: np.ndarray, v2: np.ndarray) -> float:
        """Calculates angle (in degrees) between two vectors."""
        norm_v1 = np.linalg.norm(v1)
        norm_v2 = np.linalg.norm(v2)
        if norm_v1 < 1e-6 or norm_v2 < 1e-6:
            return 0.0
        cosine = np.dot(v1, v2) / (norm_v1 * norm_v2)
        cosine = np.clip(cosine, -1.0, 1.0)
        angle = float(np.arccos(cosine) * 180.0 / np.pi)
        return round(angle, 4)
