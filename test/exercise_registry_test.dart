import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_ai/features/practice/models/exercise_registry.dart';

void main() {
  test('registry exposes the eight canonical exercise IDs', () {
    expect(
      ExerciseRegistry.all.map((exercise) => exercise.id).toSet(),
      equals({
        'basketball_shooting',
        'cricket_batting',
        'boxing_jab',
        'squat',
        'push_up',
        'seated_chest_fly',
        'tricep_push_up',
        'bent_over_row',
      }),
    );
    expect(ExerciseRegistry.byCategory(ExerciseCategory.sports), hasLength(3));
    expect(ExerciseRegistry.byCategory(ExerciseCategory.gym), hasLength(5));
  });

  test('exercise metadata keeps body-only limitations explicit', () {
    final cricket = ExerciseRegistry.byId('cricket_batting');
    final chestFly = ExerciseRegistry.byId('seated_chest_fly');
    expect(cricket.bodyOnlyNote.toLowerCase(), contains('ball'));
    expect(chestFly.bodyOnlyNote.toLowerCase(), contains('load'));
    expect(ExerciseRegistry.byId('unknown').id, 'squat');
  });
}
