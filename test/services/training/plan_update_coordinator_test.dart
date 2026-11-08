import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/training/plan_update_coordinator.dart';

void main() {
  late int saves;
  late int retries;
  late int programId;
  late Map<String, dynamic> job;
  late List<int> polled;
  late PlanUpdateCoordinator coordinator;

  setUp(() {
    saves = 0;
    retries = 0;
    programId = 337;
    polled = [];
    job = {'job_id': 145, 'status': 'succeeded', 'program_id': 337};
    coordinator = PlanUpdateCoordinator(
      saveProfile: () async {
        saves++;
        return {
          'training_generation': {'job_id': 145},
        };
      },
      readJob: (id) async {
        polled.add(id);
        return {'generation': job};
      },
      retryJob: (id) async {
        expect(id, 145);
        retries++;
        job = {'job_id': 145, 'status': 'succeeded', 'program_id': 337};
      },
      fetchProgram: () async => {'program_id': programId},
      pollInterval: Duration.zero,
      pollTimeout: Duration.zero,
    );
  });

  test('saves profile once and polls the exact job', () async {
    await coordinator.run();
    await coordinator.run();
    expect(saves, 1);
    expect(polled, everyElement(145));
    expect(retries, 0);
  });

  test('failed generation retries without resaving the profile', () async {
    job = {'job_id': 145, 'status': 'running'};
    await expectLater(coordinator.run(), throwsA(isA<TimeoutException>()));
    job = {'job_id': 145, 'status': 'failed', 'retryable': true};
    await coordinator.run();
    expect(saves, 1);
    expect(retries, 1);
  });

  test('poll timeout does not start another generation', () async {
    job = {'job_id': 145, 'status': 'running'};
    await expectLater(coordinator.run(), throwsA(isA<TimeoutException>()));
    await expectLater(coordinator.run(), throwsA(isA<TimeoutException>()));
    expect(saves, 1);
    expect(retries, 0);
  });

  test('restart resumes server job without saving profile', () async {
    coordinator.jobId = 145;
    job = {'job_id': 145, 'status': 'failed', 'retryable': true};
    await coordinator.run();
    expect(saves, 0);
    expect(retries, 1);
  });

  test('coach change blocks retries and keeps newer plan', () async {
    job = {'job_id': 145, 'status': 'superseded'};
    await expectLater(
      coordinator.run(),
      throwsA(
        isA<PlanUpdateException>().having(
          (e) => e.retryable,
          'retryable',
          false,
        ),
      ),
    );
    expect(retries, 0);
  });

  test(
    'legacy failed job requires review instead of blind regeneration',
    () async {
      job = {'job_id': 145, 'status': 'failed', 'retryable': false};
      await expectLater(coordinator.run(), throwsA(isA<PlanUpdateException>()));
      expect(retries, 0);
    },
  );

  test('old program is not accepted as a completed replacement', () async {
    programId = 335;
    await expectLater(coordinator.run(), throwsA(isA<PlanUpdateException>()));
    expect(retries, 0);
  });

  test('success from another job is not accepted', () async {
    job = {'job_id': 144, 'status': 'succeeded', 'program_id': 337};
    await expectLater(coordinator.run(), throwsA(isA<PlanUpdateException>()));
  });

  test(
    'missing job id does not resave or start uncontrolled generation',
    () async {
      coordinator.savedProfile = {};
      await expectLater(coordinator.run(), throwsA(isA<PlanUpdateException>()));
      expect(saves, 0);
      expect(retries, 0);
    },
  );
}
