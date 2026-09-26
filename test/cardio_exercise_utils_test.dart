import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/widgets/cardio/cardio_exercise_utils.dart';

void main() {
  test('indoor cycling activities are mapless', () {
    expect(isIndoorCardioExerciseName('Indoor Cycling'), isTrue);
    expect(isIndoorCardioExerciseName('Stationary Bike'), isTrue);
    expect(isIndoorCardioExerciseName('Spin Bike'), isTrue);
  });

  test('outdoor cycling remains route tracked', () {
    expect(isIndoorCardioExerciseName('Outdoor Cycling'), isFalse);
  });
}
