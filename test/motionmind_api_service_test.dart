import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_ai/core/services/motionmind_api_service.dart';
import 'package:skillverse_ai/features/practice/models/skill_biomechanics.dart';

void main() {
  test('health uses the configured backend URL', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({'status': 'Healthy', 'system': 'MotionMind'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = MotionMindApiService(
      client: client,
      baseUrl: 'http://192.168.1.2:8000',
    );

    final health = await service.health();

    expect(health.healthy, isTrue);
    expect(requests.single.url.toString(), 'http://192.168.1.2:8000/');
  });

  test(
    'vision request preserves canonical squat metadata and omits fake joints',
    () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'INSUFFICIENT_DATA',
            'detected_landmarks_count': 0,
            'tracking_quality_index': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = MotionMindApiService(
        client: client,
        baseUrl: 'http://test',
      );
      const payload = HumanTrackingPayload(
        humanDetected: false,
        trackingState: HumanDetectionState.searchingForHuman,
        trackingConfidence: 0,
        multiplePeopleCount: 0,
        selectedPersonId: 'primary_user_1',
        joints: <String, Joint3DPoint>{},
        timestampUs: 123,
        sessionId: 'session-1',
        skillId: 'squat',
        subjectView: 'side',
      );

      await service.analyzeVision(userId: 'user-1', payload: payload);

      expect(body['skill_id'], 'squat');
      expect(body['session_id'], 'session-1');
      expect(body['timestamp_us'], 123);
      expect(body['landmarks'], isEmpty);
      expect(body.containsKey('left_knee_angle'), isFalse);
    },
  );

  test(
    'health chat sends conversation history and parses Gemini response',
    () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'reply': 'Try a gentle cool-down and drink some water.',
            'provider': 'gemini',
            'safety_note':
                'General wellness information only — not a diagnosis.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = MotionMindApiService(
        client: client,
        baseUrl: 'http://test',
      );

      final response = await service.sendHealthChat(
        message: 'How should I recover after training?',
        history: const [
          {'role': 'assistant', 'content': 'How did your session feel?'},
        ],
      );

      expect(body['message'], 'How should I recover after training?');
      expect(body['history'], isA<List<dynamic>>());
      expect(response.provider, 'gemini');
      expect(response.reply, contains('cool-down'));
    },
  );
}
