import '../models/skill_biomechanics.dart';

/// Debounces the native detector state before it reaches the camera UI and
/// temporal engines. MediaPipe can briefly report BODY_NOT_CLEAR while a
/// person is moving; a single noisy frame must not make the app alternate
/// between "tracking" and "move into frame".
class TrackingStabilityFilter {
  TrackingStabilityFilter({this.lockFrameCount = 2, this.lossFrameCount = 5})
    : assert(lockFrameCount > 0),
      assert(lossFrameCount > 0);

  final int lockFrameCount;
  final int lossFrameCount;

  int _goodFrames = 0;
  int _badFrames = 0;
  bool _locked = false;
  HumanTrackingPayload? _lastStablePayload;

  bool get isLocked => _locked;

  TrackingStabilityResult update(HumanTrackingPayload payload) {
    final candidate = _isLockCandidate(payload);
    if (candidate) {
      _goodFrames++;
      _badFrames = 0;

      final justLocked = !_locked && _goodFrames >= lockFrameCount;
      if (justLocked) _locked = true;
      if (_locked) {
        _lastStablePayload = payload;
        return TrackingStabilityResult(
          displayPayload: payload,
          rawReliable: true,
          locked: true,
          gracePeriod: false,
          shouldProcess: true,
          justLocked: justLocked,
          justLost: false,
        );
      }

      // Do not expose a half-confirmed pose as a stable full-body lock.
      return TrackingStabilityResult(
        displayPayload: _lastStablePayload ?? HumanTrackingPayload.empty(),
        rawReliable: true,
        locked: false,
        gracePeriod: false,
        shouldProcess: false,
        justLocked: false,
        justLost: false,
      );
    }

    _goodFrames = 0;
    _badFrames++;
    if (_locked && _lastStablePayload != null && _badFrames < lossFrameCount) {
      // Keep the last stable visual frame during a short detector dropout,
      // but do not feed stale coordinates into the analysis engine.
      return TrackingStabilityResult(
        displayPayload: _lastStablePayload!,
        rawReliable: false,
        locked: true,
        gracePeriod: true,
        shouldProcess: false,
        justLocked: false,
        justLost: false,
      );
    }

    final justLost = _locked;
    _locked = false;
    _lastStablePayload = null;
    return TrackingStabilityResult(
      displayPayload: payload,
      rawReliable: false,
      locked: false,
      gracePeriod: false,
      // Process the terminal bad frame once so the temporal tracker can
      // explicitly enter its invalid/tracking-lost state.
      shouldProcess: true,
      justLocked: false,
      justLost: justLost,
    );
  }

  void reset() {
    _goodFrames = 0;
    _badFrames = 0;
    _locked = false;
    _lastStablePayload = null;
  }

  static bool _isLockCandidate(HumanTrackingPayload payload) {
    return payload.humanDetected &&
        payload.trackingState == HumanDetectionState.humanLocked &&
        payload.joints.isNotEmpty;
  }
}

class TrackingStabilityResult {
  TrackingStabilityResult.initial()
    : displayPayload = HumanTrackingPayload.empty(),
      rawReliable = false,
      locked = false,
      gracePeriod = false,
      shouldProcess = false,
      justLocked = false,
      justLost = false;

  const TrackingStabilityResult({
    required this.displayPayload,
    required this.rawReliable,
    required this.locked,
    required this.gracePeriod,
    required this.shouldProcess,
    required this.justLocked,
    required this.justLost,
  });

  final HumanTrackingPayload displayPayload;
  final bool rawReliable;
  final bool locked;
  final bool gracePeriod;
  final bool shouldProcess;
  final bool justLocked;
  final bool justLost;
}
