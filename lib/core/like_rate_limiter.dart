/// Anti-Spam Rate Limiter für Like/Unlike-Aktionen.
///
/// Nach [maxToggles] hintereinander auf denselben Post wird
/// die Like-Funktion für [lockDuration] gesperrt.
class LikeRateLimiter {
  LikeRateLimiter._();
  static final instance = LikeRateLimiter._();

  /// Max Toggles bevor Sperre greift.
  static const int maxToggles = 3;

  /// Sperre in Sekunden.
  static const int lockSeconds = 90;

  /// postId → Liste der Toggle-Zeitpunkte
  final Map<int, List<DateTime>> _toggleHistory = {};

  /// postId → Sperr-Zeitpunkt (wann die Sperre endet)
  final Map<int, DateTime> _lockedUntil = {};

  /// Prüft ob ein Like-Toggle für diesen Post erlaubt ist.
  /// Gibt `null` zurück wenn erlaubt, sonst die verbleibenden Sekunden.
  int? checkLimit(int postId) {
    // Ist der Post aktuell gesperrt?
    final lockEnd = _lockedUntil[postId];
    if (lockEnd != null) {
      final remaining = lockEnd.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        return remaining;
      }
      // Sperre abgelaufen → aufräumen
      _lockedUntil.remove(postId);
      _toggleHistory.remove(postId);
    }
    return null;
  }

  /// Registriert einen Like-Toggle. Gibt `null` zurück wenn OK,
  /// oder die Sperr-Sekunden wenn das Limit erreicht wurde.
  int? recordToggle(int postId) {
    // Erst prüfen ob schon gesperrt
    final locked = checkLimit(postId);
    if (locked != null) return locked;

    final now = DateTime.now();
    final history = _toggleHistory.putIfAbsent(postId, () => []);

    // Alte Einträge (>90s) entfernen
    history.removeWhere(
      (t) => now.difference(t).inSeconds > lockSeconds,
    );

    history.add(now);

    // Limit erreicht?
    if (history.length >= maxToggles) {
      _lockedUntil[postId] = now.add(const Duration(seconds: lockSeconds));
      _toggleHistory.remove(postId);
      return lockSeconds;
    }

    return null;
  }

  /// Globales Cleanup (optional, z.B. bei Logout).
  void clear() {
    _toggleHistory.clear();
    _lockedUntil.clear();
  }
}
