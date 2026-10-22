import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/practice/models/skill_biomechanics.dart';

/// HTTP client for the MotionMind/SkillVerse FastAPI backend.
///
/// For a phone connected over USB, run `adb reverse tcp:8000 tcp:8000` and
/// keep the default URL. For a phone on the same Wi-Fi network, pass a LAN
/// URL with `--dart-define=MOTIONMIND_API_URL=http://<computer-ip>:8000`.
class MotionMindApiService {
  static const defaultBaseUrl = String.fromEnvironment(
    'MOTIONMIND_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
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

  Future<ApiCoachResponse> generateCoachFeedback({
    required List<String> detectedMistakes,
    required int practiceScore,
  }) async {
    final data = await _post('/agents/coach', {
      'detected_mistakes': detectedMistakes,
      'practice_score': practiceScore,
    });
    return ApiCoachResponse.fromJson(data);
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
    // The backend accepts a list of points. Keep the ordering explicit so its
    // current index-based calculations receive shoulder/elbow/wrist/hip data.
    const orderedJoints = [
      'head',
      'leftShoulder',
      'rightShoulder',
      'leftElbow',
      'leftWrist',
      'rightElbow',
      'rightWrist',
      'leftHip',
      'rightHip',
    ];

    return {
      'user_id': userId,
      'keypoints': orderedJoints.map((name) {
        final joint = payload.joints[name];
        return {
          'x': joint?.x ?? 0.0,
          'y': joint?.y ?? 0.0,
          'z': joint?.z ?? 0.0,
          'visibility': joint?.confidence ?? 0.0,
        };
      }).toList(),
      if (payload.onDeviceQualityScore != null)
        'on_device_quality_score': payload.onDeviceQualityScore,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    };
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(timeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw MotionMindApiException('The MotionMind backend timed out.');
    } on http.ClientException catch (error) {
      throw MotionMindApiException(
        'Cannot reach the MotionMind backend: $error',
      );
    } on FormatException catch (error) {
      throw MotionMindApiException('The backend returned invalid JSON: $error');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw MotionMindApiException('The MotionMind backend timed out.');
    } on http.ClientException catch (error) {
      throw MotionMindApiException(
        'Cannot reach the MotionMind backend: $error',
      );
    } on FormatException catch (error) {
      throw MotionMindApiException('The backend returned invalid JSON: $error');
    }
  }

  Map<String, String> get _headers => const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
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
}

class MotionMindApiException implements Exception {
  const MotionMindApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiVisionResult {
  const ApiVisionResult({
    required this.isMoving,
    required this.detectedJointsCount,
    required this.trackingQualityIndex,
  });

  factory ApiVisionResult.fromJson(Map<String, dynamic> json) {
    return ApiVisionResult(
      isMoving: json['is_moving'] as bool? ?? false,
      detectedJointsCount:
          (json['detected_joints_count'] as num?)?.toInt() ?? 0,
      trackingQualityIndex:
          (json['tracking_quality_index'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final bool isMoving;
  final int detectedJointsCount;
  final double trackingQualityIndex;
}

class ApiBiomechanicsResult {
  const ApiBiomechanicsResult({
    required this.elbowAngle,
    required this.backAngle,
    required this.balanceIndex,
    required this.centerOfGravity,
    required this.velocity,
    required this.acceleration,
    required this.efficiency,
    this.onDeviceQualityScore,
  });

  factory ApiBiomechanicsResult.fromJson(Map<String, dynamic> json) {
    final rawCog = json['center_of_gravity'];
    final cog = rawCog is List && rawCog.length >= 2
        ? <double>[(rawCog[0] as num).toDouble(), (rawCog[1] as num).toDouble()]
        : const <double>[0.5, 0.5];
    return ApiBiomechanicsResult(
      elbowAngle: (json['elbow_angle'] as num?)?.toDouble() ?? 0.0,
      backAngle: (json['back_angle'] as num?)?.toDouble() ?? 0.0,
      balanceIndex: (json['balance_index'] as num?)?.toDouble() ?? 0.0,
      centerOfGravity: cog,
      velocity: (json['velocity'] as num?)?.toDouble() ?? 0.0,
      acceleration: (json['acceleration'] as num?)?.toDouble() ?? 0.0,
      efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0.0,
      onDeviceQualityScore: (json['on_device_quality_score'] as num?)
          ?.toDouble(),
    );
  }

  final double elbowAngle;
  final double backAngle;
  final double balanceIndex;
  final List<double> centerOfGravity;
  final double velocity;
  final double acceleration;
  final double efficiency;
  final double? onDeviceQualityScore;

  Map<String, dynamic> toJson() => {
    'elbow_angle': elbowAngle,
    'back_angle': backAngle,
    'balance_index': balanceIndex,
    'center_of_gravity': centerOfGravity,
    'velocity': velocity,
    'acceleration': acceleration,
    'efficiency': efficiency,
    if (onDeviceQualityScore != null)
      'on_device_quality_score': onDeviceQualityScore,
  };
}

class ApiPerformanceResult {
  const ApiPerformanceResult({
    required this.score,
    required this.isCorrect,
    required this.detectedMistakes,
  });

  factory ApiPerformanceResult.fromJson(Map<String, dynamic> json) {
    return ApiPerformanceResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      isCorrect: json['is_correct'] as bool? ?? false,
      detectedMistakes: _stringList(json['detected_mistakes']),
    );
  }

  final int score;
  final bool isCorrect;
  final List<String> detectedMistakes;
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
    required this.calories,
    required this.finalScore,
    required this.mistakesLog,
  });

  final String sessionId;
  final String userId;
  final int durationSeconds;
  final double calories;
  final int finalScore;
  final List<String> mistakesLog;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'user_id': userId,
    'duration_seconds': durationSeconds,
    'calories': calories,
    'final_score': finalScore,
    'mistakes_log': mistakesLog,
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
