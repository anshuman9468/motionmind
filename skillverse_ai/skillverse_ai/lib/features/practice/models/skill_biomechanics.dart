class Joint3DPoint {
  final double x;
  final double y;
  final double z;
  final double confidence;

  const Joint3DPoint({
    required this.x,
    required this.y,
    required this.z,
    this.confidence = 1.0,
  });

  factory Joint3DPoint.fromJson(Map<String, dynamic> json) {
    return Joint3DPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// One canonical MediaPipe Pose landmark. The complete 33-point list is kept
/// alongside the named joints so native inference can be audited and extended
/// without sending camera pixels to the backend.
class MediaPipePoseLandmark {
  const MediaPipePoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    required this.presence,
  });

  factory MediaPipePoseLandmark.fromJson(Map<String, dynamic> json) {
    return MediaPipePoseLandmark(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      visibility: (json['visibility'] as num?)?.toDouble() ?? 0.0,
      presence: (json['presence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;
}

enum HumanDetectionState {
  searchingForHuman,
  humanLocked,
  bodyNotClear,
  multiplePeopleDetected,
}

class HumanTrackingPayload {
  final bool humanDetected;
  final HumanDetectionState trackingState;
  final double trackingConfidence;
  final int multiplePeopleCount;
  final String selectedPersonId;
  final Map<String, Joint3DPoint> joints;
  final List<MediaPipePoseLandmark> landmarks;
  final int frameWidth;
  final int frameHeight;
  final int timestampUs;
  final double? onDeviceQualityScore;

  const HumanTrackingPayload({
    required this.humanDetected,
    required this.trackingState,
    required this.trackingConfidence,
    required this.multiplePeopleCount,
    required this.selectedPersonId,
    required this.joints,
    this.landmarks = const [],
    this.frameWidth = 0,
    this.frameHeight = 0,
    this.timestampUs = 0,
    this.onDeviceQualityScore,
  });

  factory HumanTrackingPayload.empty() {
    return const HumanTrackingPayload(
      humanDetected: false,
      trackingState: HumanDetectionState.searchingForHuman,
      trackingConfidence: 0.0,
      multiplePeopleCount: 0,
      selectedPersonId: 'primary_user_1',
      joints: {},
    );
  }

  factory HumanTrackingPayload.fromJson(Map<String, dynamic> json) {
    final rawStateStr =
        (json['trackingState'] as String?) ?? 'SEARCHING_FOR_HUMAN';
    HumanDetectionState state;
    switch (rawStateStr) {
      case 'HUMAN_LOCKED':
        state = HumanDetectionState.humanLocked;
        break;
      case 'BODY_NOT_CLEAR':
        state = HumanDetectionState.bodyNotClear;
        break;
      case 'MULTIPLE_PEOPLE_DETECTED':
        state = HumanDetectionState.multiplePeopleDetected;
        break;
      default:
        state = HumanDetectionState.searchingForHuman;
    }

    final rawJointsValue = json['joints'];
    final rawJoints = rawJointsValue is Map
        ? Map<String, dynamic>.from(rawJointsValue)
        : <String, dynamic>{};
    final jointsMap = rawJoints.map(
      (k, v) => MapEntry(
        k,
        Joint3DPoint.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    final rawLandmarks = json['landmarks'];
    final landmarks = rawLandmarks is List
        ? rawLandmarks
              .whereType<Map>()
              .map(
                (landmark) => MediaPipePoseLandmark.fromJson(
                  Map<String, dynamic>.from(landmark),
                ),
              )
              .toList(growable: false)
        : const <MediaPipePoseLandmark>[];

    return HumanTrackingPayload(
      humanDetected: (json['humanDetected'] as bool?) ?? false,
      trackingState: state,
      trackingConfidence:
          (json['trackingConfidence'] as num?)?.toDouble() ?? 0.0,
      multiplePeopleCount: (json['multiplePeopleCount'] as num?)?.toInt() ?? 0,
      selectedPersonId:
          (json['selectedPersonId'] as String?) ?? 'primary_user_1',
      joints: jointsMap,
      landmarks: landmarks,
      frameWidth: (json['frameWidth'] as num?)?.toInt() ?? 0,
      frameHeight: (json['frameHeight'] as num?)?.toInt() ?? 0,
      timestampUs: (json['timestampUs'] as num?)?.toInt() ?? 0,
      onDeviceQualityScore: (json['onDeviceQualityScore'] as num?)?.toDouble(),
    );
  }
}

class JointAngleTarget {
  final String jointName;
  final double targetAngle;
  final double minAcceptableAngle;
  final double maxAcceptableAngle;
  final String increasePrompt;
  final String decreasePrompt;

  const JointAngleTarget({
    required this.jointName,
    required this.targetAngle,
    required this.minAcceptableAngle,
    required this.maxAcceptableAngle,
    required this.increasePrompt,
    required this.decreasePrompt,
  });
}

class SkillMovementPhase {
  final String name; // e.g. START, DESCENT, BOTTOM, ASCENT, LOCKOUT
  final String description;
  final Map<String, JointAngleTarget> targets;

  const SkillMovementPhase({
    required this.name,
    required this.description,
    required this.targets,
  });
}

class SkillBiomechanicsProfile {
  final String skillId;
  final String skillTitle;
  final List<SkillMovementPhase> phases;

  const SkillBiomechanicsProfile({
    required this.skillId,
    required this.skillTitle,
    required this.phases,
  });

  /// Repository of skill-specific biomechanical profiles
  static List<SkillBiomechanicsProfile> getAllProfiles() {
    return const [
      SkillBiomechanicsProfile(
        skillId: 'sk_1',
        skillTitle: 'Zeus Bolt: Basketball Jump Shot',
        phases: [
          SkillMovementPhase(
            name: 'SET_UP',
            description: 'Stance flexed, ball brought to chest level',
            targets: {
              'elbow': JointAngleTarget(
                jointName: 'Left Elbow',
                targetAngle: 110,
                minAcceptableAngle: 95,
                maxAcceptableAngle: 125,
                increasePrompt: 'FLEX ELBOW MORE',
                decreasePrompt: 'EXTEND ARM SLIGHTLY',
              ),
              'knee': JointAngleTarget(
                jointName: 'Knee Flexion',
                targetAngle: 125,
                minAcceptableAngle: 110,
                maxAcceptableAngle: 140,
                increasePrompt: 'BEND KNEES DEEPER',
                decreasePrompt: 'RAISE STANCE',
              ),
              'torso': JointAngleTarget(
                jointName: 'Torso Tilt',
                targetAngle: 172,
                minAcceptableAngle: 160,
                maxAcceptableAngle: 180,
                increasePrompt: 'LEAN BACK',
                decreasePrompt: 'LEAN FORWARD',
              ),
            },
          ),
          SkillMovementPhase(
            name: 'RELEASE',
            description: 'High vertical jump, full elbow extension',
            targets: {
              'elbow': JointAngleTarget(
                jointName: 'Left Elbow',
                targetAngle: 165,
                minAcceptableAngle: 150,
                maxAcceptableAngle: 180,
                increasePrompt: 'EXTEND ELBOW FULLY',
                decreasePrompt: 'FLEX ELBOW',
              ),
              'knee': JointAngleTarget(
                jointName: 'Knee Extension',
                targetAngle: 175,
                minAcceptableAngle: 165,
                maxAcceptableAngle: 180,
                increasePrompt: 'PUSH OFF KNEES',
                decreasePrompt: 'SOFTEN LANDING',
              ),
              'torso': JointAngleTarget(
                jointName: 'Torso Verticality',
                targetAngle: 175,
                minAcceptableAngle: 165,
                maxAcceptableAngle: 180,
                increasePrompt: 'ALIGN SPINE',
                decreasePrompt: 'KEEP HEAD ERECT',
              ),
            },
          ),
        ],
      ),
      SkillBiomechanicsProfile(
        skillId: 'sk_sitting',
        skillTitle: 'Sitting Posture & Desk Ergonomics',
        phases: [
          SkillMovementPhase(
            name: 'SITTING_DESK',
            description:
                'Hips and knees at 90°, lumbar supported, neck upright',
            targets: {
              'elbow': JointAngleTarget(
                jointName: 'Desk Arm Angle',
                targetAngle: 95,
                minAcceptableAngle: 80,
                maxAcceptableAngle: 110,
                increasePrompt: 'LOWER DESK REST',
                decreasePrompt: 'RAISE FOREARMS',
              ),
              'knee': JointAngleTarget(
                jointName: 'Sitting Knee Angle',
                targetAngle: 90,
                minAcceptableAngle: 80,
                maxAcceptableAngle: 105,
                increasePrompt: 'ADJUST CHAIR HEIGHT',
                decreasePrompt: 'UN-TUCK FEET',
              ),
              'torso': JointAngleTarget(
                jointName: 'Spine Alignment',
                targetAngle: 175,
                minAcceptableAngle: 165,
                maxAcceptableAngle: 185,
                increasePrompt: 'LEAN BACK 10°',
                decreasePrompt: 'DONT SLOUCH FORWARD',
              ),
            },
          ),
        ],
      ),
      SkillBiomechanicsProfile(
        skillId: 'sk_running',
        skillTitle: 'Running Cadence & Sprint Kinematics',
        phases: [
          SkillMovementPhase(
            name: 'MID_STRIDE',
            description: 'High knee drive, explosive arm swing, forward lean',
            targets: {
              'elbow': JointAngleTarget(
                jointName: 'Arm Swing Angle',
                targetAngle: 85,
                minAcceptableAngle: 75,
                maxAcceptableAngle: 100,
                increasePrompt: 'DRIVE ELBOWS BACK',
                decreasePrompt: 'RELAX SHOULDERS',
              ),
              'knee': JointAngleTarget(
                jointName: 'Lead Knee Drive',
                targetAngle: 115,
                minAcceptableAngle: 95,
                maxAcceptableAngle: 130,
                increasePrompt: 'DRIVE KNEE HIGHER',
                decreasePrompt: 'LOWER STRIDE HEIGHT',
              ),
              'torso': JointAngleTarget(
                jointName: 'Sprint Lean',
                targetAngle: 165,
                minAcceptableAngle: 155,
                maxAcceptableAngle: 175,
                increasePrompt: 'LEAN FORWARD SLIGHTLY',
                decreasePrompt: 'DONT BEND AT WAIST',
              ),
            },
          ),
        ],
      ),
      SkillBiomechanicsProfile(
        skillId: 'sk_jumping',
        skillTitle: 'Vertical Leap & Explosive Jump',
        phases: [
          SkillMovementPhase(
            name: 'DIP_TAKE OFF',
            description: 'Deep crouch, hip load, arm windup',
            targets: {
              'knee': JointAngleTarget(
                jointName: 'Squat Load',
                targetAngle: 110,
                minAcceptableAngle: 95,
                maxAcceptableAngle: 125,
                increasePrompt: 'LOAD KNEES DEEPER',
                decreasePrompt: 'EXPLODE UPWARDS',
              ),
              'torso': JointAngleTarget(
                jointName: 'Chest Load',
                targetAngle: 155,
                minAcceptableAngle: 145,
                maxAcceptableAngle: 168,
                increasePrompt: 'KEEP CHEST UP',
                decreasePrompt: 'DONT HUNCH',
              ),
            },
          ),
        ],
      ),
      SkillBiomechanicsProfile(
        skillId: 'sk_3',
        skillTitle: 'Olympic Barbell Squat',
        phases: [
          SkillMovementPhase(
            name: 'BOTTOM_PARALLEL',
            description: 'Parallel or sub-parallel depth, full tension',
            targets: {
              'knee': JointAngleTarget(
                jointName: 'Knee Depth',
                targetAngle: 90,
                minAcceptableAngle: 80,
                maxAcceptableAngle: 100,
                increasePrompt: 'REACH PARALLEL DEPTH',
                decreasePrompt: 'DONT OVER-SINK',
              ),
              'torso': JointAngleTarget(
                jointName: 'Chest Position',
                targetAngle: 155,
                minAcceptableAngle: 145,
                maxAcceptableAngle: 168,
                increasePrompt: 'STAY UPRIGHT',
                decreasePrompt: 'DONT BEND FORWARD',
              ),
            },
          ),
        ],
      ),
    ];
  }

  static SkillBiomechanicsProfile getProfileForSkill(
    String skillId,
    String skillTitle,
  ) {
    final profiles = getAllProfiles();
    final lowerTitle = skillTitle.toLowerCase();

    if (lowerTitle.contains('sitting') ||
        lowerTitle.contains('desk') ||
        lowerTitle.contains('posture')) {
      return profiles[1];
    } else if (lowerTitle.contains('run') ||
        lowerTitle.contains('sprint') ||
        lowerTitle.contains('cadence')) {
      return profiles[2];
    } else if (lowerTitle.contains('jump') ||
        lowerTitle.contains('vertical') ||
        lowerTitle.contains('leap')) {
      return profiles[3];
    } else if (lowerTitle.contains('squat') ||
        lowerTitle.contains('powerlifting')) {
      return profiles[4];
    }

    return profiles.firstWhere(
      (p) => p.skillId == skillId,
      orElse: () => profiles.first,
    );
  }
}
