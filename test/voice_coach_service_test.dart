import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_ai/core/services/voice_coach_service.dart';

void main() {
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
