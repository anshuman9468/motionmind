"""
CoachAgent module for MotionMind backend.

Production-ready AI Agent utilizing Google Gemini to generate sports-science based
biomechanical coaching feedback, explanations, physical corrections, and encouragement
from evaluation scores and detected motion mistakes.

Note: Prompt templates are loaded dynamically from prompts/coach_prompt.txt.
"""

import os
import json
import logging
from typing import List, Dict, Any, Union, Optional
from pydantic import BaseModel, Field, ConfigDict

# Configure logger
logger = logging.getLogger("CoachAgent")
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

class CoachAgentInput(BaseModel):
    """Input payload schema for CoachAgent feedback generation."""
    skill: str = Field(..., description="Target skill (e.g. squat, boxing, basketball)")
    quality_score: int = Field(..., ge=0, le=100, description="Overall movement quality score (0-100)")
    mistakes: Union[List[str], str] = Field(..., description="Detected motion mistakes")
    confidence: float = Field(default=0.90, ge=0.0, le=1.0, description="Model prediction confidence score")

    model_config = ConfigDict(extra="ignore")


class CoachFeedbackResponse(BaseModel):
    """Exact JSON output schema required for CoachAgent."""
    feedback: str = Field(..., description="Overall analysis of the athlete's movement quality")
    reason: str = Field(..., description="Sports science breakdown explaining WHY the mistake occurred")
    correction: str = Field(..., description="Immediate step-by-step physical correction drill")
    encouragement: str = Field(..., description="Empowering motivational statement")

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# CoachAgent Implementation
# ---------------------------------------------------------------------------

class CoachAgent:
    """
    Production-ready AI Coach Agent powered by Google Gemini.
    
    Translates raw scores and detected form mistakes into deep sports-science guidance,
    biomechanical cause analysis, immediate corrective drills, and performance encouragement.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        prompt_path: Optional[str] = None,
        model_name: str = "gemini-2.5-flash"
    ):
        """
        Initialize CoachAgent.

        Args:
            api_key: Optional Gemini API Key. Defaults to GEMINI_API_KEY or GOOGLE_API_KEY env var.
            prompt_path: Optional absolute or relative path to coach_prompt.txt template.
            model_name: Gemini model name (default: 'gemini-2.5-flash').
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        self.model_name = model_name
        self.prompt_template = self._load_prompt_template(prompt_path)
        self.gemini_client = None

        if self.api_key and HAS_GEMINI:
            self._init_gemini_client()
        else:
            if not self.api_key:
                logger.warning("No Gemini API key found (GEMINI_API_KEY / GOOGLE_API_KEY). Running in sports-science fallback mode.")
            elif not HAS_GEMINI:
                logger.warning("Google Gemini library not installed. Running in sports-science fallback mode.")

    def _load_prompt_template(self, prompt_path: Optional[str] = None) -> str:
        """
        Loads prompt template from prompts/coach_prompt.txt.
        """
        if prompt_path and os.path.exists(prompt_path):
            with open(prompt_path, "r", encoding="utf-8") as f:
                return f.read()

        # Search default locations
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidate_paths = [
            os.path.join(base_dir, "prompts", "coach_prompt.txt"),
            os.path.join(os.getcwd(), "prompts", "coach_prompt.txt"),
            os.path.join(os.getcwd(), "backend", "prompts", "coach_prompt.txt")
        ]

        for path in candidate_paths:
            if os.path.exists(path):
                logger.info(f"Loaded coach prompt template from: {path}")
                with open(path, "r", encoding="utf-8") as f:
                    return f.read()

        logger.warning("coach_prompt.txt template file not found. Using embedded fallback prompt template.")
        return """
You are an elite sports scientist and biomechanics coach for MotionMind.
Skill: {skill}
Score: {quality_score}/100
Confidence: {confidence}
Mistakes: {mistakes}

Return JSON with: feedback, reason, correction, encouragement.
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

    def analyze(
        self,
        skill: str,
        quality_score: int,
        mistakes: Union[List[str], str],
        confidence: float = 0.90
    ) -> Dict[str, str]:
        """
        Main method to generate sports science coaching guidance.

        Args:
            skill: Target skill name (e.g. 'squat', 'boxing', 'basketball')
            quality_score: Movement quality score (0-100)
            mistakes: Detected form mistakes (list of strings or formatted string)
            confidence: Model confidence score (0.0 to 1.0)

        Returns:
            Dict matching exact schema:
            {
                "feedback": "...",
                "reason": "...",
                "correction": "...",
                "encouragement": "..."
            }
        """
        # Format mistakes list into readable text if needed
        if isinstance(mistakes, list):
            mistakes_str = ", ".join([str(m) for m in mistakes if m]) if mistakes else "No major mistakes detected."
        else:
            mistakes_str = str(mistakes) if mistakes else "No major mistakes detected."

        # Dynamically insert variables into prompt template
        formatted_prompt = self.prompt_template.format(
            skill=skill.strip(),
            quality_score=quality_score,
            confidence=round(confidence, 2),
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
                logger.error(f"Gemini API call failed: {e}. Falling back to sports-science knowledge engine.", exc_info=True)

        # 2. Sports-Science Fallback Engine (Guarantees robust production response)
        return self._generate_sports_science_fallback(skill, quality_score, mistakes_str, confidence)

    def _call_gemini(self, prompt: str) -> str:
        """
        Invokes Gemini API and returns raw text response.
        """
        if GEMINI_VERSION == "genai" and self.gemini_client:
            # Using google.genai Client SDK
            response = self.gemini_client.models.generate_content(
                model=self.model_name,
                contents=prompt,
            )
            return response.text
        elif GEMINI_VERSION == "legacy" and self.gemini_client:
            # Using legacy google.generativeai SDK
            response = self.gemini_client.generate_content(prompt)
            return response.text
        else:
            raise RuntimeError("Gemini client is not initialized.")

    def _parse_json_response(self, text: str) -> Optional[Dict[str, str]]:
        """
        Extracts and parses JSON object from model string output.
        """
        try:
            clean_text = text.strip()
            # Strip markdown code fencing if present
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            elif clean_text.startswith("```"):
                clean_text = clean_text[3:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]
            clean_text = clean_text.strip()

            data = json.loads(clean_text)
            
            # Validate output matches required fields
            required_keys = {"feedback", "reason", "correction", "encouragement"}
            if required_keys.issubset(data.keys()):
                return CoachFeedbackResponse(
                    feedback=str(data["feedback"]),
                    reason=str(data["reason"]),
                    correction=str(data["correction"]),
                    encouragement=str(data["encouragement"])
                ).model_dump()
        except Exception as err:
            logger.warning(f"Could not parse Gemini JSON output: {err}. Raw text: {text[:100]}...")
        return None

    def _generate_sports_science_fallback(
        self,
        skill: str,
        quality_score: int,
        mistakes: str,
        confidence: float
    ) -> Dict[str, str]:
        """
        High-performance sports science fallback engine when Gemini API key is missing or offline.
        Never returns raw score alone; provides deep biomechanical reasoning and immediate corrections.
        """
        normalized_skill = skill.lower().strip()
        
        # Rule-based sports science breakdown dictionary
        if "squat" in normalized_skill:
            if "shallow" in mistakes.lower():
                reason = "Shallow squat depth typically stems from tight ankle dorsiflexion or poor hip capsule mobility, causing premature stopping before 90-degree knee flexion."
                correction = "Elevate your heels slightly on a 5-degree wedge and focus on pushing your hips back and down while keeping your chest upright."
            elif "back" in mistakes.lower() or "lean" in mistakes.lower():
                reason = "Excessive forward torso lean indicates weak thoracic spine extensors and under-engaged anterior core muscles failing to stabilize the spine under axial load."
                correction = "Perform Goblet Squats with a weight held at chest level to act as a counter-balance, keeping your gaze forward and latissimus dorsi engaged."
            else:
                reason = "Minor knee valgicity or micro-instability observed during the transition phase between eccentric loading and concentric drive."
                correction = "Drive your knees outward over your 2nd and 3rd toes as you ascend from the bottom of the movement."

        elif "box" in normalized_skill or "jab" in normalized_skill:
            if "elbow" in mistakes.lower():
                reason = "Elbow flaring outward telegraphs the punch early and reduces force transfer by breaking the linear kinetic chain alignment from shoulder to knuckle."
                correction = "Tuck your elbows tightly against your ribs. Initiate the extension by rotating your forearm smoothly without letting the elbow drift laterally."
            elif "guard" in mistakes.lower():
                reason = "Dropping the non-striking hand during punch extension exposes the jaw to counter-strikes, caused by lack of motor habit and shoulder fatigue."
                correction = "Keep your off-hand glued to your cheekbone, using your rear thumb touching your jawline as an anchor cue."
            else:
                reason = "Kinetic chain rotation breakdown between lower body pivot and upper body extension."
                correction = "Pivot aggressively on the ball of your lead foot and snap the wrist over at full arm extension."

        elif "basket" in normalized_skill or "shoot" in normalized_skill:
            if "elbow" in mistakes.lower():
                reason = "A low elbow set point reduces the catapult angle, flattening the arc and lowering the high-margin vertical entry percentage into the hoop."
                correction = "Bring your elbow directly under the ball at eyebrow height before initiating the upward jump release."
            else:
                reason = "Lack of sequential energy transfer from knee bend to wrist snap resulting in variable trajectory."
                correction = "Sync your leg extension with your arm lift in one fluid motion, holding your follow-through wrist snap until the ball lands."

        else:
            reason = "Form discrepancy observed in kinetic chain alignment and movement sequence control during motor execution."
            correction = "Slow down movement tempo to 3 seconds per phase, focusing on core engagement and joint stability."

        feedback = (
            f"Your {skill.title()} movement scored {quality_score}/100 with {round(confidence * 100)}% model confidence. "
            f"Key focus area detected: {mistakes}."
        )

        encouragement = (
            "Great effort! Biomechanical consistency is built through intentional repetition. "
            "Focus on the corrective drill on your next set!"
        )

        response = CoachFeedbackResponse(
            feedback=feedback,
            reason=reason,
            correction=correction,
            encouragement=encouragement
        )

        return response.model_dump()
