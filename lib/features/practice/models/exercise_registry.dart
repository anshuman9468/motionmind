import 'package:flutter/material.dart';

import 'skill_biomechanics.dart';

/// The user-facing exercise catalogue.  Display labels intentionally live
/// separately from stable IDs so a UI rename cannot change API/session data.
enum ExerciseCategory { sports, gym }

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.category,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.description,
    required this.cameraPlacement,
    required this.requiredVisibility,
    required this.cameraDistance,
    required this.supportedView,
    required this.measurements,
    required this.requiredLandmarks,
    required this.phases,
    required this.profile,
    required this.scoreSupported,
    required this.temporalSupported,
    required this.bodyOnlyNote,
  });

  final String id;
  final ExerciseCategory category;
  final String name;
  final String shortName;
  final IconData icon;
  final String description;
  final String cameraPlacement;
  final String requiredVisibility;
  final String cameraDistance;
  final String supportedView;
  final List<String> measurements;
  final List<String> requiredLandmarks;
  final List<String> phases;
  final SkillBiomechanicsProfile profile;
  final bool scoreSupported;
  final bool temporalSupported;
  final String bodyOnlyNote;

  String get categoryLabel =>
      category == ExerciseCategory.sports ? 'SPORTS' : 'GYM';
}

/// Single Flutter source of truth for exercise selection, camera setup, and
/// the profile passed into the local rule engine.  Backend IDs mirror this
/// registry in ``backend/app/agents/exercise_profiles.py``.
class ExerciseRegistry {
  ExerciseRegistry._();

  static final List<ExerciseDefinition> all = <ExerciseDefinition>[
    _definition(
      id: 'basketball_shooting',
      category: ExerciseCategory.sports,
      name: 'Basketball Shooting',
      shortName: 'Basketball',
      icon: Icons.sports_basketball_rounded,
      description:
          'Body-only shooting mechanics: set position, arm extension, and landing control.',
      cameraPlacement:
          'Place the phone 3–4 m away at a front or slight side angle. Keep your full body and shooting arm visible.',
      requiredVisibility: 'Shoulders, elbows, wrists, hips, knees, and ankles.',
      cameraDistance:
          'Full body in frame with space above the head and below the feet.',
      supportedView: 'front',
      measurements: const [
        'elbow angle',
        'knee angle',
        'torso inclination',
        'arm extension',
      ],
      requiredLandmarks: const [
        'shoulders',
        'elbows',
        'wrists',
        'hips',
        'knees',
        'ankles',
      ],
      phases: const [
        'SETUP',
        'LOADING',
        'EXTENSION',
        'FOLLOW_THROUGH',
        'RECOVERY',
      ],
      profile: _basketballProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Body mechanics only; ball trajectory, rim contact, and shot result are not measured.',
    ),
    _definition(
      id: 'cricket_batting',
      category: ExerciseCategory.sports,
      name: 'Cricket Batting',
      shortName: 'Cricket',
      icon: Icons.sports_cricket_rounded,
      description:
          'Batting stance and body rotation proxies for a controlled stroke.',
      cameraPlacement:
          'Use a front or 45° view with the full body visible. Keep the camera still at hip height.',
      requiredVisibility: 'Shoulders, hips, knees, ankles, and both arms.',
      cameraDistance:
          'Frame the complete stance and leave room for the follow-through.',
      supportedView: 'front',
      measurements: const [
        'shoulder alignment',
        'hip alignment',
        'torso inclination',
        'arm geometry',
      ],
      requiredLandmarks: const [
        'shoulders',
        'elbows',
        'wrists',
        'hips',
        'knees',
        'ankles',
      ],
      phases: const [
        'STANCE',
        'PREPARATION',
        'SWING_INITIATION',
        'FOLLOW_THROUGH',
        'RECOVERY',
      ],
      profile: _cricketProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Body mechanics only; bat position, ball trajectory, and shot placement are not measured.',
    ),
    _definition(
      id: 'boxing_jab',
      category: ExerciseCategory.sports,
      name: 'Boxing Jab',
      shortName: 'Boxing',
      icon: Icons.sports_martial_arts_rounded,
      description: 'Guard, observable jab extension, and controlled recovery.',
      cameraPlacement:
          'Use a front or 45° view. Keep both shoulders, elbows, wrists, hips, and feet visible.',
      requiredVisibility:
          'Both arms and the torso must remain visible throughout the punch.',
      cameraDistance:
          'Full upper body plus stance in frame; do not crop the hands.',
      supportedView: 'front',
      measurements: const [
        'elbow extension',
        'shoulder alignment',
        'hip rotation proxy',
        'guard recovery',
      ],
      requiredLandmarks: const ['shoulders', 'elbows', 'wrists', 'hips'],
      phases: const ['GUARD', 'PUNCH_INITIATION', 'EXTENSION', 'RECOVERY'],
      profile: _boxingProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Observable body mechanics only; punch force and impact are not measured.',
    ),
    _definition(
      id: 'squat',
      category: ExerciseCategory.gym,
      name: 'Squat',
      shortName: 'Squats',
      icon: Icons.fitness_center_rounded,
      description:
          'Controlled squat depth, torso control, symmetry, and complete repetitions.',
      cameraPlacement:
          'Place the phone to your side at hip height. Keep shoulders, hips, knees, and ankles visible.',
      requiredVisibility: 'Both shoulders, hips, knees, and ankles.',
      cameraDistance:
          'Full body in a side view with room above and below the frame.',
      supportedView: 'side',
      measurements: const [
        'left/right knee angle',
        'hip angle',
        'torso inclination',
        'knee symmetry',
      ],
      requiredLandmarks: const ['shoulders', 'hips', 'knees', 'ankles'],
      phases: const [
        'STANDING',
        'DESCENDING',
        'BOTTOM',
        'ASCENDING',
        'COMPLETED REP',
      ],
      profile: _squatProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Load, bar position, force, and injury risk are not measured from landmarks.',
    ),
    _definition(
      id: 'push_up',
      category: ExerciseCategory.gym,
      name: 'Push-Up',
      shortName: 'Push-Ups',
      icon: Icons.accessibility_new_rounded,
      description:
          'Plank alignment, elbow flexion, controlled bottom position, and press-up cycle.',
      cameraPlacement:
          'Place the phone to your side at floor level. Keep shoulders, hips, elbows, and ankles visible.',
      requiredVisibility: 'Shoulders, elbows, wrists, hips, knees, and ankles.',
      cameraDistance: 'Side view with the entire body and hands in frame.',
      supportedView: 'side',
      measurements: const [
        'elbow angle',
        'hip angle',
        'torso alignment',
        'body-line stability',
      ],
      requiredLandmarks: const [
        'shoulders',
        'elbows',
        'wrists',
        'hips',
        'ankles',
      ],
      phases: const [
        'READY',
        'LOWERING',
        'BOTTOM',
        'PRESSING',
        'COMPLETED REP',
      ],
      profile: _pushUpProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Repetition quality is based on visible body geometry; load and muscle activation are not measured.',
    ),
    _definition(
      id: 'seated_chest_fly',
      category: ExerciseCategory.gym,
      name: 'Seated Chest Fly',
      shortName: 'Seated Chest Fly',
      icon: Icons.airline_seat_recline_normal_rounded,
      description:
          'Seated setup with observable arm opening, closing, and trunk control.',
      cameraPlacement:
          'Use a front or 45° view. Keep the seated torso and both arms visible.',
      requiredVisibility:
          'Shoulders, elbows, wrists, and hips; include the chair or machine only as context.',
      cameraDistance:
          'Frame the seated torso and both hands without cropping the elbows.',
      supportedView: 'front',
      measurements: const [
        'elbow angle',
        'arm spread',
        'shoulder symmetry',
        'torso stability',
      ],
      requiredLandmarks: const ['shoulders', 'elbows', 'wrists', 'hips'],
      phases: const ['READY', 'OPENING', 'OPEN', 'CLOSING', 'COMPLETED REP'],
      profile: _chestFlyProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'Equipment settings, resistance, and load are not inferred.',
    ),
    _definition(
      id: 'tricep_push_up',
      category: ExerciseCategory.gym,
      name: 'Tricep Push-Up',
      shortName: 'Tricep Push-Ups',
      icon: Icons.self_improvement_rounded,
      description:
          'Close-grip push-up body line with observable elbow flexion and extension.',
      cameraPlacement:
          'Use a side view at floor level. Keep both elbows, shoulders, hips, and ankles visible.',
      requiredVisibility: 'Shoulders, elbows, wrists, hips, and ankles.',
      cameraDistance: 'Full body and hands in frame throughout the movement.',
      supportedView: 'side',
      measurements: const [
        'elbow flexion/extension',
        'hip angle',
        'torso alignment',
        'rep timing',
      ],
      requiredLandmarks: const [
        'shoulders',
        'elbows',
        'wrists',
        'hips',
        'ankles',
      ],
      phases: const [
        'READY',
        'LOWERING',
        'BOTTOM',
        'PRESSING',
        'COMPLETED REP',
      ],
      profile: _tricepPushUpProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'The close-grip variation is a body-position proxy; muscle activation is not measured.',
    ),
    _definition(
      id: 'bent_over_row',
      category: ExerciseCategory.gym,
      name: 'Bent-Over Row',
      shortName: 'Bent-Over Row',
      icon: Icons.rowing_rounded,
      description:
          'Bent-over torso control with observable elbow pull and return.',
      cameraPlacement:
          'Use a side or 45° view. Keep the torso, shoulders, elbows, wrists, hips, and knees visible.',
      requiredVisibility: 'Shoulders, elbows, wrists, hips, and knees.',
      cameraDistance:
          'Full upper body and legs in frame; keep the camera stable.',
      supportedView: 'side',
      measurements: const [
        'torso inclination',
        'elbow angle',
        'hip angle',
        'return control',
      ],
      requiredLandmarks: const [
        'shoulders',
        'elbows',
        'wrists',
        'hips',
        'knees',
      ],
      phases: const [
        'READY',
        'ARM_EXTENSION',
        'ROWING',
        'TOP',
        'RETURNING',
        'COMPLETED REP',
      ],
      profile: _rowProfile,
      scoreSupported: true,
      temporalSupported: true,
      bodyOnlyNote:
          'The exercise is treated as a bent-over row; weight, grip force, and back injury risk are not measured.',
    ),
  ];

  static List<ExerciseDefinition> byCategory(ExerciseCategory category) => all
      .where((exercise) => exercise.category == category)
      .toList(growable: false);

  static ExerciseDefinition byId(String id) => all.firstWhere(
    (exercise) => exercise.id == id,
    orElse: () => all.firstWhere((exercise) => exercise.id == 'squat'),
  );

  static ExerciseDefinition? maybeById(String id) {
    for (final exercise in all) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  static ExerciseDefinition _definition({
    required String id,
    required ExerciseCategory category,
    required String name,
    required String shortName,
    required IconData icon,
    required String description,
    required String cameraPlacement,
    required String requiredVisibility,
    required String cameraDistance,
    required String supportedView,
    required List<String> measurements,
    required List<String> requiredLandmarks,
    required List<String> phases,
    required SkillBiomechanicsProfile profile,
    required bool scoreSupported,
    required bool temporalSupported,
    required String bodyOnlyNote,
  }) => ExerciseDefinition(
    id: id,
    category: category,
    name: name,
    shortName: shortName,
    icon: icon,
    description: description,
    cameraPlacement: cameraPlacement,
    requiredVisibility: requiredVisibility,
    cameraDistance: cameraDistance,
    supportedView: supportedView,
    measurements: measurements,
    requiredLandmarks: requiredLandmarks,
    phases: phases,
    profile: profile,
    scoreSupported: scoreSupported,
    temporalSupported: temporalSupported,
    bodyOnlyNote: bodyOnlyNote,
  );
}

const _squatProfile = SkillBiomechanicsProfile(
  skillId: 'squat',
  skillTitle: 'Squat',
  phases: [
    SkillMovementPhase(
      name: 'BOTTOM',
      description: 'Controlled depth with a stable torso.',
      targets: {
        'knee': JointAngleTarget(
          jointName: 'Knee depth',
          targetAngle: 90,
          minAcceptableAngle: 70,
          maxAcceptableAngle: 130,
          increasePrompt: 'Reach your configured depth',
          decreasePrompt: 'Avoid collapsing deeper',
        ),
        'torso': JointAngleTarget(
          jointName: 'Torso inclination',
          targetAngle: 0,
          minAcceptableAngle: 0,
          maxAcceptableAngle: 45,
          increasePrompt: 'Control your torso lean',
          decreasePrompt: 'Keep your chest controlled',
        ),
      },
    ),
  ],
);

const _basketballProfile = SkillBiomechanicsProfile(
  skillId: 'basketball_shooting',
  skillTitle: 'Basketball Shooting',
  phases: [
    SkillMovementPhase(
      name: 'SETUP',
      description: 'Loaded stance with a visible shooting arm.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Shooting elbow',
          targetAngle: 100,
          minAcceptableAngle: 70,
          maxAcceptableAngle: 135,
          increasePrompt: 'Bring the shooting elbow under control',
          decreasePrompt: 'Avoid overextending the shooting elbow',
        ),
      },
    ),
  ],
);

const _cricketProfile = SkillBiomechanicsProfile(
  skillId: 'cricket_batting',
  skillTitle: 'Cricket Batting',
  phases: [
    SkillMovementPhase(
      name: 'STANCE',
      description: 'Stable stance with observable shoulder and hip alignment.',
      targets: {
        'torso': JointAngleTarget(
          jointName: 'Torso inclination',
          targetAngle: 0,
          minAcceptableAngle: 0,
          maxAcceptableAngle: 55,
          increasePrompt: 'Control forward lean',
          decreasePrompt: 'Keep the torso ready',
        ),
      },
    ),
  ],
);

const _boxingProfile = SkillBiomechanicsProfile(
  skillId: 'boxing_jab',
  skillTitle: 'Boxing Jab',
  phases: [
    SkillMovementPhase(
      name: 'GUARD',
      description:
          'Guard, extension, and recovery are evaluated from visible arm geometry.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Punching elbow',
          targetAngle: 150,
          minAcceptableAngle: 100,
          maxAcceptableAngle: 180,
          increasePrompt: 'Extend the jab with control',
          decreasePrompt: 'Keep a relaxed elbow',
        ),
      },
    ),
  ],
);

const _pushUpProfile = SkillBiomechanicsProfile(
  skillId: 'push_up',
  skillTitle: 'Push-Up',
  phases: [
    SkillMovementPhase(
      name: 'BOTTOM',
      description: 'Elbow flexion with a controlled body line.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Elbow angle',
          targetAngle: 90,
          minAcceptableAngle: 45,
          maxAcceptableAngle: 125,
          increasePrompt: 'Lower with control',
          decreasePrompt: 'Avoid locking too early',
        ),
      },
    ),
  ],
);

const _chestFlyProfile = SkillBiomechanicsProfile(
  skillId: 'seated_chest_fly',
  skillTitle: 'Seated Chest Fly',
  phases: [
    SkillMovementPhase(
      name: 'OPEN',
      description: 'Arms open and close without losing seated trunk control.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Arm angle',
          targetAngle: 120,
          minAcceptableAngle: 45,
          maxAcceptableAngle: 175,
          increasePrompt: 'Open the arms under control',
          decreasePrompt: 'Close the arms smoothly',
        ),
      },
    ),
  ],
);

const _tricepPushUpProfile = SkillBiomechanicsProfile(
  skillId: 'tricep_push_up',
  skillTitle: 'Tricep Push-Up',
  phases: [
    SkillMovementPhase(
      name: 'BOTTOM',
      description: 'Close-grip elbow flexion with a stable body line.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Triceps elbow angle',
          targetAngle: 75,
          minAcceptableAngle: 40,
          maxAcceptableAngle: 120,
          increasePrompt: 'Lower with elbows controlled',
          decreasePrompt: 'Press without flaring',
        ),
      },
    ),
  ],
);

const _rowProfile = SkillBiomechanicsProfile(
  skillId: 'bent_over_row',
  skillTitle: 'Bent-Over Row',
  phases: [
    SkillMovementPhase(
      name: 'ROWING',
      description: 'Pull and return while keeping the torso angle controlled.',
      targets: {
        'elbow': JointAngleTarget(
          jointName: 'Rowing elbow angle',
          targetAngle: 85,
          minAcceptableAngle: 35,
          maxAcceptableAngle: 160,
          increasePrompt: 'Pull the elbow back under control',
          decreasePrompt: 'Return without rushing',
        ),
        'torso': JointAngleTarget(
          jointName: 'Torso inclination',
          targetAngle: 45,
          minAcceptableAngle: 15,
          maxAcceptableAngle: 75,
          increasePrompt: 'Keep a stable hinge',
          decreasePrompt: 'Avoid standing up during the row',
        ),
      },
    ),
  ],
);
