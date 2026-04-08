import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Zentraler XP-Calculator für das Bikergram Punktesystem.
///
/// XP-Tabelle:
/// - Fahrt: 1 XP pro km + 100 Bonus pro 1000km
/// - Post erstellen: +5
/// - Like geben: +1
/// - Like bekommen: +2
/// - Kommentar: +2
/// - Story-Like: +1
/// - Story-Kommentar: +2
/// - Follower gewinnen: +2
/// - Marktplatz-Verkauf: +10
/// - Daily Login: +3
/// - 7-Tage-Streak: +50
/// - 30-Tage-Streak: +200
///
/// Level: (xp_total ~/ 100) + 1
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

  // ── XP Award Constants ──
  static const int xpLikeGiven = 1;
  static const int xpLikeReceived = 2;
  static const int xpComment = 2;
  static const int xpStoryLike = 1;
  static const int xpStoryComment = 2;
  static const int xpNewFollower = 2;
  static const int xpPostCreated = 5;
  static const int xpMarketplaceSale = 10;
  static const int xpDailyLogin = 3;
  static const int xpStreak7 = 50;
  static const int xpStreak30 = 200;

  /// Zentrale XP-Vergabe: aktualisiert profiles.xp_total + level,
  /// loggt in xp_transactions. Fire-and-forget, Fehler werden geloggt.
  static Future<void> awardXp(String userId, int amount, String reason) async {
    if (amount <= 0 || userId.isEmpty) return;
    try {
      final sb = Supabase.instance.client;
      // 1. Aktuelles XP laden
      final profile = await sb
          .from('profiles')
          .select('xp_total')
          .eq('id', userId)
          .single();
      final oldXp = profile['xp_total'] as int? ?? 0;
      final newXp = oldXp + amount;
      final newLevel = levelFromXp(newXp);

      // 2. Profil updaten
      await sb.from('profiles').update({
        'xp_total': newXp,
        'level': newLevel,
      }).eq('id', userId);

      // 3. Transaction loggen
      await sb.from('xp_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'reason': reason,
      });

      debugPrint('[XP] +$amount ($reason) → $newXp XP, Level $newLevel');
    } catch (e) {
      debugPrint('[XP] ERROR awarding $amount ($reason) to $userId: $e');
    }
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
