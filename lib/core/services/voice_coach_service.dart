import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Short, on-device voice cues for an active practice session.
///
/// This service deliberately does not call Gemini or wait for the backend.
/// The camera loop can therefore give immediate guidance even when the phone
/// is offline. Only verified tracking events should be passed to it.
class VoiceCoachService {
  VoiceCoachService({FlutterTts? textToSpeech})
    : _textToSpeech = textToSpeech ?? FlutterTts();

  final FlutterTts _textToSpeech;
  Future<void>? _initialization;
  Future<void> _speechQueue = Future<void>.value();
  bool _ready = false;
  bool _enabled = true;
  bool _disposed = false;
  bool? _lastTrackingReady;
  String? _lastPhase;
  int _lastAnnouncedRepetition = 0;
  String? _lastCue;
  DateTime? _lastCueAt;
  DateTime? _lastFeedbackAt;

  bool get isEnabled => _enabled;

  /// Initializes Android TextToSpeech (or the platform equivalent) lazily.
  /// Missing platform engines are treated as unavailable; camera coaching
  /// continues silently instead of failing the practice screen.
  Future<bool> initialize() async {
    if (_disposed) return false;
    if (_ready) return true;
    final activeInitialization = _initialization;
    if (activeInitialization != null) {
      await activeInitialization;
      return _ready;
    }

    final initialization = _configure();
    _initialization = initialization;
    await initialization;
    if (identical(_initialization, initialization)) {
      _initialization = null;
    }
    return _ready;
  }

  Future<void> _configure() async {
    try {
      await _textToSpeech.setLanguage('en-US');
      await _textToSpeech.setSpeechRate(0.48);
      await _textToSpeech.setPitch(1.0);
      await _textToSpeech.setVolume(1.0);
      await _textToSpeech.awaitSpeakCompletion(false);
      // QUEUE_FLUSH prevents stale cues from playing after the user has
      // already changed movement phase. This method is Android-specific, so
      // failure on another platform is harmless.
      try {
        await _textToSpeech.setQueueMode(0);
      } catch (_) {}
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      await stop();
      return;
    }
    await initialize();
  }

  /// Announces only meaningful transitions from the verified temporal engine.
  Future<void> handleTrackingUpdate({
    required String exerciseId,
    required bool trackingReady,
    required bool evaluationValid,
    required String phase,
    required int repetitions,
    required bool completedRepetition,
    String? instruction,
    bool feedbackEligible = false,
  }) async {
    if (!_enabled || _disposed) return;

    if (!trackingReady) {
      if (_lastTrackingReady != false) {
        _lastTrackingReady = false;
        await speakCue(
          'Move into frame so I can see your full body.',
          cooldown: const Duration(seconds: 6),
        );
      }
      return;
    }

    final resumed = _lastTrackingReady != true;
    _lastTrackingReady = true;
    if (resumed) {
      _lastPhase = phase;
      await speakCue(
        'Tracking ready. Begin when you are ready.',
        cooldown: const Duration(seconds: 2),
      );
      return;
    }

    if (repetitions > _lastAnnouncedRepetition || completedRepetition) {
      _lastAnnouncedRepetition = repetitions;
      await speakCue(
        repetitions > 0
            ? 'Rep $repetitions complete. Nice work.'
            : 'Nice work.',
        cooldown: const Duration(milliseconds: 600),
      );
      return;
    }
    _lastAnnouncedRepetition = repetitions;

    final normalizedPhase = phase.trim().toUpperCase();
    if (evaluationValid &&
        normalizedPhase.isNotEmpty &&
        normalizedPhase != _lastPhase) {
      _lastPhase = normalizedPhase;
      final phaseCue = VoiceCoachCue.forPhase(exerciseId, normalizedPhase);
      if (phaseCue != null) {
        await speakCue(phaseCue, cooldown: const Duration(seconds: 2));
        // Let the phase cue finish before considering a separate correction
        // message on a later accepted frame.
        return;
      }
    }

    final cleanInstruction = _cleanInstruction(instruction);
    final now = DateTime.now();
    final feedbackRecentlySpoken =
        _lastFeedbackAt != null &&
        now.difference(_lastFeedbackAt!) < const Duration(seconds: 6);
    if (evaluationValid &&
        feedbackEligible &&
        cleanInstruction != null &&
        !feedbackRecentlySpoken) {
      _lastFeedbackAt = now;
      await speakCue(cleanInstruction, cooldown: const Duration(seconds: 6));
    }
  }

  /// Allows the UI to announce a short session event such as pause/resume.
  Future<void> speakCue(
    String text, {
    Duration cooldown = const Duration(seconds: 3),
  }) async {
    final normalized = _cleanInstruction(text);
    if (!_enabled || _disposed || normalized == null) return;
    final now = DateTime.now();
    if (_lastCue == normalized &&
        _lastCueAt != null &&
        now.difference(_lastCueAt!) < cooldown) {
      return;
    }
    _lastCue = normalized;
    _lastCueAt = now;

    _speechQueue = _speechQueue.then((_) async {
      if (!_enabled || _disposed) return;
      if (!await initialize()) return;
      try {
        await _textToSpeech.stop();
        await _textToSpeech.speak(normalized, focus: true);
      } catch (_) {
        // TTS is optional. A missing voice engine must never break tracking.
        _ready = false;
      }
    });
    await _speechQueue;
  }

  Future<void> stop() async {
    try {
      await _textToSpeech.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _enabled = false;
    await stop();
  }

  static String? _cleanInstruction(String? text) {
    if (text == null) return null;
    final cleaned = text
        .replaceAll('✓', '')
        .replaceAll('•', '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned == 'TRACKING READY') return null;
    // Camera cues must stay short enough to be useful during movement.
    return cleaned.length <= 140 ? cleaned : '${cleaned.substring(0, 137)}...';
  }
}

/// Exercise-aware spoken phase cues. These are intentionally concise and are
/// only emitted after the confidence gate has accepted a frame.
class VoiceCoachCue {
  VoiceCoachCue._();

  static String? forPhase(String exerciseId, String phase) {
    switch (exerciseId) {
      case 'squat':
        switch (phase) {
          case 'DESCENDING':
            return 'Lower with control.';
          case 'BOTTOM':
            return 'Hold the bottom, then drive up.';
          case 'ASCENDING':
            return 'Drive up to a stable stand.';
          case 'STANDING':
            return 'Set your stance.';
        }
      case 'push_up':
      case 'tricep_push_up':
        switch (phase) {
          case 'LOWERING':
            return 'Lower your body with control.';
          case 'BOTTOM':
            return 'Keep your body line steady.';
          case 'PRESSING':
            return 'Press smoothly back to the start.';
          case 'READY':
            return 'Set your plank position.';
        }
      case 'seated_chest_fly':
        switch (phase) {
          case 'OPENING':
            return 'Open your arms with control.';
          case 'OPEN':
            return 'Pause briefly, then close.';
          case 'CLOSING':
            return 'Bring the arms together without swinging.';
          case 'READY':
            return 'Set your seated position.';
        }
      case 'bent_over_row':
        switch (phase) {
          case 'ARM_EXTENSION':
            return 'Reach under control.';
          case 'ROWING':
          case 'TOP':
            return 'Pull your elbows back.';
          case 'RETURNING':
            return 'Lower with a steady torso.';
          case 'READY':
            return 'Set your bent-over position.';
        }
      case 'boxing_jab':
        switch (phase) {
          case 'PUNCH_INITIATION':
            return 'Start the jab smoothly.';
          case 'EXTENSION':
            return 'Extend the punch under control.';
          case 'RECOVERY':
            return 'Return your hands to guard.';
          case 'GUARD':
            return 'Keep a stable guard.';
        }
      case 'basketball_shooting':
        switch (phase) {
          case 'SETUP':
            return 'Set your feet and shoulders.';
          case 'LOADING':
            return 'Load smoothly through your knees.';
          case 'EXTENSION':
            return 'Extend through the shooting motion.';
          case 'FOLLOW_THROUGH':
            return 'Hold the follow-through.';
          case 'RECOVERY':
            return 'Land softly and reset.';
        }
      case 'cricket_batting':
        switch (phase) {
          case 'STANCE':
            return 'Set a balanced stance.';
          case 'PREPARATION':
            return 'Prepare with control.';
          case 'SWING_INITIATION':
            return 'Start the swing smoothly.';
          case 'FOLLOW_THROUGH':
            return 'Finish the follow-through.';
          case 'RECOVERY':
            return 'Return to a balanced stance.';
        }
    }
    return null;
  }
}
