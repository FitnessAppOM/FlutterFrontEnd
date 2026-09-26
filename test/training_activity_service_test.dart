import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/services/training/training_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await TrainingActivityService.stopSession();
  });

  test('mapless cardio remains classified as cardio without metrics', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await TrainingActivityService.startSession(
      exerciseName: 'Indoor Cycling',
      sets: 0,
      reps: 0,
      seconds: 0,
      isCardio: true,
    );

    final session = await TrainingActivityService.getActiveSession();
    expect(session?['kind'], 'cardio');
    expect(session?['distanceKm'], isNull);
    expect(session?['paceMinKm'], isNull);
  });

  test('strength sessions remain classified as strength', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await TrainingActivityService.startSession(
      exerciseName: 'Bench Press',
      sets: 3,
      reps: 10,
      seconds: 0,
    );

    final session = await TrainingActivityService.getActiveSession();
    expect(session?['kind'], 'strength');
  });
}
