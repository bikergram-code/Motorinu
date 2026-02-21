import 'dart:ui';

/// Zentraler XP-Calculator für das Bikergram Punktesystem.
///
/// Formeln:
/// - Base XP: 1 XP pro km
/// - Distanz-Bonus: pro 1000 km → 100 XP extra
/// - Level: (xp_total ~/ 100) + 1
class XpCalculator {
  XpCalculator._();

  /// 1 XP pro km (abgerundet)
  static int baseXp(double distanceKm) => distanceKm.round();

  /// Bonus: pro 1000 km → 100 XP extra
  /// z.B. 3045 km → floor(3045/1000) * 100 = 300 Bonus
  static int distanceBonus(double distanceKm) =>
      (distanceKm ~/ 1000) * 100;

  /// Gesamt-XP für eine Fahrt (Base + Bonus)
  static int totalXp(double distanceKm) =>
      baseXp(distanceKm) + distanceBonus(distanceKm);

  /// Level-Berechnung aus Gesamt-XP
  static int levelFromXp(int xpTotal) => (xpTotal ~/ 100) + 1;

  /// XP-Fortschritt innerhalb des aktuellen Levels (0.0 - 1.0)
  static double levelProgress(int xpTotal) => (xpTotal % 100) / 100.0;

  /// XP die noch zum nächsten Level fehlen
  static int xpToNextLevel(int xpTotal) => 100 - (xpTotal % 100);

  /// Biker-Level-Namen (deutsch, thematisch)
  static String levelName(int level) {
    if (level >= 50) return 'Legende';
    if (level >= 30) return 'Roadmaster';
    if (level >= 20) return 'Veteran';
    if (level >= 10) return 'Cruiser';
    if (level >= 5) return 'Rider';
    return 'Rookie';
  }

  /// Level-Farbe passend zum Rang
  static Color levelColor(int level) {
    if (level >= 50) return const Color(0xFFFF6B35); // Orange
    if (level >= 30) return const Color(0xFFFFD700); // Gold
    if (level >= 20) return const Color(0xFFC0C0C0); // Silber
    if (level >= 10) return const Color(0xFF4CAF50); // Grün
    if (level >= 5) return const Color(0xFF2196F3); // Blau
    return const Color(0xFFCD7F32); // Bronze
  }
}
