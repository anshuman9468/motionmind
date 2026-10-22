import os
import logging
import joblib
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Union
import numpy as np
import pandas as pd
from pydantic import BaseModel, Field

# Configure logging
logger = logging.getLogger("MotionIntelligenceAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# Pydantic Schemas
class EvaluationRequest(BaseModel):
    skill: str = Field(..., description="Target skill name e.g., 'boxing', 'basketball', 'squat'")
    features: List[Union[float, int, List[float]]] = Field(..., description="Feature vector or list of feature values")

class EvaluationResponse(BaseModel):
    skill: str = Field(..., description="Evaluated skill name")
    quality_score: int = Field(..., ge=0, le=100, description="Overall quality score from 0 to 100")
    mistakes: List[str] = Field(default_factory=list, description="List of detected motion mistakes")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Model prediction confidence score")
    timestamp: str = Field(..., description="ISO 8601 formatted UTC timestamp")


class MotionIntelligenceAgent:
    """
    Production-ready AI Agent responsible for loading pre-trained sklearn models
    and evaluating motion quality & detecting form mistakes.
    """

    SUPPORTED_SKILLS = {"boxing", "basketball", "squat"}

    # Human-readable mistake mapping dictionaries
    MISTAKE_DICTIONARIES: Dict[str, Dict[int, str]] = {
        "squat": {
            0: "Good Form - Proper depth and back posture.",
            1: "Shallow Depth - You are not squatting low enough.",
            2: "Back Rounded - Torso leaning too far forward.",
            3: "Unstable Knees - Knees caving inward during ascent."
        },
        "boxing": {
            0: "Good Form - Clean extension and tight guard.",
            1: "Elbow Flared - Elbow flaring outward during extension.",
            2: "No Hip Rotation - Lacking kinetic chain hip turn.",
            3: "Guard Dropped - Off-hand dropping below jaw level."
        },
        "basketball": {
            0: "Good Form - Excellent set point and release arc.",
            1: "Low Elbow - Set point is too low before release.",
            2: "No Leg Drive - Shooting using only upper body force.",
            3: "Poor Release Angle - Flat shot arc trajectory."
        },
        "general": {
            0: "Good Form - Motion performed correctly.",
            1: "Form Discrepancy - Slight posture deviation detected.",
            2: "Improper Execution - Body alignment needs adjustment."
        }
    }

    def __init__(self, model_dir: Optional[str] = None):
        """
        Initialize the agent and attempt automatic model loading.
        """
        self.model_dir = model_dir or self._resolve_default_model_dir()
        self.models: Dict[str, Any] = {}
        self.is_loaded: bool = False
        self.load_models()

    def _resolve_default_model_dir(self) -> str:
        """
        Resolves model directory by searching common project locations.
        """
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidate_paths = [
            os.path.join(base_dir, "ml", "models"),
            os.path.join(base_dir, "ml"),
            os.path.join(base_dir, "models"),
            os.getcwd()
        ]
        for path in candidate_paths:
            if os.path.exists(path) and any(f.endswith(".pkl") for f in os.listdir(path)):
                logger.info(f"Resolved model directory: {path}")
                return path
        
        fallback = os.path.join(base_dir, "ml")
        logger.warning(f"No models directory found with .pkl files. Defaulting to: {fallback}")
        return fallback

    def load_models(self) -> None:
        """
        Loads all required sklearn model files into memory only once during startup.
        """
        logger.info(f"Starting model loading from: {self.model_dir}")
        
        target_model_files = [
            "basketball_quality.pkl", "basketball_mistake.pkl",
            "boxing_quality.pkl", "boxing_mistake.pkl",
            "squat_quality.pkl", "squat_mistake.pkl",
            "quality_model.pkl", "mistake_model.pkl"
        ]

        loaded_count = 0
        for model_name in target_model_files:
            file_path = os.path.join(self.model_dir, model_name)
            if os.path.exists(file_path):
                try:
                    model = joblib.load(file_path)
                    self.models[model_name] = model
                    loaded_count += 1
                    logger.info(f"Successfully loaded model: {model_name}")
                except Exception as e:
                    logger.error(f"Failed to load model file '{model_name}': {e}", exc_info=True)
            else:
                logger.warning(f"Model file not found: {file_path}")

        self.is_loaded = loaded_count > 0
        logger.info(f"Model loading completed. Total loaded: {loaded_count}/{len(target_model_files)}")

    def _get_model_pair(self, skill: str):
        """
        Determines and retrieves the correct quality and mistake model pair for a given skill.
        Falls back to quality_model.pkl and mistake_model.pkl if skill specific model is absent.
        """
        normalized_skill = skill.strip().lower()
        
        # Match skill to supported keys
        matched_skill = None
        for supported in self.SUPPORTED_SKILLS:
            if supported in normalized_skill:
                matched_skill = supported
                break

        if matched_skill:
            q_key = f"{matched_skill}_quality.pkl"
            m_key = f"{matched_skill}_mistake.pkl"
            if q_key in self.models and m_key in self.models:
                logger.info(f"Using skill-specific models for '{matched_skill}'")
                return matched_skill, self.models[q_key], self.models[m_key]

        # Fallback to general models
        logger.warning(f"No specific model found for skill '{skill}'. Falling back to default models.")
        q_fallback = self.models.get("quality_model.pkl")
        m_fallback = self.models.get("mistake_model.pkl")
        return matched_skill or "general", q_fallback, m_fallback

    def _prepare_features(self, features: Union[List, Dict[str, Any], np.ndarray, pd.DataFrame], target_model: Any = None) -> np.ndarray:
        """
        Prepares raw input features into a 2D numpy array suitable for sklearn model prediction.
        Flexibly handles lists, dicts, numpy arrays, and DataFrames.
        """
        if isinstance(features, pd.DataFrame):
            arr = features.values
        elif isinstance(features, dict):
            arr = np.array([list(features.values())], dtype=np.float32)
        else:
            arr = np.array(features, dtype=np.float32)
            if arr.ndim == 1:
                arr = arr.reshape(1, -1)

        # Align feature dimension with model expectation if target_model is provided
        if target_model is not None:
            expected_n = getattr(target_model, "n_features_in_", None)
            if expected_n is not None and arr.shape[1] != expected_n:
                logger.warning(f"Feature shape mismatch for model. Expected {expected_n}, got {arr.shape[1]}. Reshaping features.")
                if arr.shape[1] > expected_n:
                    arr = arr[:, :expected_n]
                else:
                    padding = np.zeros((arr.shape[0], expected_n - arr.shape[1]), dtype=np.float32)
                    arr = np.hstack([arr, padding])

        return arr

    def evaluate(self, skill: str, features: Union[List[Any], Dict[str, Any]]) -> Dict[str, Any]:
        """
        Evaluates input motion features for a skill and returns structured results.

        Args:
            skill: Name of the skill (e.g. 'boxing', 'basketball', 'squat')
            features: List of feature values, feature dict, or feature vector

        Returns:
            Dict containing skill, quality_score, mistakes, confidence, and timestamp.
        """
        timestamp = datetime.now(timezone.utc).isoformat()
        normalized_skill = skill.strip().lower()

        if features is None or (isinstance(features, (list, dict)) and len(features) == 0):
            logger.error("Empty feature vector provided to evaluate().")
            return EvaluationResponse(
                skill=normalized_skill,
                quality_score=0,
                mistakes=["Error: Empty feature vector provided."],
                confidence=0.0,
                timestamp=timestamp
            ).model_dump()

        try:
            skill_key, quality_model, mistake_model = self._get_model_pair(normalized_skill)

            # Quality Score Prediction
            quality_score = 75  # default baseline score
            if quality_model is not None:
                prepared_features_q = self._prepare_features(features, target_model=quality_model)
                raw_pred = quality_model.predict(prepared_features_q)[0]
                quality_score = int(np.clip(round(float(raw_pred)), 0, 100))

            # Mistake Detection & Confidence
            mistakes: List[str] = []
            confidence = 0.90  # default confidence

            if mistake_model is not None:
                prepared_features_m = self._prepare_features(features, target_model=mistake_model)
                mistake_pred = int(mistake_model.predict(prepared_features_m)[0])
                
                # Confidence estimation if model supports predict_proba
                if hasattr(mistake_model, "predict_proba"):
                    try:
                        probs = mistake_model.predict_proba(prepared_features_m)[0]
                        confidence = round(float(np.max(probs)), 2)
                    except Exception as prob_err:
                        logger.debug(f"Could not calculate predict_proba: {prob_err}")

                # Retrieve mistake description
                dict_key = skill_key if skill_key in self.MISTAKE_DICTIONARIES else "general"
                mistake_dict = self.MISTAKE_DICTIONARIES.get(dict_key, self.MISTAKE_DICTIONARIES["general"])
                mistake_desc = mistake_dict.get(mistake_pred, "Form discrepancy detected.")
                
                if mistake_pred != 0 or "Good Form" not in mistake_desc:
                    mistakes.append(mistake_desc)
                else:
                    mistakes.append("No major mistakes detected. Good form!")
            else:
                mistakes.append("General evaluation mode - form baseline applied.")

            response = EvaluationResponse(
                skill=normalized_skill,
                quality_score=quality_score,
                mistakes=mistakes,
                confidence=confidence,
                timestamp=timestamp
            )

            return response.model_dump()


        except Exception as e:
            logger.error(f"Error during motion evaluation for skill '{skill}': {e}", exc_info=True)
            return EvaluationResponse(
                skill=normalized_skill,
                quality_score=0,
                mistakes=[f"Evaluation error: {str(e)}"],
                confidence=0.0,
                timestamp=timestamp
            ).model_dump()
