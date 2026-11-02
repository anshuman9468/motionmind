# MotionMind pose contract v1.0

The Android bridge, Flutter client, and FastAPI endpoints use the same frame
contract. A frame contains only landmarks returned by MediaPipe; omitted
landmarks remain omitted and are reported as unavailable by the quality gate.

## Frame metadata

| Field | Meaning |
| --- | --- |
| `schema_version` | Contract version (`1.0`) |
| `session_id` | Practice-session identifier |
| `skill_id`, `skill_name` | Exercise context; never inferred from a default |
| `timestamp_us` | Monotonic native frame timestamp |
| `image_width`, `image_height` | Dimensions of the image passed to inference |
| `coordinate_space` | `normalized_image` or true MediaPipe `world` coordinates |
| `camera_facing` | `front`, `back`, or `unknown` |
| `subject_view` | `front`, `rear`, `side`, or `unknown` |
| `mirrored`, `rotation_degrees` | Transform metadata for the inference tensor |
| `human_detected`, `tracking_state` | Native tracking state |

## Landmarks

`landmarks` is an array of objects with canonical MediaPipe Pose indices
`0..32`, `x`, `y`, `z`, `visibility`, and optional `presence`. For
`normalized_image`, x/y are normalized image coordinates and z is relative
depth; it is not a metric distance. The biomechanics engine therefore uses
only x/y in that space. z participates in geometry only when
`coordinate_space == "world"`.

The active measurements are geometrically supported joint angles and a
shoulder-to-hip torso-inclination proxy. Missing or non-finite coordinates,
missing confidence, low visibility/presence, unsupported views, and degenerate
vectors produce an explicit quality state rather than a numeric fallback.

## Result states

`VALID`, `LOW_CONFIDENCE`, `INSUFFICIENT_DATA`, `UNSUPPORTED_VIEW`, and
`TRACKING_LOST` are shared by vision, biomechanics, and performance responses.
Only `VALID` biomechanics with an implemented exercise rule profile can produce
a quality score or XP. A quality score is a configurable heuristic, not model
accuracy; XP is a separate gamification value.

## Temporal squat contract

`POST /agents/temporal/squat` receives a timestamped, confidence-gated
measurement sample (`session_id`, `skill_id`, `timestamp_us`, `subject_view`,
`status`, canonical landmarks, bilateral knee angles, hip angles, and torso
inclination). Hip fields remain nullable in the versioned schema so invalid
frames can be represented explicitly.
The active squat tracker requires finite bilateral knee and hip angles plus a
torso inclination before a sample can drive a phase transition; hip-angle
direction is used to corroborate knee movement and pause contradictory frames.
The eight required squat landmarks (shoulders, hips, knees, and ankles) must
also be present with finite coordinates and confidence at or above the
configured temporal threshold.
It retains a bounded per-session buffer of the supplied landmarks and
measurements, applies a three-sample median only to valid angles, and
derives direction/speed from angle change divided by timestamp delta. It does
not interpolate or synthesize missing frames. Phase 3 accepts a side view for
squat tracking; other views and non-squat skills abstain explicitly.

The backend also bounds the active session/exercise tracker registry; old
inactive entries may be evicted without changing any persisted session record.

The response exposes `landmarks_retained` for observability; a zero means the
caller did not supply canonical landmarks and is never treated as a complete
pose.

Valid temporal frames may also emit deterministic `verified_findings` IDs
(`squat_depth`, `squat_torso_inclination`, or
`squat_bilateral_symmetry`). These IDs are accumulated for the session and
passed to the coach as explanations of measured rule findings; the coach does
not infer new faults from them.

The initial standing/descending/bottom/ascending thresholds are configurable
heuristics (150°/120°/130°/160°) and are not accuracy claims. A short tracking
loss pauses the state machine; loss longer than one second resets the partial
phase without incrementing repetitions.

Android intentionally keeps MediaPipe in serial `IMAGE` mode. The Flutter
camera stream already supplies individual frames, so the application-level
bounded buffer owns timestamp ordering, smoothing, and phase transitions
without relying on a second native temporal state machine.

The Flutter practice screen also gates the frame-level squat score on the
temporal result. If the temporal sample is invalid, the HUD clears the score
and shows the repositioning/status message instead of presenting a green
single-frame result.

If the native camera/model channel throws or returns no frame, Flutter clears
the current payload and temporal filter immediately. Completed repetitions are
preserved for the session, but any partial phase must restart from reliable
tracking; no synthetic interruption frame is inserted.
The same reset policy is used when the user pauses the practice session.
For an explicit user pause or exercise switch, Flutter also calls
`DELETE /agents/temporal/squat/{user_id}/{session_id}` so the backend mirror
cannot bridge the reset with a short timestamp gap.
