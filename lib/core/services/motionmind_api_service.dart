import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/practice/models/skill_biomechanics.dart';

/// HTTP client for the MotionMind FastAPI backend.
///
/// For a phone connected over USB, run `adb reverse tcp:8000 tcp:8000` and
/// build with `--dart-define=MOTIONMIND_API_URL=http://127.0.0.1:8000`.
/// For wireless use, the default points at the development laptop's current
/// LAN address; override it with `--dart-define` when that address changes.
class MotionMindApiService {
  static const defaultBaseUrl = String.fromEnvironment(
    'MOTIONMIND_API_URL',
    // The development laptop's current hotspot/LAN address. Override this
    // for another network with --dart-define or use adb reverse over USB.
    defaultValue: 'http://172.20.10.3:8000',
  );

  MotionMindApiService({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// Performs the same health request used by the connection indicator. The
  /// result is intentionally separate from pose analysis: a healthy server
  /// does not imply that a frame was accepted or that technique was scored.
  Future<ApiHealthResult> health() async {
    final data = await _get('/');
    return ApiHealthResult.fromJson(data);
  }

  Future<ApiVisionResult> analyzeVision({
    required String userId,
    required HumanTrackingPayload payload,
  }) async {
    final data = await _post(
      '/agents/vision',
      _poseRequest(userId: userId, payload: payload),
    );
    return ApiVisionResult.fromJson(data);
  }

  Future<ApiBiomechanicsResult> analyzeBiomechanics({
    required String userId,
    required HumanTrackingPayload payload,
  }) async {
    final data = await _post(
      '/agents/biomechanics',
      _poseRequest(userId: userId, payload: payload),
    );
    return ApiBiomechanicsResult.fromJson(data);
  }

  Future<ApiPerformanceResult> evaluatePerformance(
    ApiBiomechanicsResult metrics,
  ) async {
    final data = await _post('/agents/performance', metrics.toJson());
    return ApiPerformanceResult.fromJson(data);
  }

  Future<ApiTemporalResult> analyzeSquatTemporal({
    required String userId,
    required String sessionId,
    required int timestampUs,
    required HumanTrackingPayload payload,
    required ApiBiomechanicsResult biomechanics,
  }) async {
    final temporalLandmarks = payload.landmarks
        .where((landmark) => landmark.index != null)
        .map(
          (landmark) => {
            'index': landmark.index,
            'x': landmark.x,
            'y': landmark.y,
            'z': landmark.z,
            'visibility': landmark.visibility,
            'presence': landmark.presence,
          },
        )
        .toList(growable: false);
    final retainedLandmarks = temporalLandmarks.isNotEmpty
        ? temporalLandmarks
        : _namedJointsAsCanonicalLandmarks(payload.joints);
    final data = await _post('/agents/temporal/squat', {
      'schema_version': payload.schemaVersion,
      'user_id': userId,
      'session_id': sessionId,
      'skill_id': biomechanics.skillId,
      'timestamp_us': timestampUs,
      'subject_view': biomechanics.subjectView,
      'status': biomechanics.status,
      if (biomechanics.measurementConfidence != null)
        'measurement_confidence': biomechanics.measurementConfidence,
      'landmarks': retainedLandmarks,
      if (biomechanics.leftKneeAngle != null)
        'left_knee_angle': biomechanics.leftKneeAngle,
      if (biomechanics.rightKneeAngle != null)
        'right_knee_angle': biomechanics.rightKneeAngle,
      if (biomechanics.leftHipAngle != null)
        'left_hip_angle': biomechanics.leftHipAngle,
      if (biomechanics.rightHipAngle != null)
        'right_hip_angle': biomechanics.rightHipAngle,
      if (biomechanics.torsoInclination != null)
        'torso_inclination': biomechanics.torsoInclination,
      if (biomechanics.bilateralKneeSymmetry != null)
        'bilateral_knee_symmetry': biomechanics.bilateralKneeSymmetry,
    });
    return ApiTemporalResult.fromJson(data);
  }

  Future<void> resetSquatTemporal({
    required String userId,
    required String sessionId,
  }) async {
    await _delete(
      '/agents/temporal/squat/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(sessionId)}',
    );
  }

  Future<ApiTemporalResult> analyzeExerciseTemporal({
    required String userId,
    required String sessionId,
    required HumanTrackingPayload payload,
    required ApiBiomechanicsResult biomechanics,
  }) async {
    final data = await _post('/agents/temporal/analyze', {
      'schema_version': payload.schemaVersion,
      'user_id': userId,
      'session_id': sessionId,
      'skill_id': biomechanics.skillId,
      'timestamp_us': payload.timestampUs,
      'subject_view': biomechanics.subjectView,
      'status': biomechanics.status,
      if (biomechanics.measurementConfidence != null)
        'measurement_confidence': biomechanics.measurementConfidence,
      if (biomechanics.leftElbowAngle != null)
        'left_elbow_angle': biomechanics.leftElbowAngle,
      if (biomechanics.rightElbowAngle != null)
        'right_elbow_angle': biomechanics.rightElbowAngle,
      if (biomechanics.leftHipAngle != null)
        'left_hip_angle': biomechanics.leftHipAngle,
      if (biomechanics.rightHipAngle != null)
        'right_hip_angle': biomechanics.rightHipAngle,
      if (biomechanics.torsoInclination != null)
        'torso_inclination': biomechanics.torsoInclination,
    });
    return ApiTemporalResult.fromJson(data);
  }

  Future<ApiCoachResponse> generateCoachFeedback({
    required List<String> detectedMistakes,
    int? practiceScore,
    String? analysisStatus,
    String? skillId,
    double? qualityScore,
    String? phase,
    String? confidenceStatus,
    List<String> verifiedFindings = const [],
    Map<String, double?> verifiedMeasurements = const {},
  }) async {
    final availableMeasurements = <String, double>{};
    verifiedMeasurements.forEach((key, value) {
      if (value != null) availableMeasurements[key] = value;
    });
    final data = await _post('/agents/coach', {
      'detected_mistakes': detectedMistakes,
      if (practiceScore != null) 'practice_score': practiceScore,
      if (analysisStatus != null) 'analysis_status': analysisStatus,
      if (skillId != null) 'skill_id': skillId,
      if (qualityScore != null) 'quality_score': qualityScore,
      if (phase != null) 'phase': phase,
      if (confidenceStatus != null) 'confidence_status': confidenceStatus,
      'verified_findings': verifiedFindings,
      'verified_measurements': availableMeasurements,
    });
    return ApiCoachResponse.fromJson(data);
  }

  /// Sends a short wellness conversation to the optional Gemini health
  /// companion. The API key remains on the backend; it is never sent by the
  /// mobile app.
  Future<ApiHealthChatResponse> sendHealthChat({
    required String message,
    List<Map<String, String>> history = const [],
    String? context,
  }) async {
    final data = await _post('/agents/health-chat', {
      'message': message,
      if (history.isNotEmpty) 'history': history,
      if (context != null && context.trim().isNotEmpty) 'context': context,
    });
    return ApiHealthChatResponse.fromJson(data);
  }

  Future<ApiRecommendationResult> getRecommendations({
    required List<String> detectedWeaknesses,
    required String experienceLevel,
  }) async {
    final data = await _post('/agents/recommendation', {
      'detected_weaknesses': detectedWeaknesses,
      'experience_level': experienceLevel,
    });
    return ApiRecommendationResult.fromJson(data);
  }

  Future<ApiRoadmapResult> createRoadmap({
    required List<String> preferredSkills,
    required String experienceLevel,
  }) async {
    final data = await _post('/agents/planner', {
      'preferred_skills': preferredSkills,
      'experience_level': experienceLevel,
    });
    return ApiRoadmapResult.fromJson(data);
  }

  Future<ApiTwinProfile> getTwinProfile(String userId) async {
    final data = await _get('/agents/twin/$userId');
    return ApiTwinProfile.fromJson(data);
  }

  Future<ApiTwinProfile> updateTwinProfile({
    required String userId,
    required List<String> recentMistakes,
    required List<int> sessionScores,
  }) async {
    final data = await _post('/agents/twin/update', {
      'user_id': userId,
      'recent_mistakes': recentMistakes,
      'session_scores': sessionScores,
    });
    return ApiTwinProfile.fromJson(data);
  }

  Future<ApiMemoryResult> storeSession(ApiSessionRecord session) async {
    final data = await _post('/agents/memory/store', session.toJson());
    return ApiMemoryResult.fromJson(data);
  }

  Future<ApiHistoryResult> getHistory(String userId) async {
    final data = await _get('/agents/memory/history/$userId');
    return ApiHistoryResult.fromJson(data);
  }

  Map<String, dynamic> _poseRequest({
    required String userId,
    required HumanTrackingPayload payload,
  }) {
    // The backend consumes the canonical MediaPipe indices. Only landmarks
    // actually returned by the native tracker are sent; missing landmarks are
    // omitted so the server can abstain instead of receiving fabricated 0s.
    final landmarks = payload.landmarks
        .where((landmark) => landmark.index != null)
        .map(
          (landmark) => {
            'index': landmark.index,
            'x': landmark.x,
            'y': landmark.y,
            'z': landmark.z,
            'visibility': landmark.visibility,
            'presence': landmark.presence,
          },
        )
        .toList(growable: false);

    final legacyLandmarks = landmarks.isNotEmpty
        ? landmarks
        : _namedJointsAsCanonicalLandmarks(payload.joints);

    return {
      'schema_version': payload.schemaVersion,
      'user_id': userId,
      if (payload.sessionId != null) 'session_id': payload.sessionId,
      'skill_id': payload.skillId ?? 'unknown',
      if (payload.skillName != null) 'skill_name': payload.skillName,
      'landmarks': legacyLandmarks,
      'coordinate_space': payload.coordinateSpace,
      if (payload.frameWidth > 0) 'image_width': payload.frameWidth,
      if (payload.frameHeight > 0) 'image_height': payload.frameHeight,
      if (payload.timestampUs > 0) 'timestamp_us': payload.timestampUs,
      'camera_facing': payload.cameraFacing,
      'subject_view': payload.subjectView,
      if (payload.mirrored != null) 'mirrored': payload.mirrored,
      if (payload.rotationDegrees != null)
        'rotation_degrees': payload.rotationDegrees,
      'human_detected': payload.humanDetected,
      'tracking_state': _trackingStateName(payload.trackingState),
      if (payload.onDeviceQualityScore != null)
        'on_device_quality_score': payload.onDeviceQualityScore,
    };
  }

  String _trackingStateName(HumanDetectionState state) {
    switch (state) {
      case HumanDetectionState.searchingForHuman:
        return 'SEARCHING_FOR_HUMAN';
      case HumanDetectionState.humanLocked:
        return 'HUMAN_LOCKED';
      case HumanDetectionState.bodyNotClear:
        return 'BODY_NOT_CLEAR';
      case HumanDetectionState.multiplePeopleDetected:
        return 'MULTIPLE_PEOPLE_DETECTED';
    }
  }

  List<Map<String, dynamic>> _namedJointsAsCanonicalLandmarks(
    Map<String, Joint3DPoint> joints,
  ) {
    const indices = {
      'head': 0,
      'leftShoulder': 11,
      'rightShoulder': 12,
      'leftElbow': 13,
      'rightElbow': 14,
      'leftWrist': 15,
      'rightWrist': 16,
      'leftHip': 23,
      'rightHip': 24,
      'leftKnee': 25,
      'rightKnee': 26,
      'leftAnkle': 27,
      'rightAnkle': 28,
    };
    return indices.entries
        .where((entry) => joints.containsKey(entry.key))
        .map((entry) {
          final joint = joints[entry.key]!;
          return {
            'index': entry.value,
            'x': joint.x,
            'y': joint.y,
            'z': joint.z,
            'visibility': joint.confidence,
            'presence': joint.presence,
          };
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final stopwatch = Stopwatch()..start();
    _logRequest('GET', uri);
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      final decoded = _decodeResponse(response);
      _logResponse('GET', uri, response, stopwatch);
      return decoded;
    } on TimeoutException {
      _logFailure('GET', uri, 'timeout', stopwatch);
      throw MotionMindApiException('The MotionMind backend timed out.');
    } on http.ClientException catch (error) {
      _logFailure('GET', uri, error.toString(), stopwatch);
      throw MotionMindApiException(
        'Cannot reach the MotionMind backend: $error',
      );
    } on FormatException catch (error) {
      _logFailure('GET', uri, 'invalid JSON: $error', stopwatch);
      throw MotionMindApiException('The backend returned invalid JSON: $error');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final stopwatch = Stopwatch()..start();
    _logRequest('POST', uri, bodyBytes: jsonEncode(body).length);
    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
      final decoded = _decodeResponse(response);
      _logResponse('POST', uri, response, stopwatch);
      return decoded;
    } on TimeoutException {
      _logFailure('POST', uri, 'timeout', stopwatch);
      throw MotionMindApiException('The MotionMind backend timed out.');
    } on http.ClientException catch (error) {
      _logFailure('POST', uri, error.toString(), stopwatch);
      throw MotionMindApiException(
        'Cannot reach the MotionMind backend: $error',
      );
    } on FormatException catch (error) {
      _logFailure('POST', uri, 'invalid JSON: $error', stopwatch);
      throw MotionMindApiException('The backend returned invalid JSON: $error');
    }
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final stopwatch = Stopwatch()..start();
    _logRequest('DELETE', uri);
    try {
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(timeout);
      final decoded = _decodeResponse(response);
      _logResponse('DELETE', uri, response, stopwatch);
      return decoded;
    } on TimeoutException {
      _logFailure('DELETE', uri, 'timeout', stopwatch);
      throw MotionMindApiException('The MotionMind backend timed out.');
    } on http.ClientException catch (error) {
      _logFailure('DELETE', uri, error.toString(), stopwatch);
      throw MotionMindApiException(
        'Cannot reach the MotionMind backend: $error',
      );
    } on FormatException catch (error) {
      _logFailure('DELETE', uri, 'invalid JSON: $error', stopwatch);
      throw MotionMindApiException('The backend returned invalid JSON: $error');
    }
  }

  Map<String, String> get _headers => const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    _log(
      'HTTP ${response.statusCode} ${response.request?.method ?? 'REQUEST'} '
      '${response.request?.url ?? 'unknown'} (${response.bodyBytes.length} bytes)',
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw MotionMindApiException(
        detail ?? 'Backend request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map) {
      throw const MotionMindApiException('Backend response was not an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _logRequest(String method, Uri uri, {int? bodyBytes}) {
    _log('$method $uri${bodyBytes == null ? '' : ' (${bodyBytes} bytes)'}');
  }

  void _logResponse(
    String method,
    Uri uri,
    http.Response response,
    Stopwatch stopwatch,
  ) {
    _log('$method $uri completed in ${stopwatch.elapsedMilliseconds}ms');
  }

  void _logFailure(String method, Uri uri, String reason, Stopwatch stopwatch) {
    _log(
      '$method $uri failed after ${stopwatch.elapsedMilliseconds}ms: $reason',
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[MotionMind API] $message');
  }
}

class MotionMindApiException implements Exception {
  const MotionMindApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiHealthResult {
  const ApiHealthResult({required this.healthy, required this.system});

  factory ApiHealthResult.fromJson(Map<String, dynamic> json) {
    return ApiHealthResult(
      healthy: json['status']?.toString().toLowerCase() == 'healthy',
      system: json['system']?.toString() ?? 'MotionMind backend',
    );
  }

  final bool healthy;
  final String system;
}

class ApiVisionResult {
  const ApiVisionResult({
    required this.status,
    required this.isMoving,
    required this.detectedJointsCount,
    required this.trackingQualityIndex,
    this.reason,
  });

  factory ApiVisionResult.fromJson(Map<String, dynamic> json) {
    return ApiVisionResult(
      status: json['status']?.toString() ?? 'INSUFFICIENT_DATA',
      isMoving: json['is_moving'] as bool?,
      detectedJointsCount:
          (json['detected_landmarks_count'] as num?)?.toInt() ??
          (json['detected_joints_count'] as num?)?.toInt() ??
          0,
      trackingQualityIndex: (json['tracking_quality_index'] as num?)
          ?.toDouble(),
      reason: json['reason']?.toString(),
    );
  }

  final String status;
  final bool? isMoving;
  final int detectedJointsCount;
  final double? trackingQualityIndex;
  final String? reason;
}

class ApiBiomechanicsResult {
  const ApiBiomechanicsResult({
    required this.status,
    required this.dataQualityStatus,
    required this.skillId,
    required this.coordinateSpace,
    required this.subjectView,
    required this.measurementConfidence,
    required this.availableMeasurements,
    required this.unavailableMeasurements,
    required this.reason,
    required this.leftElbowAngle,
    required this.rightElbowAngle,
    required this.leftKneeAngle,
    required this.rightKneeAngle,
    required this.leftHipAngle,
    required this.rightHipAngle,
    required this.torsoInclination,
    required this.bilateralKneeSymmetry,
    this.onDeviceQualityScore,
  });

  factory ApiBiomechanicsResult.fromJson(Map<String, dynamic> json) {
    return ApiBiomechanicsResult(
      status: json['status']?.toString() ?? 'INSUFFICIENT_DATA',
      dataQualityStatus:
          json['data_quality_status']?.toString() ?? 'INSUFFICIENT_DATA',
      skillId: json['skill_id']?.toString() ?? 'unknown',
      coordinateSpace:
          json['coordinate_space']?.toString() ?? 'normalized_image',
      subjectView: json['subject_view']?.toString() ?? 'unknown',
      measurementConfidence: (json['measurement_confidence'] as num?)
          ?.toDouble(),
      availableMeasurements: _stringList(json['available_measurements']),
      unavailableMeasurements: _stringList(json['unavailable_measurements']),
      reason: json['reason']?.toString(),
      leftElbowAngle: (json['left_elbow_angle'] as num?)?.toDouble(),
      rightElbowAngle: (json['right_elbow_angle'] as num?)?.toDouble(),
      leftKneeAngle: (json['left_knee_angle'] as num?)?.toDouble(),
      rightKneeAngle: (json['right_knee_angle'] as num?)?.toDouble(),
      leftHipAngle: (json['left_hip_angle'] as num?)?.toDouble(),
      rightHipAngle: (json['right_hip_angle'] as num?)?.toDouble(),
      torsoInclination: (json['torso_inclination'] as num?)?.toDouble(),
      bilateralKneeSymmetry: (json['bilateral_knee_symmetry'] as num?)
          ?.toDouble(),
      onDeviceQualityScore: (json['on_device_quality_score'] as num?)
          ?.toDouble(),
    );
  }

  final String status;
  final String dataQualityStatus;
  final String skillId;
  final String coordinateSpace;
  final String subjectView;
  final double? measurementConfidence;
  final List<String> availableMeasurements;
  final List<String> unavailableMeasurements;
  final String? reason;
  final double? leftElbowAngle;
  final double? rightElbowAngle;
  final double? leftKneeAngle;
  final double? rightKneeAngle;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? torsoInclination;
  final double? bilateralKneeSymmetry;
  final double? onDeviceQualityScore;

  Map<String, dynamic> toJson() => {
    'status': status,
    'data_quality_status': dataQualityStatus,
    'skill_id': skillId,
    'coordinate_space': coordinateSpace,
    'subject_view': subjectView,
    if (measurementConfidence != null)
      'measurement_confidence': measurementConfidence,
    'available_measurements': availableMeasurements,
    'unavailable_measurements': unavailableMeasurements,
    if (reason != null) 'reason': reason,
    if (leftElbowAngle != null) 'left_elbow_angle': leftElbowAngle,
    if (rightElbowAngle != null) 'right_elbow_angle': rightElbowAngle,
    if (leftKneeAngle != null) 'left_knee_angle': leftKneeAngle,
    if (rightKneeAngle != null) 'right_knee_angle': rightKneeAngle,
    if (leftHipAngle != null) 'left_hip_angle': leftHipAngle,
    if (rightHipAngle != null) 'right_hip_angle': rightHipAngle,
    if (torsoInclination != null) 'torso_inclination': torsoInclination,
    if (bilateralKneeSymmetry != null)
      'bilateral_knee_symmetry': bilateralKneeSymmetry,
    if (onDeviceQualityScore != null)
      'on_device_quality_score': onDeviceQualityScore,
  };
}

class ApiPerformanceResult {
  const ApiPerformanceResult({
    required this.status,
    required this.qualityScore,
    required this.xp,
    required this.isCorrect,
    required this.detectedMistakes,
    required this.verifiedFindings,
    required this.feedbackEligible,
    required this.reason,
    this.scoringMethod,
    this.category,
  });

  factory ApiPerformanceResult.fromJson(Map<String, dynamic> json) {
    return ApiPerformanceResult(
      status: json['status']?.toString() ?? 'INSUFFICIENT_DATA',
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      xp: (json['xp'] as num?)?.toInt(),
      isCorrect: json['is_correct'] as bool?,
      detectedMistakes: _stringList(json['detected_mistakes']),
      verifiedFindings: _stringList(json['verified_findings']),
      feedbackEligible: json['feedback_eligible'] as bool? ?? false,
      reason: json['reason']?.toString(),
      scoringMethod: json['scoring_method']?.toString(),
      category: json['category']?.toString(),
    );
  }

  final String status;
  final double? qualityScore;
  final int? xp;
  final bool? isCorrect;
  final List<String> detectedMistakes;
  final List<String> verifiedFindings;
  final bool feedbackEligible;
  final String? reason;
  final String? scoringMethod;
  final String? category;
}

class ApiTemporalResult {
  const ApiTemporalResult({
    required this.status,
    required this.phase,
    this.phaseLabel,
    required this.repetitionCount,
    required this.completedRep,
    required this.smoothedKneeAngle,
    required this.movementDirection,
    required this.movementSpeedDegreesPerSecond,
    required this.torsoInclination,
    required this.leftHipAngle,
    required this.rightHipAngle,
    required this.bilateralKneeSymmetry,
    required this.feedbackEligible,
    required this.feedback,
    required this.verifiedFindings,
    required this.reason,
    required this.landmarksRetained,
  });

  factory ApiTemporalResult.fromJson(Map<String, dynamic> json) {
    return ApiTemporalResult(
      status: json['status']?.toString() ?? 'INSUFFICIENT_DATA',
      phase: json['phase']?.toString() ?? 'STANDING',
      phaseLabel: json['phase_label']?.toString(),
      repetitionCount: (json['repetition_count'] as num?)?.toInt() ?? 0,
      completedRep: json['completed_rep'] as bool? ?? false,
      smoothedKneeAngle: (json['smoothed_knee_angle'] as num?)?.toDouble(),
      movementDirection: json['movement_direction']?.toString(),
      movementSpeedDegreesPerSecond:
          (json['movement_speed_degrees_per_second'] as num?)?.toDouble(),
      torsoInclination: (json['torso_inclination'] as num?)?.toDouble(),
      leftHipAngle: (json['left_hip_angle'] as num?)?.toDouble(),
      rightHipAngle: (json['right_hip_angle'] as num?)?.toDouble(),
      bilateralKneeSymmetry: (json['bilateral_knee_symmetry'] as num?)
          ?.toDouble(),
      feedbackEligible: json['feedback_eligible'] as bool? ?? false,
      feedback: _stringList(json['feedback']),
      verifiedFindings: _stringList(json['verified_findings']),
      reason: json['reason']?.toString(),
      landmarksRetained: (json['landmarks_retained'] as num?)?.toInt() ?? 0,
    );
  }

  final String status;
  final String phase;
  final String? phaseLabel;
  final int repetitionCount;
  final bool completedRep;
  final double? smoothedKneeAngle;
  final String? movementDirection;
  final double? movementSpeedDegreesPerSecond;
  final double? torsoInclination;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? bilateralKneeSymmetry;
  final bool feedbackEligible;
  final List<String> feedback;
  final List<String> verifiedFindings;
  final String? reason;
  final int landmarksRetained;
}

class ApiCoachResponse {
  const ApiCoachResponse({
    required this.feedbackText,
    required this.audioCues,
    required this.motivation,
  });

  factory ApiCoachResponse.fromJson(Map<String, dynamic> json) {
    return ApiCoachResponse(
      feedbackText: json['feedback_text']?.toString() ?? '',
      audioCues: _stringList(json['audio_cues']),
      motivation: json['motivation']?.toString() ?? '',
    );
  }

  final String feedbackText;
  final List<String> audioCues;
  final String motivation;
}

class ApiHealthChatResponse {
  const ApiHealthChatResponse({
    required this.reply,
    required this.provider,
    required this.safetyNote,
  });

  factory ApiHealthChatResponse.fromJson(Map<String, dynamic> json) {
    return ApiHealthChatResponse(
      reply:
          json['reply']?.toString() ??
          'I could not prepare a health response right now.',
      provider: json['provider']?.toString() ?? 'offline',
      safetyNote:
          json['safety_note']?.toString() ??
          'General wellness information only — not a diagnosis.',
    );
  }

  final String reply;
  final String provider;
  final String safetyNote;
}

class ApiRecommendationResult {
  const ApiRecommendationResult({
    required this.warmups,
    required this.cooldowns,
    required this.targetDrills,
  });

  factory ApiRecommendationResult.fromJson(Map<String, dynamic> json) {
    return ApiRecommendationResult(
      warmups: _stringList(json['warmups']),
      cooldowns: _stringList(json['cooldowns']),
      targetDrills: _stringList(json['target_drills']),
    );
  }

  final List<String> warmups;
  final List<String> cooldowns;
  final List<String> targetDrills;
}

class ApiRoadmapResult {
  const ApiRoadmapResult({
    required this.roadmapSteps,
    required this.lessonTitle,
    required this.lessonFocus,
    required this.lessonTargetScore,
  });

  factory ApiRoadmapResult.fromJson(Map<String, dynamic> json) {
    final lesson = json['lesson_of_the_day'] is Map
        ? Map<String, dynamic>.from(json['lesson_of_the_day'] as Map)
        : const <String, dynamic>{};
    return ApiRoadmapResult(
      roadmapSteps: _stringList(json['roadmap_steps']),
      lessonTitle: lesson['title']?.toString() ?? '',
      lessonFocus: lesson['focus']?.toString() ?? '',
      lessonTargetScore: (lesson['target_score'] as num?)?.toInt() ?? 0,
    );
  }

  final List<String> roadmapSteps;
  final String lessonTitle;
  final String lessonFocus;
  final int lessonTargetScore;
}

class ApiTwinProfile {
  const ApiTwinProfile({
    required this.userId,
    required this.learningSpeed,
    required this.weaknesses,
    required this.predictedDaysToMastery,
  });

  factory ApiTwinProfile.fromJson(Map<String, dynamic> json) {
    return ApiTwinProfile(
      userId: json['user_id']?.toString() ?? '',
      learningSpeed: (json['learning_speed'] as num?)?.toDouble() ?? 1.0,
      weaknesses: _stringList(json['weaknesses']),
      predictedDaysToMastery:
          (json['predicted_days_to_mastery'] as num?)?.toInt() ?? 0,
    );
  }

  final String userId;
  final double learningSpeed;
  final List<String> weaknesses;
  final int predictedDaysToMastery;
}

class ApiSessionRecord {
  const ApiSessionRecord({
    required this.sessionId,
    required this.userId,
    required this.durationSeconds,
    this.calories,
    required this.finalScore,
    required this.mistakesLog,
    this.repetitions,
    this.exerciseId,
    this.category,
    this.trackingQuality,
    this.validFrames,
    this.rejectedFrames,
    this.processingLatencyMs,
    this.confidenceReasons = const [],
    this.verifiedFindings = const [],
    this.cameraFacing,
    this.subjectView,
  });

  final String sessionId;
  final String userId;
  final int durationSeconds;
  final double? calories;
  final int? finalScore;
  final List<String> mistakesLog;
  final int? repetitions;
  final String? exerciseId;
  final String? category;
  final double? trackingQuality;
  final int? validFrames;
  final int? rejectedFrames;
  final double? processingLatencyMs;
  final List<String> confidenceReasons;
  final List<String> verifiedFindings;
  final String? cameraFacing;
  final String? subjectView;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'user_id': userId,
    'duration_seconds': durationSeconds,
    if (calories != null) 'calories': calories,
    if (finalScore != null) 'final_score': finalScore,
    if (repetitions != null) 'repetitions': repetitions,
    'mistakes_log': mistakesLog,
    if (exerciseId != null) 'exercise_id': exerciseId,
    if (category != null) 'category': category,
    if (trackingQuality != null) 'tracking_quality': trackingQuality,
    if (validFrames != null) 'valid_frames': validFrames,
    if (rejectedFrames != null) 'rejected_frames': rejectedFrames,
    if (processingLatencyMs != null)
      'processing_latency_ms': processingLatencyMs,
    if (confidenceReasons.isNotEmpty) 'confidence_reasons': confidenceReasons,
    if (verifiedFindings.isNotEmpty) 'verified_findings': verifiedFindings,
    if (cameraFacing != null) 'camera_facing': cameraFacing,
    if (subjectView != null) 'subject_view': subjectView,
  };
}

class ApiMemoryResult {
  const ApiMemoryResult({
    required this.status,
    required this.totalStoredSessions,
  });

  factory ApiMemoryResult.fromJson(Map<String, dynamic> json) {
    return ApiMemoryResult(
      status: json['status']?.toString() ?? '',
      totalStoredSessions:
          (json['total_stored_sessions'] as num?)?.toInt() ?? 0,
    );
  }

  final String status;
  final int totalStoredSessions;
}

class ApiHistoryResult {
  const ApiHistoryResult({
    required this.userId,
    required this.cumulativeScore,
    required this.mostCommonMistakes,
  });

  factory ApiHistoryResult.fromJson(Map<String, dynamic> json) {
    return ApiHistoryResult(
      userId: json['user_id']?.toString() ?? '',
      cumulativeScore: (json['cumulative_score'] as num?)?.toInt() ?? 0,
      mostCommonMistakes: _stringList(json['most_common_mistakes']),
    );
  }

  final String userId;
  final int cumulativeScore;
  final List<String> mostCommonMistakes;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
