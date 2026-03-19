/// In-memory flag: set when training program was just regenerated.
/// Train page should avoid showing cached/old program while waiting
/// for fresh program from network.
class TrainingRegenerationFlag {
  static bool _regenerating = false;

  static void setRegenerating() {
    _regenerating = true;
  }

  static void clear() {
    _regenerating = false;
  }

  static bool get isRegenerating => _regenerating;
}
