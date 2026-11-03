import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../core/services/motionmind_api_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import 'models/skill_biomechanics.dart';
import 'models/exercise_registry.dart';
import 'services/biomechanics_engine.dart';
import 'services/temporal_squat_tracker.dart';
import 'services/temporal_exercise_tracker.dart';
import 'services/tracking_stability_filter.dart';
import 'widgets/human_detection_overlay.dart';
import 'widgets/ar_biomechanics_painter.dart';
import 'widgets/biomechanical_hud_panel.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with SingleTickerProviderStateMixin {
  static const _userId = 'usr_99';

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  String? _cameraError;

  // Telemetry Session State
  bool _isPaused = false;
  int _secondsElapsed = 0;
  Timer? _sessionTimer;
  final String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  int? _practiceScore;

  // Mode toggles
  bool _isGhostModeEnabled = false;
  bool _isReplayModeEnabled = false;
  bool _voiceCoachEnabled = true;
  PoseOverlayMode _overlayMode = PoseOverlayMode.minimal;
  // Native Platform Channel Bridge
  static const _visionChannel = MethodChannel(
    'com.skillverse.ai/vision_tracking',
  );
  HumanTrackingPayload _currentTrackingPayload = HumanTrackingPayload.empty();
  late SkillBiomechanicsProfile _currentBiomechanicsProfile;
  late ExerciseDefinition _exercise;
  final int _currentPhaseIndex = 0;
  bool _isPoseFrameProcessing = false;
  bool _onDeviceTrackingReady = false;
  DateTime _nextPoseFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _onDevicePoseError;
  int _poseFramesProcessed = 0;
  int _validFrames = 0;
  int _rejectedFrames = 0;
  double? _lastPoseInferenceMs;

  // Backend synchronization is throttled so the camera UI remains smooth.
  final MotionMindApiService _apiService = MotionMindApiService();
  DateTime _nextBackendAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _backendRequestInFlight = false;
  String _backendStatus = 'Waiting for pose';
  ApiPerformanceResult? _backendPerformance;
  ApiBiomechanicsResult? _backendBiomechanics;
  ApiCoachResponse? _coachResponse;
  bool _coachRequestInFlight = false;
  String? _lastCoachFindingsKey;
  double? _lastBackendLatencyMs;
  final SquatTemporalTracker _temporalTracker = SquatTemporalTracker();
  SquatTemporalResult _temporalResult = const SquatTemporalResult.initial();
  late ExerciseTemporalTracker _exerciseTemporalTracker;
  late ExerciseTemporalResult _exerciseTemporalResult;
  final TrackingStabilityFilter _trackingStabilityFilter =
      TrackingStabilityFilter();
  TrackingStabilityResult _trackingStability =
      TrackingStabilityResult.initial();
  int? _latestPayloadTimestampUs;
  final Set<String> _sessionVerifiedFindings = <String>{};
  final VoiceCoachService _voiceCoach = VoiceCoachService();

  late AnimationController _pulseController;

  bool get _isSquatProfile => _exercise.id == 'squat';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _exercise = ExerciseRegistry.byId(widget.exerciseId);
    _currentBiomechanicsProfile = _exercise.profile;
    _exerciseTemporalTracker = ExerciseTemporalTracker(_exercise);
    _exerciseTemporalResult = ExerciseTemporalResult.initial(_exercise.name);
    unawaited(_voiceCoach.initialize());
    unawaited(_checkBackendHealth());
    _initializeCamera();
    _startSession();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    if (_cameraController?.value.isStreamingImages ?? false) {
      unawaited(_cameraController!.stopImageStream());
    }
    _cameraController?.dispose();
    unawaited(_voiceCoach.dispose());
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      if (mounted) setState(() => _cameraError = null);
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras[_selectedCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraError = null;
          });
        }
        await _initializeOnDeviceTracking();
        await _startPoseStream();
      } else {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _cameraError = 'No camera device found on this phone.';
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final isPermission =
            errStr.contains('permission') ||
            errStr.contains('denied') ||
            errStr.contains('authoriz');
        setState(() {
          _isCameraInitialized = false;
          _cameraError = isPermission
              ? 'Camera permission denied.\nEnable camera access in your phone settings and try again.'
              : 'Camera error: $e';
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    HapticFeedback.mediumImpact();
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No secondary camera detected on this phone.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _resetTemporalAfterInterruption(
      'CAMERA CHANGED. REPOSITION IN A SIDE VIEW TO RESUME.',
    );

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
      // Recreate the native VIDEO-mode landmarker for a new lens. This clears
      // temporal state from the previous camera and prevents a front/rear
      // switch from blending two coordinate streams.
      await _initializeOnDeviceTracking();
      await _startPoseStream();
    } catch (e) {
      debugPrint('Error toggling camera: $e');
    }
  }

  void _startSession() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isReplayModeEnabled) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  Future<void> _initializeOnDeviceTracking() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (mounted) {
        setState(
          () =>
              _onDevicePoseError = 'Movement tracking is available on Android.',
        );
      }
      return;
    }

    try {
      await _visionChannel.invokeMethod('initializePoseLandmarker');
      if (mounted) {
        setState(() {
          _onDeviceTrackingReady = true;
          _onDevicePoseError = null;
        });
      }
    } catch (error) {
      _resetTemporalAfterInterruption(
        'Movement tracking could not start. Reposition and try again.',
      );
      if (mounted) {
        setState(() {
          _onDeviceTrackingReady = false;
          _onDevicePoseError = 'Movement tracking could not start.';
          _backendStatus = 'Movement tracking unavailable';
        });
      }
      debugPrint('MediaPipe initialization failed: $error');
    }
  }

  Future<void> _startPoseStream() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }
    if (!_onDeviceTrackingReady) {
      await _initializeOnDeviceTracking();
    }
    if (!_onDeviceTrackingReady) return;

    try {
      await controller.startImageStream(_submitPoseFrame);
    } catch (error) {
      _resetTemporalAfterInterruption(
        'Movement tracking could not start. Reposition and try again.',
      );
      if (mounted) {
        setState(() => _onDevicePoseError = 'Could not read camera frames.');
      }
      debugPrint('Camera image stream failed: $error');
    }
  }

  void _submitPoseFrame(CameraImage image) {
    if (!mounted ||
        _isPaused ||
        _isReplayModeEnabled ||
        _isPoseFrameProcessing ||
        DateTime.now().isBefore(_nextPoseFrameAt)) {
      return;
    }

    _isPoseFrameProcessing = true;
    // The native bridge uses one bounded executor and this flag provides
    // backpressure. Eight-ish samples per second are enough for the local
    // angle state machine while avoiding an unbounded queue of camera images.
    // A 10 FPS cap keeps native inference bounded while making phase changes
    // visibly responsive for slow, controlled repetitions.
    _nextPoseFrameAt = DateTime.now().add(const Duration(milliseconds: 100));
    final camera = _cameras[_selectedCameraIndex];
    unawaited(_processPoseFrame(image, camera));
  }

  Future<void> _processPoseFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _visionChannel.invokeMapMethod<String, dynamic>(
        'processCameraFrame',
        {
          'width': image.width,
          'height': image.height,
          'rotationDegrees': camera.sensorOrientation,
          'cameraFacing': camera.lensDirection.name,
          // The native bitmap is not horizontally flipped before MediaPipe;
          // preview mirroring must not be mistaken for inference mirroring.
          'mirrored': false,
          'sessionId': _sessionId,
          'skillId': _exercise.id,
          'skillName': _exercise.name,
          'subjectView': _exercise.supportedView,
          // The experimental TFLite quality model is intentionally disabled
          // during coaching. It is not validated for technique scoring and
          // would otherwise consume time needed for real pose tracking.
          'runExperimentalQuality': false,
          'planes': image.planes
              .map(
                (plane) => {
                  'bytes': plane.bytes,
                  'bytesPerRow': plane.bytesPerRow,
                  'bytesPerPixel': plane.bytesPerPixel ?? 1,
                },
              )
              .toList(growable: false),
        },
      );
      if (response != null && mounted) {
        _poseFramesProcessed++;
        _lastPoseInferenceMs = stopwatch.elapsedMicroseconds / 1000.0;
        _updateTrackingPayload(HumanTrackingPayload.fromJson(response));
      } else if (mounted) {
        _resetTemporalAfterInterruption(
          'NO POSE FRAME RECEIVED. REPOSITION AND TRY AGAIN.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _onDevicePoseError = 'Movement tracking failed.';
          _backendStatus = 'Movement tracking unavailable';
        });
      }
      if (error is PlatformException && error.code == 'MODELS_NOT_READY') {
        _onDeviceTrackingReady = false;
        await _initializeOnDeviceTracking();
      }
      _resetTemporalAfterInterruption(
        'Movement tracking failed. Reposition and try again.',
      );
      debugPrint('MediaPipe frame inference failed: $error');
    } finally {
      _isPoseFrameProcessing = false;
    }
  }

  void _updateTrackingPayload(HumanTrackingPayload payload) {
    if (!mounted) return;
    final stability = _trackingStabilityFilter.update(payload);
    final squatResult = _isSquatProfile && stability.shouldProcess
        ? _temporalTracker.process(payload)
        : null;
    final exerciseResult = !_isSquatProfile && stability.shouldProcess
        ? _exerciseTemporalTracker.process(payload)
        : null;
    final temporalStatus = squatResult?.status ?? exerciseResult?.status;
    if (temporalStatus != null) {
      if (temporalStatus == BiomechanicsEvaluationStatus.valid) {
        _validFrames++;
      } else {
        _rejectedFrames++;
      }
    }
    _sessionVerifiedFindings.addAll(
      squatResult?.verifiedFindings ??
          exerciseResult?.verifiedFindings ??
          const [],
    );
    setState(() {
      _trackingStability = stability;
      _currentTrackingPayload = stability.displayPayload;
      _latestPayloadTimestampUs = payload.timestampUs;
      if (squatResult != null) _temporalResult = squatResult;
      if (exerciseResult != null) _exerciseTemporalResult = exerciseResult;
      _onDevicePoseError = null;
      // Keep the last accepted backend sample while the next request is in
      // flight. Clearing it on every camera frame made a normal 8 FPS stream
      // erase the response before it could be rendered. Invalid local frames
      // still clear it, so a previous score is never shown during loss.
      if (temporalStatus != null &&
          temporalStatus != BiomechanicsEvaluationStatus.valid) {
        _backendPerformance = null;
        _backendBiomechanics = null;
        _practiceScore = null;
      }
      if (_backendStatus == 'Movement tracking unavailable') {
        _backendStatus = 'Waiting for backend';
      }
    });
    if (stability.shouldProcess && stability.rawReliable) {
      _scheduleBackendAnalysis(payload);
    }
    unawaited(
      _announceVoiceTracking(payload, squatResult, exerciseResult, stability),
    );
  }

  Future<void> _announceVoiceTracking(
    HumanTrackingPayload payload,
    SquatTemporalResult? squatResult,
    ExerciseTemporalResult? exerciseResult,
    TrackingStabilityResult stability,
  ) async {
    if (stability.gracePeriod || (!stability.locked && stability.rawReliable)) {
      // A candidate pose is still being confirmed; do not tell the user to
      // move into frame while the detector is settling.
      return;
    }
    final detected =
        payload.humanDetected &&
        payload.trackingState == HumanDetectionState.humanLocked;
    final resultStatus = squatResult?.status ?? exerciseResult?.status;
    final evaluationValid = resultStatus == BiomechanicsEvaluationStatus.valid;
    await _voiceCoach.handleTrackingUpdate(
      exerciseId: _exercise.id,
      trackingReady: stability.locked && detected && evaluationValid,
      evaluationValid: evaluationValid,
      phase: squatResult?.phase.label ?? exerciseResult?.phaseLabel ?? '',
      repetitions:
          squatResult?.repetitionCount ?? exerciseResult?.repetitionCount ?? 0,
      completedRepetition:
          squatResult?.completedRep ?? exerciseResult?.completedCycle ?? false,
      instruction: squatResult?.message ?? exerciseResult?.message,
      feedbackEligible:
          squatResult?.feedbackEligible ??
          exerciseResult?.feedbackEligible ??
          false,
    );
  }

  void _scheduleBackendAnalysis(HumanTrackingPayload payload) {
    if (payload.timestampUs <= 0) {
      if (mounted)
        setState(() => _backendStatus = 'Tracking lost • no timestamp');
      return;
    }

    final now = DateTime.now();
    if (_backendRequestInFlight || now.isBefore(_nextBackendAttempt)) return;

    // Keep the local HUD real-time while sending a useful sample roughly once
    // per second instead of making a request for every camera poll.
    _nextBackendAttempt = now.add(const Duration(seconds: 1));
    _backendRequestInFlight = true;
    if (mounted) {
      setState(() => _backendStatus = 'Syncing...');
    }
    unawaited(_analyzeFrameOnBackend(payload));
  }

  Future<void> _analyzeFrameOnBackend(HumanTrackingPayload payload) async {
    final stopwatch = Stopwatch()..start();
    try {
      final vision = await _apiService.analyzeVision(
        userId: _userId,
        payload: payload,
      );
      final biomechanics = await _apiService.analyzeBiomechanics(
        userId: _userId,
        payload: payload,
      );
      final performance = await _apiService.evaluatePerformance(biomechanics);
      final temporal = payload.timestampUs > 0
          ? _isSquatProfile
                ? await _apiService.analyzeSquatTemporal(
                    userId: _userId,
                    sessionId: _sessionId,
                    timestampUs: payload.timestampUs,
                    payload: payload,
                    biomechanics: biomechanics,
                  )
                : await _apiService.analyzeExerciseTemporal(
                    userId: _userId,
                    sessionId: _sessionId,
                    payload: payload,
                    biomechanics: biomechanics,
                  )
          : null;
      if (temporal != null && temporal.status == 'VALID') {
        _sessionVerifiedFindings.addAll(temporal.verifiedFindings);
      }
      final gatedPerformance = temporal != null && temporal.status != 'VALID'
          ? null
          : performance;

      final latestTimestamp = _latestPayloadTimestampUs;
      final responseIsRecent =
          latestTimestamp != null &&
          payload.timestampUs <= latestTimestamp &&
          latestTimestamp - payload.timestampUs <= 2000000;
      if (mounted && responseIsRecent) {
        final temporalSummary = temporal == null
            ? ''
            : ' • ${temporal.phaseLabel ?? temporal.phase} • ${temporal.repetitionCount} reps';
        setState(() {
          _backendBiomechanics = biomechanics;
          _backendPerformance = gatedPerformance;
          _practiceScore = gatedPerformance?.xp;
          _backendStatus =
              'Online • ${vision.status} • ${vision.detectedJointsCount} landmarks'
              '$temporalSummary';
          _lastBackendLatencyMs = stopwatch.elapsedMicroseconds / 1000.0;
        });
        if (gatedPerformance != null) {
          unawaited(_requestVerifiedCoach(gatedPerformance, biomechanics));
        }
      }
    } catch (error) {
      // The local camera and biomechanics HUD remain usable when the backend
      // is stopped or the phone is temporarily offline.
      _nextBackendAttempt = DateTime.now().add(const Duration(seconds: 5));
      if (mounted && payload.timestampUs == _latestPayloadTimestampUs) {
        final detail = error is MotionMindApiException
            ? error.message
            : error.toString();
        setState(() {
          _lastBackendLatencyMs = stopwatch.elapsedMicroseconds / 1000.0;
          _backendStatus = 'Request failed • ${_shortStatus(detail)}';
        });
      }
      debugPrint('MotionMind backend unavailable: $error');
    } finally {
      _backendRequestInFlight = false;
    }
  }

  Future<void> _checkBackendHealth() async {
    if (!mounted) return;
    setState(() => _backendStatus = 'Connecting...');
    try {
      final health = await _apiService.health();
      if (!mounted) return;
      setState(() {
        _backendStatus = health.healthy
            ? 'Online • health check'
            : 'Request failed • unhealthy';
      });
    } catch (error) {
      if (!mounted) return;
      final detail = error is MotionMindApiException
          ? error.message
          : error.toString();
      setState(() => _backendStatus = 'Offline • ${_shortStatus(detail)}');
      debugPrint('MotionMind backend health check failed: $error');
    }
  }

  String _shortStatus(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 54
        ? normalized
        : '${normalized.substring(0, 51)}...';
  }

  Future<void> _requestVerifiedCoach(
    ApiPerformanceResult performance,
    ApiBiomechanicsResult biomechanics,
  ) async {
    if (!performance.feedbackEligible || performance.verifiedFindings.isEmpty) {
      return;
    }
    final key = '${_exercise.id}:${performance.verifiedFindings.join('|')}';
    if (_coachRequestInFlight || key == _lastCoachFindingsKey) return;
    _coachRequestInFlight = true;
    _lastCoachFindingsKey = key;
    try {
      final response = await _apiService.generateCoachFeedback(
        detectedMistakes: performance.detectedMistakes,
        analysisStatus: performance.status,
        skillId: _exercise.id,
        qualityScore: performance.qualityScore,
        phase: _activePhaseLabel,
        confidenceStatus: biomechanics.dataQualityStatus,
        verifiedFindings: performance.verifiedFindings,
        verifiedMeasurements: {
          'left_knee_angle': biomechanics.leftKneeAngle,
          'right_knee_angle': biomechanics.rightKneeAngle,
          'torso_inclination': biomechanics.torsoInclination,
        },
      );
      if (mounted) setState(() => _coachResponse = response);
    } catch (error) {
      // Deterministic findings remain visible locally. No fabricated AI reply
      // is shown when the optional coaching service is unavailable.
      debugPrint('Verified coach request failed: $error');
    } finally {
      _coachRequestInFlight = false;
    }
  }

  void _togglePause() {
    HapticFeedback.selectionClick();
    if (!_isPaused) {
      unawaited(_resetBackendTemporal());
      _resetTemporalAfterInterruption(
        'SESSION PAUSED. REPOSITION BEFORE RESUMING TRACKING.',
      );
      unawaited(_voiceCoach.speakCue('Session paused.'));
    }
    setState(() {
      _isPaused = !_isPaused;
    });
    if (!_isPaused) {
      unawaited(_voiceCoach.speakCue('Session resumed. Move when ready.'));
    }
  }

  Future<void> _resetBackendTemporal() async {
    if (!_isSquatProfile) return;
    try {
      await _apiService.resetSquatTemporal(
        userId: _userId,
        sessionId: _sessionId,
      );
    } catch (error) {
      // Local tracking remains authoritative when the backend is offline.
      debugPrint('Could not reset backend temporal tracker: $error');
    }
  }

  void _resetTemporalAfterInterruption(String message) {
    if (!mounted) return;
    _trackingStabilityFilter.reset();
    final temporalResult = _temporalTracker.resetAfterInterruption(
      message: message,
    );
    final exerciseResult = _exerciseTemporalTracker.resetAfterInterruption(
      message,
    );
    setState(() {
      _trackingStability = TrackingStabilityResult.initial();
      _currentTrackingPayload = HumanTrackingPayload.empty();
      _latestPayloadTimestampUs = null;
      _temporalResult = temporalResult;
      _exerciseTemporalResult = exerciseResult;
      _backendPerformance = null;
      _backendBiomechanics = null;
      _practiceScore = null;
      _backendStatus = 'Tracking lost';
    });
    if (!message.toUpperCase().contains('PAUSED')) {
      unawaited(
        _voiceCoach.handleTrackingUpdate(
          exerciseId: _exercise.id,
          trackingReady: false,
          evaluationValid: false,
          phase: '',
          repetitions: temporalResult.repetitionCount > 0
              ? temporalResult.repetitionCount
              : exerciseResult.repetitionCount,
          completedRepetition: false,
          instruction: message,
        ),
      );
    }
  }

  int get _activeRepetitionCount => _isSquatProfile
      ? _temporalResult.repetitionCount
      : _exerciseTemporalResult.repetitionCount;

  String get _activePhaseLabel => _isSquatProfile
      ? _temporalResult.phase.label
      : _exerciseTemporalResult.phaseLabel;

  BiomechanicsEvaluationStatus get _activeTemporalStatus =>
      _isSquatProfile ? _temporalResult.status : _exerciseTemporalResult.status;

  String get _activeTemporalMessage => _isSquatProfile
      ? _temporalResult.message
      : _exerciseTemporalResult.message;

  void _finishSession() {
    HapticFeedback.heavyImpact();
    unawaited(_voiceCoach.stop());
    _sessionTimer?.cancel();
    unawaited(_persistSession());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Session Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _activeRepetitionCount > 0
                    ? 'Your verified ${_exercise.name.toLowerCase()} practice is ready to review.'
                    : 'No complete ${_exercise.name.toLowerCase()} repetition was verified this time.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.glassBorder),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatSummary(
                    'Quality',
                    _practiceScore == null ? 'Pending' : '$_practiceScore%',
                  ),
                  _buildStatSummary('Reps', '$_activeRepetitionCount'),
                  _buildStatSummary(
                    'Duration',
                    _formatDuration(_secondsElapsed),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _persistSession() async {
    final mistakes = _backendPerformance?.detectedMistakes ?? const <String>[];
    final verifiedFindings = <String>{
      ...?_backendPerformance?.verifiedFindings,
      ..._sessionVerifiedFindings,
    }.toList(growable: false);
    final qualityScore = _backendPerformance?.qualityScore;
    final finalScore = qualityScore?.round();

    try {
      final coach = await _apiService.generateCoachFeedback(
        detectedMistakes: mistakes,
        practiceScore: _backendPerformance?.xp,
        analysisStatus: _backendPerformance?.status,
        skillId: _exercise.id,
        qualityScore: qualityScore,
        phase: _activePhaseLabel,
        confidenceStatus: _backendBiomechanics?.dataQualityStatus,
        verifiedFindings: verifiedFindings,
        verifiedMeasurements: {
          'left_elbow_angle': _backendBiomechanics?.leftElbowAngle,
          'right_elbow_angle': _backendBiomechanics?.rightElbowAngle,
          'left_knee_angle': _backendBiomechanics?.leftKneeAngle,
          'right_knee_angle': _backendBiomechanics?.rightKneeAngle,
          'left_hip_angle': _backendBiomechanics?.leftHipAngle,
          'right_hip_angle': _backendBiomechanics?.rightHipAngle,
          'torso_inclination': _backendBiomechanics?.torsoInclination,
          'bilateral_knee_symmetry':
              _backendBiomechanics?.bilateralKneeSymmetry,
        },
      );
      final session = ApiSessionRecord(
        sessionId: _sessionId,
        userId: _userId,
        durationSeconds: _secondsElapsed,
        calories: null,
        finalScore: finalScore,
        mistakesLog: mistakes,
        repetitions: _activeRepetitionCount,
        exerciseId: _exercise.id,
        category: _exercise.categoryLabel,
        trackingQuality: _backendBiomechanics?.measurementConfidence,
        validFrames: _validFrames,
        rejectedFrames: _rejectedFrames,
        processingLatencyMs: _lastPoseInferenceMs,
        confidenceReasons:
            _backendBiomechanics?.unavailableMeasurements ?? const [],
        verifiedFindings: verifiedFindings,
        cameraFacing: _currentTrackingPayload.cameraFacing,
        subjectView: _exercise.supportedView,
      );
      await _apiService.storeSession(session);
      if (finalScore != null) {
        await _apiService.updateTwinProfile(
          userId: _userId,
          recentMistakes: mistakes,
          sessionScores: [finalScore],
        );
      }

      if (mounted) {
        setState(() {
          _coachResponse = coach;
          _backendStatus = 'Saved to backend';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _backendStatus = 'Not saved • backend offline');
      }
      debugPrint('Could not persist MotionMind session: $error');
    }
  }

  String get _activeInstruction {
    if (_activeTemporalStatus == BiomechanicsEvaluationStatus.valid &&
        _coachResponse?.feedbackText.isNotEmpty == true) {
      return _coachResponse!.feedbackText;
    }
    return _activeTemporalMessage;
  }

  void _showDeveloperDiagnostics() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Developer diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Technical details are kept here so the practice view stays clear.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _diagnosticRow('Backend', _backendStatus),
              _diagnosticRow(
                'Backend latency',
                _lastBackendLatencyMs == null
                    ? '—'
                    : '${_lastBackendLatencyMs!.toStringAsFixed(0)} ms',
              ),
              _diagnosticRow(
                'Pose processing',
                _lastPoseInferenceMs == null
                    ? '—'
                    : '${_lastPoseInferenceMs!.toStringAsFixed(0)} ms',
              ),
              _diagnosticRow(
                'Frames accepted',
                '$_validFrames / $_poseFramesProcessed',
              ),
              _diagnosticRow('Overlay mode', _overlayMode.name),
              if (_onDevicePoseError != null)
                _diagnosticRow('Camera tracking', _onDevicePoseError!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(String label, String val) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int secs) {
    final minutes = (secs / 60).floor();
    final remaining = secs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentPhase = _currentBiomechanicsProfile.phases[_currentPhaseIndex];
    final automaticPhaseLabel = _activePhaseLabel;
    var evalFrame = BiomechanicsEngine.evaluateFrame(
      payload: _currentTrackingPayload,
      phaseTarget: currentPhase,
      skillId: _currentBiomechanicsProfile.skillId,
    );
    if (_activeTemporalStatus != BiomechanicsEvaluationStatus.valid) {
      evalFrame = BiomechanicsEngine.suppressTechniqueEvaluation(
        evaluation: evalFrame,
        status: _activeTemporalStatus,
        instruction: _activeTemporalMessage,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Camera Live Feed or Simulation Placeholder
          Positioned.fill(
            child: _isCameraInitialized && !_isReplayModeEnabled
                ? CameraPreview(_cameraController!)
                : Container(
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: GridPaper(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.05,
                            ),
                            interval: 40,
                            subdivisions: 1,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _cameraError != null
                                  ? Icons.videocam_off_rounded
                                  : Icons.video_camera_back_rounded,
                              color: _cameraError != null
                                  ? AppColors.roseError
                                  : AppColors.primaryBlue.withValues(
                                      alpha: 0.2,
                                    ),
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _cameraError ??
                                    (_isReplayModeEnabled
                                        ? 'Replay Analytics Mode'
                                        : 'Preparing movement tracking…'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cameraError != null
                                      ? AppColors.roseError
                                      : AppColors.textMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (_cameraError != null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _initializeCamera,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Retry Camera Access'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
          ),

          // 2. Custom AR Biomechanics Painter Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: ARBiomechanicsPainter(
                payload: _currentTrackingPayload,
                evaluation: evalFrame,
                currentPhase: currentPhase,
                isGhostModeEnabled: _isGhostModeEnabled,
                isReplayModeEnabled: _isReplayModeEnabled,
                overlayMode: _overlayMode,
                pulseProgress: _pulseController.value,
              ),
            ),
          ),

          // 2B. 4-State Human Detection & Multi-Person Selector Overlay
          Positioned.fill(
            child: HumanDetectionOverlay(
              payload: _currentTrackingPayload,
              onSelectPerson: (id) async {
                try {
                  await _visionChannel.invokeMethod('selectPrimaryPerson', {
                    'personId': id,
                  });
                } catch (_) {}
              },
            ),
          ),

          // 3. Safety Area Overlay HUD
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 230),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(
                                alpha: .75,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _exercise.icon,
                                color: AppColors.primaryBlue,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _exercise.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Switch camera front/back button
                    IconButton(
                      onPressed: _toggleCamera,
                      icon: const Icon(
                        Icons.flip_camera_ios_rounded,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    IconButton(
                      tooltip: _voiceCoachEnabled
                          ? 'Turn voice coaching off'
                          : 'Turn voice coaching on',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final enabled = !_voiceCoachEnabled;
                        setState(() => _voiceCoachEnabled = enabled);
                        unawaited(_voiceCoach.setEnabled(enabled));
                        if (enabled) {
                          unawaited(
                            _voiceCoach.speakCue('Voice coaching is on.'),
                          );
                        }
                      },
                      icon: Icon(
                        _voiceCoachEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: _voiceCoachEnabled
                            ? AppColors.primaryBlue
                            : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Pose overlay mode',
                      icon: const Icon(
                        Icons.layers_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                      onSelected: (mode) {
                        if (mode == 'diagnostics') {
                          _showDeveloperDiagnostics();
                        } else {
                          setState(
                            () => _overlayMode = PoseOverlayMode.values
                                .firstWhere((value) => value.name == mode),
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'off',
                          child: Text('Overlay: off'),
                        ),
                        PopupMenuItem(
                          value: 'minimal',
                          child: Text('Overlay: minimal'),
                        ),
                        PopupMenuItem(
                          value: 'fullSkeleton',
                          child: Text('Overlay: full'),
                        ),
                        PopupMenuItem(
                          value: 'diagnostics',
                          child: Text('Developer diagnostics'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: _buildTrackingIndicator(),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildHudTile(
                        Icons.timer_outlined,
                        _formatDuration(_secondsElapsed),
                        'Duration',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHudTile(
                        Icons.repeat_rounded,
                        '$_activeRepetitionCount',
                        'Reps',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHudTile(
                        Icons.auto_awesome_rounded,
                        _backendPerformance?.qualityScore == null
                            ? 'Pending'
                            : '${_backendPerformance!.qualityScore!.toInt()}%',
                        'Quality',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Backend latency and model diagnostics are available from
                // the layers menu, not in the consumer practice HUD.
              ],
            ),
          ),

          // 4. Biomechanical Real-Time Diagnostic HUD Panel
          Positioned(
            left: 10,
            right: 10,
            bottom: MediaQuery.of(context).padding.bottom + 160,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: BiomechanicalHudPanel(
                  profile: _currentBiomechanicsProfile,
                  currentPhase: currentPhase,
                  phaseLabel: automaticPhaseLabel,
                  automaticPhase: true,
                  instructionOverride: _activeInstruction,
                  evaluation: evalFrame,
                  onNextPhase: () {},
                  onPrevPhase: () {},
                ),
              ),
            ),
          ),

          // 5. Bottom control panel actions
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureButton(
                        'Pose guide',
                        Icons.copy_rounded,
                        _isGhostModeEnabled,
                        () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _isGhostModeEnabled = !_isGhostModeEnabled,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureButton(
                        'Replay',
                        Icons.history_rounded,
                        _isReplayModeEnabled,
                        () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _isReplayModeEnabled = !_isReplayModeEnabled,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        text: _isPaused ? 'Resume' : 'Pause',
                        icon: _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        onPressed: _togglePause,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        text: 'Finish session',
                        icon: Icons.stop_rounded,
                        onPressed: _finishSession,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingIndicator() {
    final detected =
        _trackingStability.locked &&
        _currentTrackingPayload.humanDetected &&
        _currentTrackingPayload.trackingState ==
            HumanDetectionState.humanLocked;
    final evaluationReady =
        detected && _activeTemporalStatus == BiomechanicsEvaluationStatus.valid;
    final indicatorColor = _trackingStability.gracePeriod
        ? AppColors.amberWarning
        : !detected
        ? AppColors.roseError
        : (evaluationReady ? AppColors.emeraldGreen : AppColors.amberWarning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            detected
                ? Icons.person_pin_circle_rounded
                : Icons.person_off_rounded,
            color: indicatorColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _trackingStability.gracePeriod
                ? 'Tracking stabilizing'
                : !detected
                ? 'Move into frame'
                : (evaluationReady
                      ? 'Tracking • $_activePhaseLabel'
                      : 'Adjust your position'),
            style: TextStyle(
              color: indicatorColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudTile(IconData icon, String val, String subtitle) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    val,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryBlue.withValues(alpha: 0.15)
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primaryBlue : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? AppColors.primaryBlue : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.primaryBlue : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retained only for source compatibility with older callers. The active
/// practice screen uses [ARBiomechanicsPainter]; this legacy painter is not
/// instantiated and intentionally renders nothing so it cannot display
/// fabricated skeleton coordinates.
@Deprecated('Use ARBiomechanicsPainter with a real HumanTrackingPayload.')
class PosePainter extends CustomPainter {
  final double elbowAngle;
  final double backAngle;
  final Color skeletonColor;
  final bool isGhostMode;
  final bool isReplayMode;
  final double pulseProgress;
  final bool isLearnerInFrame;
  final bool isCalibrating;

  PosePainter({
    required this.elbowAngle,
    required this.backAngle,
    required this.skeletonColor,
    required this.isGhostMode,
    required this.isReplayMode,
    required this.pulseProgress,
    required this.isLearnerInFrame,
    required this.isCalibrating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Never render the former synthetic-pose implementation.
    return;

    /*
    final center = Offset(size.width / 2, size.height / 2);

    // IF NO HUMAN IS IN FRAME: DO NOT DRAW STICK FIGURE ON DOORS OR WALLS!
    if (!isLearnerInFrame) {
      final scanRectPaint = Paint()
        ..color = AppColors.cyanGlow.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rWidth = size.width * 0.7;
      final rHeight = size.height * 0.5;
      final rLeft = (size.width - rWidth) / 2;
      final rTop = (size.height - rHeight) / 2;
      final cornerLen = 24.0;

      // Draw Corner Reticles
      canvas.drawLine(
        Offset(rLeft, rTop),
        Offset(rLeft + cornerLen, rTop),
        scanRectPaint,
      );
      canvas.drawLine(
        Offset(rLeft, rTop),
        Offset(rLeft, rTop + cornerLen),
        scanRectPaint,
      );

      canvas.drawLine(
        Offset(rLeft + rWidth, rTop),
        Offset(rLeft + rWidth - cornerLen, rTop),
        scanRectPaint,
      );
      canvas.drawLine(
        Offset(rLeft + rWidth, rTop),
        Offset(rLeft + rWidth, rTop + cornerLen),
        scanRectPaint,
      );

      canvas.drawLine(
        Offset(rLeft, rTop + rHeight),
        Offset(rLeft + cornerLen, rTop + rHeight),
        scanRectPaint,
      );
      canvas.drawLine(
        Offset(rLeft, rTop + rHeight),
        Offset(rLeft, rTop + rHeight - cornerLen),
        scanRectPaint,
      );

      canvas.drawLine(
        Offset(rLeft + rWidth, rTop + rHeight),
        Offset(rLeft + rWidth - cornerLen, rTop + rHeight),
        scanRectPaint,
      );
      canvas.drawLine(
        Offset(rLeft + rWidth, rTop + rHeight),
        Offset(rLeft + rWidth, rTop + rHeight - cornerLen),
        scanRectPaint,
      );

      // Pulsing Reticle Core
      canvas.drawCircle(
        center,
        35 + (pulseProgress * 15),
        Paint()
          ..color = AppColors.cyanGlow.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = AppColors.primaryBlue.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill,
      );

      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.text = const TextSpan(
        text:
            '[ SEARCHING FOR LEARNER IN FRAME ]\nStep in front of camera to begin posture analysis',
        style: TextStyle(
          color: AppColors.cyanGlow,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          height: 1.5,
        ),
      );
      tp.layout(maxWidth: rWidth);
      tp.paint(canvas, Offset(center.dx - (tp.width / 2), rTop + rHeight + 16));
      return;
    }

    // IF LEARNER IS IN FRAME BUT CALIBRATING:
    if (isCalibrating) {
      final scanY =
          (size.height * 0.25) + (pulseProgress * (size.height * 0.45));
      final laserPaint = Paint()
        ..color = AppColors.cyanGlow
        ..strokeWidth = 3.0;

      final laserGlowPaint = Paint()
        ..color = AppColors.cyanGlow.withValues(alpha: 0.15)
        ..strokeWidth = 12.0;

      canvas.drawLine(
        Offset(size.width * 0.15, scanY),
        Offset(size.width * 0.85, scanY),
        laserGlowPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.15, scanY),
        Offset(size.width * 0.85, scanY),
        laserPaint,
      );

      final tp = TextPainter(textDirection: TextDirection.ltr);
      tp.text = TextSpan(
        text: '⚡ CALIBRATING HUMAN BIOMECHANICS... STAY STILL',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          background: Paint()
            ..color = AppColors.primaryBlue
            ..style = PaintingStyle.fill,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(center.dx - (tp.width / 2), scanY - 24));
      return;
    }

    // ONCE LEARNER IS CONFIRMED & CALIBRATED: DRAW SKELETON
    final head = Offset(center.dx, center.dy - 120);
    final shoulderL = Offset(center.dx - 60, center.dy - 70);
    final shoulderR = Offset(center.dx + 60, center.dy - 70);

    final elbowRad = (elbowAngle * math.pi) / 180;
    final elbowL = Offset(shoulderL.dx - 50, shoulderL.dy + 40);
    final wristL = Offset(
      elbowL.dx - 40 * math.sin(elbowRad),
      elbowL.dy + 50 * math.cos(elbowRad),
    );

    final elbowR = Offset(shoulderR.dx + 50, shoulderR.dy + 40);
    final wristR = Offset(elbowR.dx + 50, elbowR.dy + 40);

    final hipL = Offset(center.dx - 45, center.dy + 70);
    final hipR = Offset(center.dx + 45, center.dy + 70);
    final kneeL = Offset(hipL.dx - 15, hipL.dy + 90);
    final kneeR = Offset(hipR.dx + 15, hipR.dy + 90);
    final footL = Offset(kneeL.dx - 20, kneeL.dy + 80);
    final footR = Offset(kneeR.dx + 20, kneeR.dy + 80);

    // 1. Ghost Pose
    if (isGhostMode) {
      final ghostPaint = Paint()
        ..color = AppColors.primaryBlue.withValues(alpha: 0.25)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final gElbowL = Offset(shoulderL.dx - 60, shoulderL.dy + 60);
      final gWristL = Offset(gElbowL.dx - 60, gElbowL.dy + 20);

      canvas.drawLine(head, shoulderL, ghostPaint);
      canvas.drawLine(head, shoulderR, ghostPaint);
      canvas.drawLine(shoulderL, shoulderR, ghostPaint);
      canvas.drawLine(shoulderL, gElbowL, ghostPaint);
      canvas.drawLine(gElbowL, gWristL, ghostPaint);
      canvas.drawLine(shoulderL, hipL, ghostPaint);
      canvas.drawLine(shoulderR, hipR, ghostPaint);
      canvas.drawLine(hipL, kneeL, ghostPaint);
      canvas.drawLine(kneeL, footL, ghostPaint);
      canvas.drawLine(hipR, kneeR, ghostPaint);
      canvas.drawLine(kneeR, footR, ghostPaint);
    }

    // 2. User Skeleton Lines
    final linePaint = Paint()
      ..color = skeletonColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(head, shoulderL, linePaint);
    canvas.drawLine(head, shoulderR, linePaint);
    canvas.drawLine(shoulderL, shoulderR, linePaint);
    canvas.drawLine(shoulderL, elbowL, linePaint);
    canvas.drawLine(elbowL, wristL, linePaint);
    canvas.drawLine(shoulderR, elbowR, linePaint);
    canvas.drawLine(elbowR, wristR, linePaint);
    canvas.drawLine(shoulderL, hipL, linePaint);
    canvas.drawLine(shoulderR, hipR, linePaint);
    canvas.drawLine(hipL, hipR, linePaint);
    canvas.drawLine(hipL, kneeL, linePaint);
    canvas.drawLine(kneeL, footL, linePaint);
    canvas.drawLine(hipR, kneeR, linePaint);
    canvas.drawLine(kneeR, footR, linePaint);

    // 3. Joint Nodes
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = skeletonColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final joints = [
      head,
      shoulderL,
      shoulderR,
      elbowL,
      wristL,
      elbowR,
      wristR,
      hipL,
      hipR,
      kneeL,
      kneeR,
      footL,
      footR,
    ];
    for (final j in joints) {
      canvas.drawCircle(j, 10 + (pulseProgress * 4), glowPaint);
      canvas.drawCircle(j, 5, nodePaint);
    }

    // 4. Center of Gravity crosshair
    final cog = Offset(center.dx, center.dy + 40);
    final cogPaint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(cog, 8, cogPaint);
    canvas.drawCircle(
      cog,
      16 + (pulseProgress * 8),
      Paint()
        ..color = AppColors.primaryBlue.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 5. Posture Scan Quality Tags
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawScanTag(String text, Color color, Offset offset) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          background: Paint()
            ..color = Colors.black
            ..style = PaintingStyle.fill,
        ),
      );
      tp.layout();
      tp.paint(canvas, offset);
    }

    drawScanTag(
      'Learner Lock [Head Sync]',
      AppColors.cyanGlow,
      Offset(head.dx + 12, head.dy - 6),
    );
    drawScanTag(
      'Good [Shoulders L/R]',
      AppColors.cyanGlow,
      Offset(shoulderL.dx - 45, shoulderL.dy - 18),
    );

    final elbowStatus = elbowAngle > 140
        ? 'Great'
        : (elbowAngle > 120 ? 'Good' : 'Bad (Flex Elbow)');
    final elbowColor = elbowAngle > 140
        ? AppColors.emeraldGreen
        : (elbowAngle > 120 ? AppColors.primaryBlue : AppColors.primaryPurple);
    drawScanTag(
      '$elbowStatus [L-Elbow: ${elbowAngle.toInt()}°]',
      elbowColor,
      Offset(elbowL.dx - 60, elbowL.dy - 16),
    );

    final backStatus = backAngle > 170 ? 'Great' : 'Bad (Leaning)';
    final backColor = backAngle > 170
        ? AppColors.emeraldGreen
        : AppColors.primaryPurple;
    drawScanTag(
      '$backStatus [Spine: ${backAngle.toInt()}°]',
      backColor,
      Offset(cog.dx + 16, cog.dy - 6),
    );

    drawScanTag(
      'Great [Knees Balanced]',
      AppColors.emeraldGreen,
      Offset(kneeR.dx + 12, kneeR.dy - 6),
    );
    drawScanTag(
      'Good [Footing]',
      AppColors.cyanGlow,
      Offset(footL.dx - 12, footL.dy + 12),
    );

    if (isReplayMode) {
      final heatmapPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.red.withValues(alpha: 0.6),
            Colors.orange.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: elbowL, radius: 45))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(elbowL, 45, heatmapPaint);
      canvas.drawCircle(kneeR, 40, heatmapPaint);
    }
    */
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.elbowAngle != elbowAngle ||
        oldDelegate.backAngle != backAngle ||
        oldDelegate.skeletonColor != skeletonColor ||
        oldDelegate.isGhostMode != isGhostMode ||
        oldDelegate.isReplayMode != isReplayMode ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.isLearnerInFrame != isLearnerInFrame ||
        oldDelegate.isCalibrating != isCalibrating;
  }
}
