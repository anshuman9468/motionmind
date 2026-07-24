"""
RecommendationAgent module for MotionMind backend.

Production-ready AI Agent utilizing Google Gemini to generate personalized
sports science training recommendations (drills, warmups, stretching, mobility exercises,
cooldowns, and difficulty progressions) tailored to an athlete's skill evaluation.

Note: Prompt templates are loaded dynamically from prompts/recommendation_prompt.txt.
"""

import os
import json
import logging
from typing import List, Dict, Any, Union, Optional
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("RecommendationAgent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# Attempt imports for Gemini API
HAS_GEMINI = False
GEMINI_VERSION = None

try:
    from google import genai
    HAS_GEMINI = True
    GEMINI_VERSION = "genai"
except ImportError:
    try:
        import google.generativeai as genai_legacy
        HAS_GEMINI = True
        GEMINI_VERSION = "legacy"
    except ImportError:
        HAS_GEMINI = False


# ---------------------------------------------------------------------------
# Pydantic Schemas for FastAPI Integration
# ---------------------------------------------------------------------------

class RecommendationInput(BaseModel):
    """Input payload schema for RecommendationAgent."""
    skill: str = Field(..., description="Target skill name (e.g. squat, boxing, basketball)")
    detected_mistakes: Union[List[str], str] = Field(..., description="List of detected form mistakes or summary text")
    quality_score: int = Field(..., ge=0, le=100, description="Overall movement quality score (0 to 100)")

    model_config = ConfigDict(extra="ignore")


class RecommendationOutput(BaseModel):
    """Exact JSON output schema required for RecommendationAgent."""
    drills: List[str] = Field(..., description="Targeted drills addressing detected mistakes & mobility limitations")
    warmup: List[str] = Field(..., description="Dynamic warmup and joint mobility exercises")
    cooldown: List[str] = Field(..., description="Static stretching and recovery protocols")
    next_level: str = Field(..., description="Difficulty progression and target metrics for next progression level")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# RecommendationAgent Implementation
# ---------------------------------------------------------------------------

class RecommendationAgent:
    """
    Production-ready Recommendation Agent powered by Google Gemini.
    
    Responsibilities:
      - Takes skill, detected mistakes, and quality score.
      - Recommends drills, dynamic warmups, mobility exercises, static cooldown stretches, and difficulty progressions.
      - Returns clean, structured JSON output matching exact schema:
        {
          "drills": [...],
          "warmup": [...],
          "cooldown": [...],
          "next_level": "..."
        }
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        prompt_path: Optional[str] = None,
        model_name: str = "gemini-2.5-flash"
    ):
        """
        Initialize RecommendationAgent.

        Args:
            api_key: Optional Gemini API Key. Defaults to GEMINI_API_KEY / GOOGLE_API_KEY env var.
            prompt_path: Optional custom path to recommendation_prompt.txt.
            model_name: Gemini model identifier.
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        self.model_name = model_name
        self.prompt_template = self._load_prompt_template(prompt_path)
        self.gemini_client = None

        if self.api_key and HAS_GEMINI:
            self._init_gemini_client()
        else:
            if not self.api_key:
                logger.warning("No Gemini API key found. Running in sports-science fallback mode.")
            elif not HAS_GEMINI:
                logger.warning("Google Gemini SDK not installed. Running in sports-science fallback mode.")

    def _load_prompt_template(self, prompt_path: Optional[str] = None) -> str:
        """
        Loads recommendation prompt template from prompts/recommendation_prompt.txt.
        """
        if prompt_path and os.path.exists(prompt_path):
            with open(prompt_path, "r", encoding="utf-8") as f:
                return f.read()

        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidate_paths = [
            os.path.join(base_dir, "prompts", "recommendation_prompt.txt"),
            os.path.join(os.getcwd(), "prompts", "recommendation_prompt.txt"),
            os.path.join(os.getcwd(), "backend", "prompts", "recommendation_prompt.txt")
        ]

        for path in candidate_paths:
            if os.path.exists(path):
                logger.info(f"Loaded recommendation prompt template from: {path}")
                with open(path, "r", encoding="utf-8") as f:
                    return f.read()

        logger.warning("recommendation_prompt.txt template file not found. Using embedded fallback prompt template.")
        return """
Skill: {skill}
Quality Score: {quality_score}
Mistakes: {mistakes}

Return valid JSON with keys: drills, warmup, cooldown, next_level.
"""

    def _init_gemini_client(self) -> None:
        """
        Initializes Google Gemini SDK client.
        """
        try:
            if GEMINI_VERSION == "genai":
                self.gemini_client = genai.Client(api_key=self.api_key)
                logger.info(f"Gemini client initialized with model '{self.model_name}' (genai SDK).")
            elif GEMINI_VERSION == "legacy":
                import google.generativeai as genai_legacy
                genai_legacy.configure(api_key=self.api_key)
                self.gemini_client = genai_legacy.GenerativeModel(self.model_name)
                logger.info(f"Gemini client initialized with model '{self.model_name}' (legacy SDK).")
        except Exception as e:
            logger.error(f"Failed to initialize Gemini client: {e}", exc_info=True)
            self.gemini_client = None

    def recommend(
        self,
        skill: str,
        detected_mistakes: Union[List[str], str],
        quality_score: int
    ) -> Dict[str, Any]:
        """
        Main method to generate workout drills, warmups, cooldowns, and progressions.

        Args:
            skill: Name of movement skill (e.g. 'squat', 'boxing', 'basketball')
            detected_mistakes: Detected form mistakes (list or string)
            quality_score: Movement quality score (0-100)

        Returns:
            Dict matching exact required JSON structure:
            {
              "drills": [...],
              "warmup": [...],
              "cooldown": [...],
              "next_level": "..."
            }
        """
        # Parse mistakes into string representation
        if isinstance(detected_mistakes, list):
            mistakes_str = ", ".join([str(m) for m in detected_mistakes if m]) if detected_mistakes else "No major mistakes detected."
        else:
            mistakes_str = str(detected_mistakes) if detected_mistakes else "No major mistakes detected."

        formatted_prompt = self.prompt_template.format(
            skill=skill.strip(),
            quality_score=quality_score,
            mistakes=mistakes_str
        )

        # 1. Attempt Gemini Generation
        if self.gemini_client is not None:
            try:
                response_text = self._call_gemini(formatted_prompt)
                parsed = self._parse_json_response(response_text)
                if parsed:
                    return parsed
            except Exception as e:
                logger.error(f"Gemini API call failed: {e}. Falling back to sports-science recommendation engine.", exc_info=True)

        # 2. Sports-Science Fallback Engine (Guarantees robust production output)
        return self._generate_sports_science_fallback(skill, mistakes_str, quality_score)

    def _call_gemini(self, prompt: str) -> str:
        """
        Invokes Gemini API and returns raw text response.
        """
        if GEMINI_VERSION == "genai" and self.gemini_client:
            response = self.gemini_client.models.generate_content(
                model=self.model_name,
                contents=prompt,
            )
            return response.text
        elif GEMINI_VERSION == "legacy" and self.gemini_client:
            response = self.gemini_client.generate_content(prompt)
            return response.text
        else:
            raise RuntimeError("Gemini client is not initialized.")

    def _parse_json_response(self, text: str) -> Optional[Dict[str, Any]]:
        """
        Extracts and validates JSON response from Gemini model output.
        """
        try:
            clean_text = text.strip()
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            elif clean_text.startswith("```"):
                clean_text = clean_text[3:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]
            clean_text = clean_text.strip()

            data = json.loads(clean_text)
            
            required_keys = {"drills", "warmup", "cooldown", "next_level"}
            if required_keys.issubset(data.keys()):
                return RecommendationOutput(
                    drills=list(data["drills"]),
                    warmup=list(data["warmup"]),
                    cooldown=list(data["cooldown"]),
                    next_level=str(data["next_level"])
                ).model_dump()
        except Exception as err:
            logger.warning(f"Could not parse Gemini JSON response: {err}. Raw text: {text[:100]}...")
        return None

    def _generate_sports_science_fallback(
        self,
        skill: str,
        mistakes: str,
        quality_score: int
    ) -> Dict[str, Any]:
        """
        Rule-based sports science fallback engine generating expert drills, warmups, mobility,
        and next-level progressions when Gemini API key is missing or offline.
        """
        normalized_skill = skill.lower().strip()

        drills = []
        warmup = []
        cooldown = []
        next_level = ""

        if "squat" in normalized_skill:
            warmup = [
                "5 min Light Ergometer Cycling or Bodyweight Glute Bridges (2 sets of 15 reps)",
                "Ankle Dorsiflexion Knee-to-Wall Mobilization (2 sets of 10 reps per side)",
                "Bodyweight Deep Squat Hold with Thoracic Rotations (30 seconds hold)"
            ]
            
            if "shallow" in mistakes.lower():
                drills = [
                    "Heels-Elevated Goblet Squat: 3 sets x 10 reps with a 3-second eccentric tempo to increase depth range of motion.",
                    "Box Squat to Parallel: 4 sets x 8 reps focusing on full hip hinge depth contact before ascending.",
                    "Weighted Ankle Mobilization Stretch: 3 sets x 45 seconds using a kettlebell over the knee."
                ]
            elif "back" in mistakes.lower() or "lean" in mistakes.lower():
                drills = [
                    "Wall-Facing Bodyweight Squat: 3 sets x 8 reps to force an upright torso alignment.",
                    "Front Squat with Kettlebell / Dumbbell: 4 sets x 8 reps strengthening upper back and anterior core tension.",
                    "Dead Bug with Overhead Reach: 3 sets x 12 reps for anti-extension core stability."
                ]
            else:
                drills = [
                    "Tempo Pause Squats: 4 sets x 6 reps with a 2-second pause in the bottom position.",
                    "Banded Miniband Squats: 3 sets x 12 reps to activate gluteus medius and prevent knee caving."
                ]

            cooldown = [
                "Kneeling Hip Flexor Stretch (60 seconds per leg)",
                "Standing Quadriceps & Hamstring Static Stretch (45 seconds per side)",
                "Foam Rolling IT Band and Calf Complex (90 seconds per muscle group)"
            ]

            if quality_score >= 85:
                next_level = "Progression Stage 3: Transition to Barbell Back/Front Squats at 75% 1RM while preserving deep hip depth."
            elif quality_score >= 65:
                next_level = "Progression Stage 2: Master Goblet Squats with bodyweight load before advancing to weighted barbell resistance."
            else:
                next_level = "Progression Stage 1: Focus on bodyweight squat depth and core stability to achieve a consistent >80 quality score."

        elif "box" in normalized_skill or "jab" in normalized_skill:
            warmup = [
                "Shadowboxing with loose arms & footwork drills (3 minutes)",
                "Arm Circles & Shoulder Dislocates with PVC Pipe (2 sets of 15 reps)",
                "Band Pull-Aparts for Scapular Activation (3 sets of 20 reps)"
            ]

            if "elbow" in mistakes.lower():
                drills = [
                    "Wall-Guided Jab Drill: 4 rounds x 1 minute punching parallel to a wall to eliminate elbow flare.",
                    "Resistance Band Straight Punching: 3 sets x 20 reps emphasizing linear kinetic drive."
                ]
            else:
                drills = [
                    "Heavy Bag Combination Rounds: 4 rounds x 2 minutes with focus on hip pivot and chin protection.",
                    "Double-End Bag Rhythm Drill: 3 rounds x 3 minutes for kinetic timing."
                ]

            cooldown = [
                "Cross-Body Shoulder & Triceps Stretch (60 seconds per arm)",
                "Doorway Pectoral Stretch (45 seconds hold)",
                "Upper Back & Latissimus Dorsi Foam Rolling (2 minutes)"
            ]

            next_level = f"Next Level Goal: Progress to 4-punch combination drills while maintaining form score > 85."

        elif "basket" in normalized_skill or "shoot" in normalized_skill:
            warmup = [
                "Dynamic High Knees & Butt Kicks (2 sets of 20 meters)",
                "Wrist & Forearm Flexor/Extensor Dynamic Stretch (2 sets of 15 reps)",
                "Form Shooting from 3 feet (15 made shots)"
            ]

            drills = [
                "One-Hand Form Shooting: 5 sets x 10 makes at 5 feet from hoop focusing on elbow alignment.",
                "Set-Point Pause Jump Shots: 3 sets x 10 makes pausing 1 second at set-point eyebrow height."
            ]

            cooldown = [
                "Seated Calf & Achille Tendon Stretch (60 seconds per leg)",
                "Triceps & Overhead Lat Stretch (45 seconds per side)"
            ]

            next_level = "Next Level Goal: Advance to off-dribble pull-up jump shots with release height score > 85."

        else:
            warmup = [
                "Full-Body Dynamic Joint Mobility Warmup (5 minutes)",
                "Light Aerobic Jogging & Core Activation (3 minutes)"
            ]
            drills = [
                "Movement Pattern Tempo Drill: 3 sets x 10 reps at 50% speed focusing on strict form execution.",
                "Targeted Isometric Hold Drill: 3 sets x 30 seconds at key joint angle position."
            ]
            cooldown = [
                "Full Body Static Stretch & Decompression (5 minutes)",
                "Deep Diaphragmatic Breathing Recovery (2 minutes)"
            ]
            next_level = f"Next Level Goal: Build movement consistency to elevate quality score above 85."

        response = RecommendationOutput(
            drills=drills,
            warmup=warmup,
            cooldown=cooldown,
            next_level=next_level
        )

        return response.model_dump()
