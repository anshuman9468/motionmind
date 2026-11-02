import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:skillverse_ai/core/services/voice_coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speaks only meaningful tracking transitions and repetitions', () async {
    final fakeTts = _FakeFlutterTts();
    final service = VoiceCoachService(textToSpeech: fakeTts);
    addTearDown(service.dispose);

    expect(await service.initialize(), isTrue);
    await service.handleTrackingUpdate(
      exerciseId: 'squat',
      trackingReady: false,
      evaluationValid: false,
      phase: '',
      repetitions: 0,
      completedRepetition: false,
    );
    await service.handleTrackingUpdate(
      exerciseId: 'squat',
      trackingReady: false,
      evaluationValid: false,
      phase: '',
      repetitions: 0,
      completedRepetition: false,
    );
    expect(fakeTts.spoken, ['Move into frame so I can see your full body.']);

    await service.handleTrackingUpdate(
      exerciseId: 'squat',
      trackingReady: true,
      evaluationValid: true,
      phase: 'STANDING',
      repetitions: 0,
      completedRepetition: false,
    );
    await service.handleTrackingUpdate(
      exerciseId: 'squat',
      trackingReady: true,
      evaluationValid: true,
      phase: 'DESCENDING',
      repetitions: 0,
      completedRepetition: false,
    );
    await service.handleTrackingUpdate(
      exerciseId: 'squat',
      trackingReady: true,
      evaluationValid: true,
      phase: 'ASCENDING',
      repetitions: 1,
      completedRepetition: true,
    );

    expect(
      fakeTts.spoken,
      containsAll(<String>[
        'Tracking ready. Begin when you are ready.',
        'Lower with control.',
        'Rep 1 complete. Nice work.',
      ]),
    );
  });

  group('VoiceCoachCue', () {
    test('provides exercise-specific squat cues', () {
      expect(
        VoiceCoachCue.forPhase('squat', 'DESCENDING'),
        'Lower with control.',
      );
      expect(
        VoiceCoachCue.forPhase('squat', 'BOTTOM'),
        'Hold the bottom, then drive up.',
      );
    });

    test('provides cues for sport and gym profiles', () {
      expect(
        VoiceCoachCue.forPhase('boxing_jab', 'EXTENSION'),
        'Extend the punch under control.',
      );
      expect(
        VoiceCoachCue.forPhase('basketball_shooting', 'FOLLOW_THROUGH'),
        'Hold the follow-through.',
      );
      expect(
        VoiceCoachCue.forPhase('seated_chest_fly', 'OPENING'),
        'Open your arms with control.',
      );
      expect(
        VoiceCoachCue.forPhase('bent_over_row', 'ROWING'),
        'Pull your elbows back.',
      );
    });

    test('does not invent a cue for an unsupported phase', () {
      expect(VoiceCoachCue.forPhase('squat', 'UNKNOWN'), isNull);
      expect(VoiceCoachCue.forPhase('unknown_exercise', 'MOVING'), isNull);
    });
  });
}

class _FakeFlutterTts extends FlutterTts {
  final List<String> spoken = <String>[];

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {}

  @override
  Future<dynamic> setLanguage(String language) async {}

  @override
  Future<dynamic> setSpeechRate(double rate) async {}

  @override
  Future<dynamic> setPitch(double pitch) async {}

  @override
  Future<dynamic> setVolume(double volume) async {}

  @override
  Future<dynamic> setQueueMode(int queueMode) async {}

  @override
  Future<dynamic> stop() async {}

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
  }
}
