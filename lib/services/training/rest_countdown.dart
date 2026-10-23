/// A rest deadline that remains valid when the app's timers are suspended.
class RestCountdown {
  const RestCountdown({required this.endsAtMs});

  factory RestCountdown.start(int seconds, {int? nowMs}) {
    return RestCountdown(
      endsAtMs:
          (nowMs ?? DateTime.now().millisecondsSinceEpoch) + seconds * 1000,
    );
  }

  /// Older saved sessions contain remaining seconds and a save timestamp.
  factory RestCountdown.restore({
    int? endsAtMs,
    required int remainingSeconds,
    int? savedAtMs,
  }) {
    return RestCountdown(
      endsAtMs:
          endsAtMs ??
          (savedAtMs ?? DateTime.now().millisecondsSinceEpoch) +
              remainingSeconds * 1000,
    );
  }

  final int endsAtMs;

  int remainingSeconds({int? nowMs}) {
    final remainingMs =
        endsAtMs - (nowMs ?? DateTime.now().millisecondsSinceEpoch);
    // Round up so a partial last second is still displayed as one second.
    return remainingMs <= 0 ? 0 : (remainingMs + 999) ~/ 1000;
  }

  RestCountdown extendedBy(int seconds) {
    return RestCountdown(endsAtMs: endsAtMs + seconds * 1000);
  }
}
