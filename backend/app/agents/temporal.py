"""Timestamped, confidence-aware temporal analysis for squat practice.

This module deliberately operates on measured joint angles rather than raw
pixel spread.  Missing/uncertain samples pause the state machine and never
create a synthetic velocity, angle, or repetition.
"""

from __future__ import annotations

import math
from collections import OrderedDict, deque
from dataclasses import dataclass
from typing import Deque, Dict, List, Optional, Tuple

from fastapi import APIRouter

from app.agents.exercise_profiles import get_exercise_profile
from app.schemas import (
    EvaluationStatus,
    LandmarkPoint,
    SquatPhase,
    TemporalAnalysisResult,
    TemporalPoseInput,
)


router = APIRouter(prefix="/temporal", tags=["Temporal movement"])

REQUIRED_SQUAT_LANDMARKS = frozenset((11, 12, 23, 24, 25, 26, 27, 28))


@dataclass(frozen=True)
class TemporalFrame:
    """A single frame after confidence gating and geometric measurement."""

    timestamp_us: int
    session_id: str
    skill_id: str
    status: EvaluationStatus
    landmarks: Tuple[LandmarkPoint, ...] = ()
    subject_view: str = "unknown"
    measurement_confidence: Optional[float] = None
    left_knee_angle: Optional[float] = None
    right_knee_angle: Optional[float] = None
    left_hip_angle: Optional[float] = None
    right_hip_angle: Optional[float] = None
    torso_inclination: Optional[float] = None
    bilateral_knee_symmetry: Optional[float] = None


@dataclass(frozen=True)
class TemporalFrameResult:
    status: EvaluationStatus
    phase: SquatPhase
    repetition_count: int
    completed_rep: bool
    smoothed_knee_angle: Optional[float]
    movement_direction: Optional[str]
    movement_speed_degrees_per_second: Optional[float]
    torso_inclination: Optional[float]
    left_hip_angle: Optional[float]
    right_hip_angle: Optional[float]
    bilateral_knee_symmetry: Optional[float]
    feedback_eligible: bool
    feedback: List[str]
    verified_findings: List[str]
    reason: Optional[str]
    buffer_size: int
    landmarks_retained: int


@dataclass
class GenericTemporalTracker:
    """Bounded angle-based tracker for non-squat exercise profiles.

    It intentionally consumes only measurements already produced by the
    confidence-gated biomechanics service. The thresholds are starting
    heuristics and the result is never an expert-quality or outcome score.
    """

    profile: object
    last_timestamp_us: Optional[int] = None
    phase_index: int = 0
    repetitions: int = 0
    previous_signal: Optional[float] = None
    buffer_size: int = 0

    def process(self, frame: TemporalPoseInput) -> tuple[EvaluationStatus, str, bool, list[str], Optional[float], Optional[str], Optional[str]]:
        if self.last_timestamp_us is not None and frame.timestamp_us <= self.last_timestamp_us:
            return EvaluationStatus.INSUFFICIENT_DATA, self.phase_label, False, [], None, None, "Duplicate or out-of-order frame timestamp ignored."
        self.last_timestamp_us = frame.timestamp_us
        self.buffer_size = min(self.buffer_size + 1, 120)
        if frame.status != EvaluationStatus.VALID or frame.measurement_confidence is None or frame.measurement_confidence < 0.60:
            self.phase_index = 0
            self.previous_signal = None
            return EvaluationStatus.LOW_CONFIDENCE if frame.status == EvaluationStatus.VALID else frame.status, self.phase_label, False, [], None, None, "Required measurements are unavailable; evaluation paused."
        values = [frame.left_elbow_angle, frame.right_elbow_angle]
        values = [value for value in values if value is not None and math.isfinite(value)]
        if not values:
            self.phase_index = 0
            self.previous_signal = None
            return EvaluationStatus.INSUFFICIENT_DATA, self.phase_label, False, [], None, None, "The selected exercise requires valid arm measurements."
        signal = sum(values) / len(values)
        delta = 0.0 if self.previous_signal is None else signal - self.previous_signal
        self.previous_signal = signal
        direction = "STATIONARY" if abs(delta) < 1.0 else ("DESCENDING" if delta < 0 else "ASCENDING")
        completed = False
        # The common profiles use a start/loaded/return sequence. This is a
        # phase signal only; detailed sport-specific validation remains local.
        low, high = 115.0, 155.0
        if self.phase_index == 0 and signal >= high:
            self.phase_index = 1
        elif self.phase_index == 1 and signal <= low:
            self.phase_index = 2
        elif self.phase_index == 2 and signal >= high and delta > 0:
            self.phase_index = 0
            self.repetitions += 1
            completed = True
        feedback = [self.phase_label] if not completed else ["Movement cycle completed."]
        return EvaluationStatus.VALID, self.phase_label, completed, feedback, signal, direction, None

    @property
    def phase_label(self) -> str:
        phases = getattr(self.profile, "phases", ()) or ("READY", "MOVING", "COMPLETED_REP")
        return phases[min(self.phase_index, len(phases) - 1)]

    def reset(self) -> None:
        self.last_timestamp_us = None
        self.phase_index = 0
        self.repetitions = 0
        self.previous_signal = None
        self.buffer_size = 0


class SquatTemporalTracker:
    """Small deterministic squat state machine with bounded memory.

    Thresholds are initial heuristics and must be calibrated against labelled
    recordings before being presented as scientifically validated.  A side
    view is required because the Phase 3 measurements use sagittal-plane knee
    flexion and torso inclination.
    """

    def __init__(
        self,
        *,
        max_buffer_size: int = 120,
        smoothing_window: int = 3,
        min_confidence: float = 0.60,
        standing_exit_angle: float = 150.0,
        bottom_angle: float = 120.0,
        bottom_exit_angle: float = 130.0,
        standing_return_angle: float = 160.0,
        min_direction_speed: float = 1.0,
        tracking_loss_grace_us: int = 1_000_000,
        direction_deadband_degrees: float = 2.0,
        min_standing_samples: int = 2,
        min_bottom_samples: int = 1,
        min_bottom_dwell_us: int = 40_000,
        min_rep_duration_us: int = 120_000,
        max_plausible_angular_speed: float = 1_200.0,
    ) -> None:
        if max_buffer_size < 1:
            raise ValueError("max_buffer_size must be positive")
        if smoothing_window < 1 or smoothing_window % 2 == 0:
            raise ValueError("smoothing_window must be a positive odd number")
        self.max_buffer_size = max_buffer_size
        self.smoothing_window = smoothing_window
        self.min_confidence = min_confidence
        self.standing_exit_angle = standing_exit_angle
        self.bottom_angle = bottom_angle
        self.bottom_exit_angle = bottom_exit_angle
        self.standing_return_angle = standing_return_angle
        self.min_direction_speed = min_direction_speed
        self.tracking_loss_grace_us = tracking_loss_grace_us
        self.direction_deadband_degrees = direction_deadband_degrees
        self.min_standing_samples = min_standing_samples
        self.min_bottom_samples = min_bottom_samples
        self.min_bottom_dwell_us = min_bottom_dwell_us
        self.min_rep_duration_us = min_rep_duration_us
        self.max_plausible_angular_speed = max_plausible_angular_speed
        self._frames: Deque[TemporalFrame] = deque(maxlen=max_buffer_size)
        self._valid_angles: Deque[float] = deque(maxlen=smoothing_window)
        self._valid_hip_angles: Deque[float] = deque(maxlen=smoothing_window)
        self._phase = SquatPhase.STANDING
        self._repetitions = 0
        self._last_timestamp_us: Optional[int] = None
        self._last_valid_timestamp_us: Optional[int] = None
        self._last_smoothed_angle: Optional[float] = None
        self._last_smoothed_hip_angle: Optional[float] = None
        self._loss_started_us: Optional[int] = None
        self._bottom_started_us: Optional[int] = None
        self._last_feedback: List[str] = []
        self._incomplete_cycle = False
        self._incomplete_feedback_emitted = False
        self._standing_samples = 0
        self._bottom_samples = 0
        self._cycle_started_us: Optional[int] = None

    @property
    def phase(self) -> SquatPhase:
        return self._phase

    @property
    def repetition_count(self) -> int:
        return self._repetitions

    @property
    def buffer_size(self) -> int:
        return len(self._frames)

    def reset(self, *, keep_repetition_count: bool = True) -> None:
        """Reset filters and phase after a new session or unrecoverable loss."""

        repetitions = self._repetitions if keep_repetition_count else 0
        self._frames.clear()
        self._valid_angles.clear()
        self._valid_hip_angles.clear()
        self._phase = SquatPhase.STANDING
        self._repetitions = repetitions
        self._last_timestamp_us = None
        self._last_valid_timestamp_us = None
        self._last_smoothed_angle = None
        self._last_smoothed_hip_angle = None
        self._loss_started_us = None
        self._bottom_started_us = None
        self._last_feedback = []
        self._incomplete_cycle = False
        self._incomplete_feedback_emitted = False
        self._standing_samples = 0
        self._bottom_samples = 0
        self._cycle_started_us = None

    def process(self, frame: TemporalFrame) -> TemporalFrameResult:
        """Consume one sample and return the current temporal assessment."""

        if self._last_timestamp_us is not None and frame.timestamp_us <= self._last_timestamp_us:
            return self._result(
                status=EvaluationStatus.INSUFFICIENT_DATA,
                completed_rep=False,
                reason="Duplicate or out-of-order frame timestamp ignored.",
                feedback=[],
            )
        self._last_timestamp_us = frame.timestamp_us
        self._frames.append(frame)

        profile = get_exercise_profile(frame.skill_id)
        if profile is None or profile.skill_id != "squat":
            # Do not allow a partial squat from a previous context to be
            # completed after an unsupported exercise is selected.
            self._reset_phase_only()
            return self._result(
                status=EvaluationStatus.INSUFFICIENT_DATA,
                completed_rep=False,
                reason="Temporal squat tracking was requested for a non-squat exercise.",
                feedback=[],
            )
        if frame.subject_view.lower() != "side":
            # A view change invalidates the sagittal-plane sequence. The
            # repetition total is preserved, but the partial phase is not.
            self._reset_phase_only()
            return self._result(
                status=EvaluationStatus.UNSUPPORTED_VIEW,
                completed_rep=False,
                reason="Squat temporal tracking requires a side camera view.",
                feedback=[],
            )

        if not self._is_reliable(frame):
            return self._handle_tracking_loss(frame)

        # A camera stream can stop delivering callbacks entirely.  Treat a
        # large timestamp gap like extended tracking loss even when no explicit
        # invalid sample arrived between two valid frames.
        if (
            self._last_valid_timestamp_us is not None
            and frame.timestamp_us - self._last_valid_timestamp_us > self.tracking_loss_grace_us
        ):
            self._reset_phase_only()

        # A valid frame can recover from a short interruption.  Extended loss
        # resets the phase before this frame is considered, so a partial rep
        # cannot be completed using a fabricated bridge across the gap.
        if self._loss_started_us is not None:
            loss_duration = frame.timestamp_us - self._loss_started_us
            if loss_duration > self.tracking_loss_grace_us:
                self._reset_phase_only()
            self._loss_started_us = None

        left = frame.left_knee_angle
        right = frame.right_knee_angle
        assert left is not None and right is not None
        measured_angle = (left + right) / 2.0
        self._valid_angles.append(measured_angle)
        smoothed_angle = self._median(self._valid_angles)
        left_hip = frame.left_hip_angle
        right_hip = frame.right_hip_angle
        assert left_hip is not None and right_hip is not None
        measured_hip_angle = (left_hip + right_hip) / 2.0
        self._valid_hip_angles.append(measured_hip_angle)
        smoothed_hip_angle = self._median(self._valid_hip_angles)

        speed: Optional[float] = None
        direction: Optional[str] = None
        hip_speed: Optional[float] = None
        hip_direction: Optional[str] = None
        if self._last_smoothed_angle is not None and self._last_valid_timestamp_us is not None:
            delta_seconds = (frame.timestamp_us - self._last_valid_timestamp_us) / 1_000_000.0
            if delta_seconds > 0 and math.isfinite(delta_seconds):
                delta_angle = smoothed_angle - self._last_smoothed_angle
                speed = abs(delta_angle / delta_seconds)
                direction = self._direction(delta_angle)
                if self._last_smoothed_hip_angle is not None:
                    hip_delta = smoothed_hip_angle - self._last_smoothed_hip_angle
                    hip_speed = abs(hip_delta / delta_seconds)
                    hip_direction = self._direction(hip_delta)
        self._last_valid_timestamp_us = frame.timestamp_us
        self._last_smoothed_angle = smoothed_angle
        self._last_smoothed_hip_angle = smoothed_hip_angle

        # Knee flexion is the primary squat signal. Hip-angle direction is a
        # corroborating signal: a strong contradiction pauses transitions so a
        # single noisy joint cannot manufacture a phase change.
        movement_supported = (
            direction is None
            or hip_direction in (None, "STATIONARY", direction)
            or (hip_speed is not None and hip_speed < self.min_direction_speed)
        )

        speed_supported = speed is None or speed <= self.max_plausible_angular_speed
        completed_rep = self._advance_state(
            smoothed_angle=smoothed_angle,
            direction=direction,
            speed=speed,
            movement_supported=movement_supported and speed_supported,
            timestamp_us=frame.timestamp_us,
        )
        symmetry = self._symmetry(frame)
        verified_findings = self._verified_findings(frame, symmetry)
        feedback = self._feedback(frame, smoothed_angle, completed_rep, symmetry)
        return self._result(
            status=EvaluationStatus.VALID,
            completed_rep=completed_rep,
            smoothed_knee_angle=smoothed_angle,
            movement_direction=direction,
            movement_speed_degrees_per_second=speed,
            torso_inclination=frame.torso_inclination,
            left_hip_angle=frame.left_hip_angle,
            right_hip_angle=frame.right_hip_angle,
            bilateral_knee_symmetry=symmetry,
            feedback=feedback,
            verified_findings=verified_findings,
        )

    def _is_reliable(self, frame: TemporalFrame) -> bool:
        if frame.status != EvaluationStatus.VALID:
            return False
        if frame.measurement_confidence is None or frame.measurement_confidence < self.min_confidence:
            return False
        landmarks_by_index = self._landmarks_by_index(frame)
        if not REQUIRED_SQUAT_LANDMARKS.issubset(landmarks_by_index):
            return False
        for index in REQUIRED_SQUAT_LANDMARKS:
            landmark = landmarks_by_index[index]
            if not all(math.isfinite(value) for value in (landmark.x, landmark.y, landmark.z)):
                return False
            if (
                landmark.visibility is None
                or not math.isfinite(landmark.visibility)
                or landmark.visibility < self.min_confidence
            ):
                return False
            if landmark.presence is not None:
                if not math.isfinite(landmark.presence) or landmark.presence < self.min_confidence:
                    return False
        values = (
            frame.left_knee_angle,
            frame.right_knee_angle,
            frame.left_hip_angle,
            frame.right_hip_angle,
            frame.torso_inclination,
        )
        return all(value is not None and math.isfinite(value) for value in values)

    @staticmethod
    def _landmarks_by_index(frame: TemporalFrame) -> Dict[int, LandmarkPoint]:
        indexed = [landmark for landmark in frame.landmarks if landmark.index is not None]
        indices = [int(landmark.index) for landmark in indexed]
        if len(indices) != len(set(indices)):
            # Duplicate canonical indices make anatomical identity ambiguous;
            # fail closed instead of letting the last value silently win.
            return {}
        return {int(landmark.index): landmark for landmark in indexed}

    def _has_low_confidence_landmark(self, frame: TemporalFrame) -> bool:
        landmarks = self._landmarks_by_index(frame)
        if not REQUIRED_SQUAT_LANDMARKS.issubset(landmarks):
            return False
        for index in REQUIRED_SQUAT_LANDMARKS:
            landmark = landmarks[index]
            if landmark.visibility is None or not math.isfinite(landmark.visibility):
                continue
            if landmark.visibility < self.min_confidence:
                return True
            if (
                landmark.presence is not None
                and math.isfinite(landmark.presence)
                and landmark.presence < self.min_confidence
            ):
                return True
        return False

    def _handle_tracking_loss(self, frame: TemporalFrame) -> TemporalFrameResult:
        if (
            self._last_valid_timestamp_us is not None
            and frame.timestamp_us - self._last_valid_timestamp_us > self.tracking_loss_grace_us
        ):
            self._reset_phase_only()
        if self._loss_started_us is None:
            self._loss_started_us = frame.timestamp_us
        elif frame.timestamp_us - self._loss_started_us > self.tracking_loss_grace_us:
            self._reset_phase_only()
            self._loss_started_us = frame.timestamp_us
        status = frame.status
        if status == EvaluationStatus.VALID:
            status = (
                EvaluationStatus.LOW_CONFIDENCE
                if (
                    frame.measurement_confidence is not None
                    and frame.measurement_confidence < self.min_confidence
                )
                or self._has_low_confidence_landmark(frame)
                else EvaluationStatus.INSUFFICIENT_DATA
            )
        return self._result(
            status=status,
            completed_rep=False,
            reason="Required squat measurements are unavailable; evaluation paused.",
            feedback=["Step back into a side view and keep both hips and knees visible."],
        )

    @staticmethod
    def _symmetry(frame: TemporalFrame) -> Optional[float]:
        if frame.left_knee_angle is None or frame.right_knee_angle is None:
            return None
        value = 1.0 - abs(frame.left_knee_angle - frame.right_knee_angle) / 180.0
        return max(0.0, min(1.0, value)) if math.isfinite(value) else None

    def _reset_phase_only(self) -> None:
        self._phase = SquatPhase.STANDING
        self._valid_angles.clear()
        self._valid_hip_angles.clear()
        self._last_smoothed_angle = None
        self._last_smoothed_hip_angle = None
        self._last_valid_timestamp_us = None
        self._bottom_started_us = None
        self._incomplete_cycle = False
        self._incomplete_feedback_emitted = False
        self._standing_samples = 0
        self._bottom_samples = 0
        self._cycle_started_us = None
        self._last_feedback = []

    def _advance_state(
        self,
        *,
        smoothed_angle: float,
        direction: Optional[str],
        speed: Optional[float],
        movement_supported: bool,
        timestamp_us: int,
    ) -> bool:
        moving_down = (
            movement_supported
            and direction == "DESCENDING"
            and (speed or 0.0) >= self.min_direction_speed
        )
        moving_up = (
            movement_supported
            and direction == "ASCENDING"
            and (speed or 0.0) >= self.min_direction_speed
        )

        if self._phase == SquatPhase.COMPLETED_REP:
            # Completion is emitted for one frame.  A later standing frame is
            # a stable reset and cannot increment the counter again.
            if smoothed_angle >= self.standing_return_angle:
                self._phase = SquatPhase.STANDING
                # The completed transition already proved a stable top
                # position; do not require artificial extra standing frames
                # before the next repetition can begin.
                self._standing_samples = self.min_standing_samples
            return False

        if self._phase == SquatPhase.STANDING:
            standing_confirmed = self._standing_samples >= self.min_standing_samples
            if (
                smoothed_angle <= self.standing_exit_angle
                and moving_down
                and standing_confirmed
            ):
                self._phase = SquatPhase.DESCENDING
                self._cycle_started_us = timestamp_us
                self._incomplete_cycle = False
                self._incomplete_feedback_emitted = False
            if smoothed_angle >= self.standing_return_angle:
                self._standing_samples += 1
            elif smoothed_angle < self.standing_return_angle - self.direction_deadband_degrees:
                self._standing_samples = 0
            return False

        if self._phase == SquatPhase.DESCENDING:
            if (
                smoothed_angle <= self.bottom_angle
                and movement_supported
                and (moving_down or direction == "STATIONARY")
            ):
                self._bottom_samples += 1
                if self._bottom_samples >= self.min_bottom_samples:
                    self._phase = SquatPhase.BOTTOM
                    self._bottom_started_us = timestamp_us
            elif smoothed_angle > self.bottom_angle + self.direction_deadband_degrees:
                self._bottom_samples = 0
            if smoothed_angle >= self.standing_return_angle and not moving_down:
                # Partial squat: it never reached the configured depth.
                self._phase = SquatPhase.STANDING
                self._incomplete_cycle = True
                self._incomplete_feedback_emitted = False
                self._cycle_started_us = None
            return False

        if self._phase == SquatPhase.BOTTOM:
            bottom_dwell_satisfied = (
                self._bottom_started_us is None
                or timestamp_us - self._bottom_started_us >= self.min_bottom_dwell_us
            )
            if smoothed_angle >= self.bottom_exit_angle and moving_up and bottom_dwell_satisfied:
                self._phase = SquatPhase.ASCENDING
            return False

        if self._phase == SquatPhase.ASCENDING:
            rep_duration_satisfied = (
                self._cycle_started_us is None
                or timestamp_us - self._cycle_started_us >= self.min_rep_duration_us
            )
            if (
                smoothed_angle >= self.standing_return_angle
                and movement_supported
                and (moving_up or direction == "STATIONARY")
                and rep_duration_satisfied
            ):
                self._phase = SquatPhase.COMPLETED_REP
                self._repetitions += 1
                return True
            if smoothed_angle <= self.bottom_angle and not moving_up:
                self._phase = SquatPhase.BOTTOM
            return False

        return False

    def _direction(self, delta: float) -> str:
        if delta < -self.direction_deadband_degrees:
            return "DESCENDING"
        if delta > self.direction_deadband_degrees:
            return "ASCENDING"
        return "STATIONARY"

    def _feedback(
        self,
        frame: TemporalFrame,
        angle: float,
        completed_rep: bool,
        symmetry: Optional[float],
    ) -> List[str]:
        findings: List[str] = []
        if completed_rep:
            findings.append("Squat repetition completed.")
        elif self._phase == SquatPhase.DESCENDING:
            findings.append("Keep lowering under control.")
        elif self._phase == SquatPhase.BOTTOM:
            findings.append("Hold the bottom briefly, then drive up.")
        elif self._phase == SquatPhase.ASCENDING:
            findings.append("Drive up and return to a stable standing position.")
        elif (
            self._phase == SquatPhase.STANDING
            and self._incomplete_cycle
            and not self._incomplete_feedback_emitted
        ):
            findings.append("Squat depth was not reached; repeat with a controlled descent.")
            self._incomplete_feedback_emitted = True
        if frame.torso_inclination is not None and frame.torso_inclination > 45.0:
            findings.append("Reduce observable torso lean.")
        if symmetry is not None and symmetry < 0.80:
            findings.append("Keep both knees tracking evenly.")
        # Keep feedback stable between phase/finding changes; this avoids a
        # contradictory message flash on every camera frame.
        if findings == self._last_feedback:
            return self._last_feedback
        self._last_feedback = findings
        return findings

    def _verified_findings(
        self,
        frame: TemporalFrame,
        symmetry: Optional[float],
    ) -> List[str]:
        """Return only findings supported by current valid measurements.

        These IDs are intentionally small and deterministic so the coach can
        explain them without making independent technique decisions.
        """

        findings: List[str] = []
        if self._incomplete_cycle:
            findings.append("squat_depth")
        if frame.torso_inclination is not None and frame.torso_inclination > 45.0:
            findings.append("squat_torso_inclination")
        if symmetry is not None and symmetry < 0.80:
            findings.append("squat_bilateral_symmetry")
        return findings

    @staticmethod
    def _median(values: Deque[float]) -> float:
        ordered = sorted(values)
        middle = len(ordered) // 2
        if len(ordered) % 2:
            return ordered[middle]
        return (ordered[middle - 1] + ordered[middle]) / 2.0

    def _result(
        self,
        *,
        status: EvaluationStatus,
        completed_rep: bool,
        reason: Optional[str] = None,
        smoothed_knee_angle: Optional[float] = None,
        movement_direction: Optional[str] = None,
        movement_speed_degrees_per_second: Optional[float] = None,
        torso_inclination: Optional[float] = None,
        left_hip_angle: Optional[float] = None,
        right_hip_angle: Optional[float] = None,
        bilateral_knee_symmetry: Optional[float] = None,
        feedback: Optional[List[str]] = None,
        verified_findings: Optional[List[str]] = None,
    ) -> TemporalFrameResult:
        return TemporalFrameResult(
            status=status,
            phase=self._phase,
            repetition_count=self._repetitions,
            completed_rep=completed_rep,
            smoothed_knee_angle=smoothed_knee_angle,
            movement_direction=movement_direction,
            movement_speed_degrees_per_second=movement_speed_degrees_per_second,
            torso_inclination=torso_inclination,
            left_hip_angle=left_hip_angle,
            right_hip_angle=right_hip_angle,
            bilateral_knee_symmetry=bilateral_knee_symmetry,
            feedback_eligible=status == EvaluationStatus.VALID,
            feedback=feedback or [],
            verified_findings=verified_findings or [],
            reason=reason,
            buffer_size=len(self._frames),
            landmarks_retained=(len(self._frames[-1].landmarks) if self._frames else 0),
        )


MAX_ACTIVE_TRACKERS = 128
_trackers: OrderedDict[tuple[str, str, str], SquatTemporalTracker] = OrderedDict()
_generic_trackers: OrderedDict[tuple[str, str, str], GenericTemporalTracker] = OrderedDict()


def _tracker_for(key: tuple[str, str, str]) -> SquatTemporalTracker:
    """Return a session/exercise tracker while bounding registry memory."""

    tracker = _trackers.pop(key, None)
    if tracker is None:
        tracker = SquatTemporalTracker()
    _trackers[key] = tracker
    while len(_trackers) > MAX_ACTIVE_TRACKERS:
        _trackers.popitem(last=False)
    return tracker


def _to_api_result(frame: TemporalPoseInput, result: TemporalFrameResult) -> TemporalAnalysisResult:
    return TemporalAnalysisResult(
        status=result.status,
        skill_id=frame.skill_id,
        session_id=frame.session_id,
        phase=result.phase,
        phase_label=result.phase.value,
        repetition_count=result.repetition_count,
        completed_rep=result.completed_rep,
        smoothed_knee_angle=result.smoothed_knee_angle,
        movement_direction=result.movement_direction,
        movement_speed_degrees_per_second=result.movement_speed_degrees_per_second,
        torso_inclination=result.torso_inclination,
        left_hip_angle=result.left_hip_angle,
        right_hip_angle=result.right_hip_angle,
        bilateral_knee_symmetry=result.bilateral_knee_symmetry,
        feedback_eligible=result.feedback_eligible,
        feedback=result.feedback,
        verified_findings=result.verified_findings,
        reason=result.reason,
        buffer_size=result.buffer_size,
        landmarks_retained=result.landmarks_retained,
    )


@router.post("/squat", response_model=TemporalAnalysisResult)
async def analyze_squat_temporal(frame: TemporalPoseInput) -> TemporalAnalysisResult:
    # Exercise identity is part of temporal state. A session may contain
    # several skills, but their phases and repetition counters must not mix.
    key = (frame.user_id, frame.session_id, frame.skill_id)
    tracker = _tracker_for(key)
    result = tracker.process(
        TemporalFrame(
            timestamp_us=frame.timestamp_us,
            session_id=frame.session_id,
            skill_id=frame.skill_id,
            status=frame.status,
            subject_view=frame.subject_view,
            measurement_confidence=frame.measurement_confidence,
            left_knee_angle=frame.left_knee_angle,
            right_knee_angle=frame.right_knee_angle,
            left_hip_angle=frame.left_hip_angle,
            right_hip_angle=frame.right_hip_angle,
            torso_inclination=frame.torso_inclination,
            bilateral_knee_symmetry=frame.bilateral_knee_symmetry,
            landmarks=tuple(frame.landmarks),
        )
    )
    return _to_api_result(frame, result)


@router.post("/analyze", response_model=TemporalAnalysisResult)
async def analyze_exercise_temporal(frame: TemporalPoseInput) -> TemporalAnalysisResult:
    """Analyze a canonical non-squat exercise without mixing session state."""

    profile = get_exercise_profile(frame.skill_id)
    if profile is None:
        return TemporalAnalysisResult(
            status=EvaluationStatus.INSUFFICIENT_DATA,
            skill_id=frame.skill_id,
            session_id=frame.session_id,
            phase=SquatPhase.STANDING,
            phase_label="READY",
            repetition_count=0,
            completed_rep=False,
            feedback_eligible=False,
            feedback=[],
            verified_findings=[],
            reason="No exercise profile is available for temporal analysis.",
        )
    if profile.name == "Squats":
        return TemporalAnalysisResult(
            status=EvaluationStatus.INSUFFICIENT_DATA,
            skill_id=frame.skill_id,
            session_id=frame.session_id,
            phase=SquatPhase.STANDING,
            phase_label="STANDING",
            feedback_eligible=False,
            reason="Use the squat temporal endpoint for squat sessions.",
        )
    key = (frame.user_id, frame.session_id, frame.skill_id)
    tracker = _generic_trackers.pop(key, None)
    if tracker is None:
        tracker = GenericTemporalTracker(profile)
    _generic_trackers[key] = tracker
    while len(_generic_trackers) > MAX_ACTIVE_TRACKERS:
        _generic_trackers.popitem(last=False)
    status, phase_label, completed, feedback, signal, direction, reason = tracker.process(frame)
    return TemporalAnalysisResult(
        status=status,
        skill_id=frame.skill_id,
        session_id=frame.session_id,
        phase=SquatPhase.STANDING,
        phase_label=phase_label,
        repetition_count=tracker.repetitions,
        completed_rep=completed,
        smoothed_knee_angle=signal,
        movement_direction=direction,
        feedback_eligible=status == EvaluationStatus.VALID,
        feedback=feedback,
        verified_findings=[],
        reason=reason,
        buffer_size=tracker.buffer_size,
    )


@router.delete("/squat/{user_id}/{session_id}")
async def reset_squat_temporal(user_id: str, session_id: str) -> dict[str, str]:
    for key in list(_trackers):
        if key[0] == user_id and key[1] == session_id:
            _trackers.pop(key, None)
            _generic_trackers.pop(key, None)
    return {"status": "reset"}


@router.delete("/analyze/{user_id}/{session_id}")
async def reset_exercise_temporal(user_id: str, session_id: str) -> dict[str, str]:
    for key in list(_generic_trackers):
        if key[0] == user_id and key[1] == session_id:
            _generic_trackers.pop(key, None)
    return {"status": "reset"}
