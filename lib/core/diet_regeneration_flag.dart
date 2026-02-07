/// In-memory flag: set when training days (or full plan) was just updated,
/// so diet is being regenerated in background. Diet page must not show
/// cached/old targets until new ones are loaded from network.
class DietRegenerationFlag {
  static bool _regenerating = false;
  static DateTime? _setAt;

  static void setRegenerating() {
    _regenerating = true;
    _setAt = DateTime.now();
  }

  static void clear() {
    _regenerating = false;
    _setAt = null;
  }

  static bool get isRegenerating => _regenerating;

  /// Only accept fetched targets after this long, so we don't show old data
  /// that the API might still return while the new diet is generating.
  static const Duration minWaitBeforeAccept = Duration(seconds: 25);

  static bool get canAcceptTargets {
    if (!_regenerating || _setAt == null) return true;
    return DateTime.now().difference(_setAt!) >= minWaitBeforeAccept;
  }
}
