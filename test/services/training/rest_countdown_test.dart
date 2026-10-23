import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/training/rest_countdown.dart';

void main() {
  const startedAt = 1000000;

  test(
    'returning from suspension deducts time without any timer callbacks',
    () {
      final rest = RestCountdown.start(90, nowMs: startedAt);

      expect(rest.remainingSeconds(nowMs: startedAt), 90);
      // No countdown updates occur during these 45 seconds in the background.
      expect(rest.remainingSeconds(nowMs: startedAt + 45000), 45);
      expect(rest.remainingSeconds(nowMs: startedAt + 46000), 44);
    },
  );

  test('a rest that expires in the background stays finished on resume', () {
    final rest = RestCountdown.start(60, nowMs: startedAt);

    expect(rest.remainingSeconds(nowMs: startedAt + 60000), 0);
    expect(rest.remainingSeconds(nowMs: startedAt + 120000), 0);
  });

  test(
    'frequent updates and missed callbacks produce the same remaining time',
    () {
      final foreground = RestCountdown.start(90, nowMs: startedAt);
      final background = RestCountdown.start(90, nowMs: startedAt);
      for (var second = 1; second < 45; second++) {
        foreground.remainingSeconds(nowMs: startedAt + second * 1000);
      }

      expect(
        foreground.remainingSeconds(nowMs: startedAt + 45000),
        background.remainingSeconds(nowMs: startedAt + 45000),
      );
      expect(background.remainingSeconds(nowMs: startedAt + 45000), 45);
    },
  );

  test('restoring a saved deadline ignores a stale remaining count', () {
    final rest = RestCountdown.restore(
      endsAtMs: startedAt + 60000,
      remainingSeconds: 60,
      savedAtMs: startedAt + 20000,
    );

    expect(rest.remainingSeconds(nowMs: startedAt + 40000), 20);
    expect(rest.remainingSeconds(nowMs: startedAt + 120000), 0);
  });

  test('older saved sessions subtract the gap since the save timestamp', () {
    final rest = RestCountdown.restore(
      remainingSeconds: 50,
      savedAtMs: startedAt + 10000,
    );

    expect(rest.remainingSeconds(nowMs: startedAt + 40000), 20);
    expect(rest.remainingSeconds(nowMs: startedAt + 120000), 0);
  });

  test('adding 30 seconds preserves time already spent resting', () {
    final rest = RestCountdown.start(60, nowMs: startedAt);
    expect(rest.remainingSeconds(nowMs: startedAt + 20500), 40);

    final extended = rest.extendedBy(30);
    expect(extended.remainingSeconds(nowMs: startedAt + 20500), 70);
    expect(extended.remainingSeconds(nowMs: startedAt + 80000), 10);
    expect(extended.remainingSeconds(nowMs: startedAt + 90000), 0);
  });

  test('partial seconds do not finish the rest early', () {
    final rest = RestCountdown.start(60, nowMs: startedAt);

    expect(rest.remainingSeconds(nowMs: startedAt + 1), 60);
    expect(rest.remainingSeconds(nowMs: startedAt + 59999), 1);
    expect(rest.remainingSeconds(nowMs: startedAt + 60000), 0);
  });
}
