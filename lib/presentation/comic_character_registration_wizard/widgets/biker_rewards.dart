import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reward_toast.dart';

/// ONE SOURCE OF TRUTH for rewards.
///
/// This file intentionally contains ALL methods referenced across your wizard widgets:
/// - getPoints / getBadges
/// - currentAgeSeal / maybePopAgeBadge  (AgeStepWidget)
/// - rideTierLabel / rideTierIcon / maybeRideTierReward (RidingExperienceStepWidget)
/// - bikeTierLabel / bikeTierIcon / maybeBikeTierReward (BikeCountStepWidget)
/// - diyTierLabel / diyTierIcon / maybeDiyTierReward (DiySkillsStepWidget)
/// - awardTrackTrophyOnce (TrackExperienceStepWidget)
///
/// Storage model:
/// - Points are stored as a per-bucket map: { "ride": 110, "bikes": 250, "diy": 50, "track": 150 }
/// - Total points = sum of buckets (no more "always 0 XP").
/// - Badges stored as a unique list of strings.
///
/// Note: XP/Badge *rules* can be adjusted later without breaking build.
class BikerRewards {
  BikerRewards._();

  // Badges list (strings)
  static const _kBadges = 'biker_rewards_badges';

  // Per-bucket points map (string -> int)
  static const _kPointsMap = 'biker_rewards_points_map';

  // Legacy total (optional)
  static const _kPointsLegacy = 'biker_rewards_points';

  // Last shown tiers (avoid toast spam)
  static const _kLastAgeSeal = 'biker_rewards_last_age_seal';
  static const _kLastRideTier = 'biker_rewards_last_ride_tier';
  static const _kLastBikeTier = 'biker_rewards_last_bike_tier';
  static const _kLastDiyTier = 'biker_rewards_last_diy_tier';

  // Track trophy one-time flag
  static const _kTrackTrophyAwarded = 'biker_rewards_track_trophy_awarded';

  // ---------------------------
  // Public API: totals
  // ---------------------------

  static Future<int> getPoints() async {
    final sp = await SharedPreferences.getInstance();
    final map = await _getPointsMap(sp);
    if (map.isNotEmpty) {
      return map.values.fold<int>(0, (a, b) => a + b);
    }
    return sp.getInt(_kPointsLegacy) ?? 0;
  }

  static Future<List<String>> getBadges() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kBadges);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return <String>[];
  }

  static Future<void> resetAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kBadges);
    await sp.remove(_kPointsMap);
    await sp.remove(_kPointsLegacy);
    await sp.remove(_kLastAgeSeal);
    await sp.remove(_kLastRideTier);
    await sp.remove(_kLastBikeTier);
    await sp.remove(_kLastDiyTier);
    await sp.remove(_kTrackTrophyAwarded);
  }

  // ---------------------------
  // Internal storage helpers
  // ---------------------------

  static Future<Map<String, int>> _getPointsMap(SharedPreferences sp) async {
    final raw = sp.getString(_kPointsMap);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      final out = <String, int>{};
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k is String && v is num) out[k] = v.toInt();
        });
      }
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> _setPointsKey(String key, int value) async {
    final sp = await SharedPreferences.getInstance();
    final map = await _getPointsMap(sp);
    map[key] = value;
    await sp.setString(_kPointsMap, jsonEncode(map));
    final total = map.values.fold<int>(0, (a, b) => a + b);
    await sp.setInt(_kPointsLegacy, total);
  }

  static Future<void> _addBadge(String badge) async {
    final sp = await SharedPreferences.getInstance();
    final current = await getBadges();
    if (current.contains(badge)) return;
    final updated = [...current, badge];
    await sp.setString(_kBadges, jsonEncode(updated));
  }

  // ===========================================================================
  // AGE SEALS (AgeStepWidget uses these)
  // ===========================================================================

  static String? currentAgeSeal(int age) {
    final a = age.clamp(8, 110);
    if (a <= 12) return 'Baby Biker';
    if (a <= 17) return 'Pocket Rocket';
    if (a <= 25) return 'Road Ready';
    if (a <= 35) return 'Asphalt Junkie';
    if (a <= 50) return 'Touren Koenig';
    if (a <= 65) return 'Asphalt Veteran';
    if (a <= 79) return 'Oldschool Legend';
    if (a <= 95) return 'Hardcore Biker';
    return 'Grabsteher Biker';
  }

  static Future<void> maybePopAgeBadge(
    BuildContext context, {
    required int age,
    double reservedBottomPx = 120,
  }) async {
    final seal = currentAgeSeal(age);
    if (seal == null) return;

    final sp = await SharedPreferences.getInstance();
    final last = sp.getString(_kLastAgeSeal);
    if (last == seal) return;
    await sp.setString(_kLastAgeSeal, seal);

    RewardToast.show(
      context,
      title: seal,
      subtitle: _ageLine(seal),
      icon: _iconForAgeSeal(seal),
      reservedBottomPx: reservedBottomPx,
      position: RewardToastPosition.top,
    );
  }

  static String _ageLine(String seal) {
    switch (seal) {
      case 'Baby Biker':
        return 'Stutzraeder? Nein. Sturzbuegel! 😄';
      case 'Pocket Rocket':
        return 'Helm sitzt, Ego groesser als Hubraum. 🚀';
      case 'Road Ready':
        return 'Erste Tour geplant. Blinker? Optional. 😉';
      case 'Asphalt Junkie':
        return 'Kaffee? Nein. Benzingespraeche. ☕🏍️';
      case 'Touren Koenig':
        return 'Du kennst jede Passstrasse beim Vornamen. 👑';
      case 'Asphalt Veteran':
        return 'Erfahrung in Kilometern, nicht in Jahren. 🛣️';
      case 'Oldschool Legend':
        return 'Vergaser-Fluesterer. Respekt. 🧔‍♂️';
      case 'Hardcore Biker':
        return 'Regen? Ist nur nasse Luft. 🌧️';
      case 'Grabsteher Biker':
        return 'Ride in Peace – aber erst noch eine Runde! 🪦';
      default:
        return 'Weiter geht’s, Rider. 🤘';
    }
  }

  static IconData _iconForAgeSeal(String seal) {
    switch (seal) {
      case 'Baby Biker':
        return Icons.toys;
      case 'Pocket Rocket':
        return Icons.rocket_launch;
      case 'Road Ready':
        return Icons.verified;
      case 'Asphalt Junkie':
        return Icons.local_cafe;
      case 'Touren Koenig':
        return Icons.emoji_events;
      case 'Asphalt Veteran':
        return Icons.military_tech;
      case 'Oldschool Legend':
        return Icons.workspace_premium;
      case 'Hardcore Biker':
        return Icons.local_fire_department;
      case 'Grabsteher Biker':
        return Icons.church;
      default:
        return Icons.emoji_events;
    }
  }

  // ===========================================================================
  // RIDING EXPERIENCE (0..102) – used by RidingExperienceStepWidget
  // ===========================================================================

  static String rideTierLabel(num years) {
    final y = years.toDouble().clamp(0.0, 102.0);
    if (y < 1) return 'Frischling';
    if (y < 3) return 'Wackelstarter';
    if (y < 7) return 'Strassen-Fuchs';
    if (y < 15) return 'Touren-Talent';
    if (y < 30) return 'Asphalt Veteran';
    if (y < 50) return 'Road Captain';
    if (y < 70) return 'Legende';
    return 'Mythos 70+';
  }

  static IconData rideTierIcon(String tierLabel) {
    switch (tierLabel) {
      case 'Frischling':
        return Icons.spa;
      case 'Wackelstarter':
        return Icons.school;
      case 'Strassen-Fuchs':
        return Icons.directions_bike;
      case 'Touren-Talent':
        return Icons.map;
      case 'Asphalt Veteran':
        return Icons.military_tech;
      case 'Road Captain':
        return Icons.shield;
      case 'Legende':
        return Icons.emoji_events;
      case 'Mythos 70+':
        return Icons.workspace_premium;
      default:
        return Icons.emoji_events;
    }
  }

  /// Pops a toast only when the ride tier changes.
  /// Sets the "ride" points bucket based on tier (overwrites).
  static Future<void> maybeRideTierReward(
    BuildContext context, {
    required num years,
    double reservedBottomPx = 120,
  }) async {
    final label = rideTierLabel(years);
    final sp = await SharedPreferences.getInstance();
    if (sp.getString(_kLastRideTier) == label) return;
    await sp.setString(_kLastRideTier, label);

    final pts = _rideTierPoints(label);
    await _setPointsKey('ride', pts);
    await _addBadge('🏍️ Fahrerfahrung: $label');

    RewardToast.show(
      context,
      title: label,
      subtitle: '+$pts XP Fahrerfahrung',
      icon: rideTierIcon(label),
      reservedBottomPx: reservedBottomPx,
      position: RewardToastPosition.top,
    );
  }

  static int _rideTierPoints(String label) {
    switch (label) {
      case 'Frischling':
        return 0;
      case 'Wackelstarter':
        return 20;
      case 'Strassen-Fuchs':
        return 40;
      case 'Touren-Talent':
        return 70;
      case 'Asphalt Veteran':
        return 110;
      case 'Road Captain':
        return 160;
      case 'Legende':
        return 220;
      case 'Mythos 70+':
        return 320;
      default:
        return 0;
    }
  }

  // ===========================================================================
  // BIKE COUNT (0..60) – used by BikeCountStepWidget
  // ===========================================================================

  static String bikeTierLabel(int bikeCount) {
    final c = bikeCount.clamp(0, 60);
    if (c <= 0) return 'Ohne Bike?';
    if (c == 1) return 'Solo Rider';
    if (c == 2) return 'Duo Biker';
    if (c == 3) return 'Trio Biker';
    if (c <= 4) return 'Sammler';
    if (c <= 9) return 'Garagenboss';
    if (c <= 19) return 'Haendler';
    if (c <= 29) return 'Museum';
    if (c <= 39) return 'Bike-Konzern';
    if (c <= 49) return 'Bike-Imperium';
    if (c <= 59) return 'Legendary Garage';
    return '60er Hall of Fame';
  }

  static IconData bikeTierIcon(String tierLabel) {
    if (tierLabel.contains('Solo')) return Icons.person;
    if (tierLabel.contains('Duo')) return Icons.people;
    if (tierLabel.contains('Trio')) return Icons.groups;
    if (tierLabel.contains('Sammler')) return Icons.collections;
    if (tierLabel.contains('Garagenboss')) return Icons.garage;
    if (tierLabel.contains('Haendler')) return Icons.storefront;
    if (tierLabel.contains('Museum')) return Icons.museum;
    if (tierLabel.contains('Konzern')) return Icons.factory;
    if (tierLabel.contains('Imperium')) return Icons.castle;
    if (tierLabel.contains('Hall of Fame')) return Icons.emoji_events;
    if (tierLabel.contains('Legendary')) return Icons.workspace_premium;
    return Icons.directions_bike;
  }

  /// Pops a toast only when bike tier changes.
  /// Sets "bikes" points bucket = bikeCount*10 (overwrites).
  static Future<void> maybeBikeTierReward(
    BuildContext context, {
    required int bikeCount,
    double reservedBottomPx = 120,
  }) async {
    final label = bikeTierLabel(bikeCount);
    final sp = await SharedPreferences.getInstance();
    if (sp.getString(_kLastBikeTier) == label) return;
    await sp.setString(_kLastBikeTier, label);

    final pts = bikeCount.clamp(0, 60) * 10;
    await _setPointsKey('bikes', pts);
    await _addBadge('🏍️ Garage: $label');

    RewardToast.show(
      context,
      title: label,
      subtitle: '+$pts XP (Bikes: $bikeCount)',
      icon: bikeTierIcon(label),
      reservedBottomPx: reservedBottomPx,
      position: RewardToastPosition.top,
    );
  }

  // ===========================================================================
  // DIY – used by DiySkillsStepWidget
  // ===========================================================================

  static String diyTierLabel(int selectedCount) {
    final c = selectedCount.clamp(0, 99);
    if (c <= 0) return 'Laie';
    if (c == 1) return 'Hobbyschrauber';
    if (c == 2) return 'Werkstatt-Assistant';
    if (c <= 4) return 'Schrauber';
    if (c <= 7) return 'Meister';
    return 'Guru';
  }

  static IconData diyTierIcon(String tier) {
    switch (tier) {
      case 'Laie':
        return Icons.pan_tool_alt;
      case 'Hobbyschrauber':
        return Icons.handyman;
      case 'Werkstatt-Assistant':
        return Icons.build_circle;
      case 'Schrauber':
        return Icons.build;
      case 'Meister':
        return Icons.engineering;
      case 'Guru':
        return Icons.auto_fix_high;
      default:
        return Icons.handyman;
    }
  }

  /// Pops toast only when DIY tier changes.
  /// Sets "diy" points bucket = selectedCount*25 (overwrites).
  static Future<void> maybeDiyTierReward(
    BuildContext context, {
    required int selectedCount,
    double reservedBottomPx = 120,
  }) async {
    final tier = diyTierLabel(selectedCount);
    final sp = await SharedPreferences.getInstance();
    if (sp.getString(_kLastDiyTier) == tier) return;
    await sp.setString(_kLastDiyTier, tier);

    final pts = selectedCount.clamp(0, 20) * 25;
    await _setPointsKey('diy', pts);
    await _addBadge('🔧 DIY: $tier');

    RewardToast.show(
      context,
      title: tier,
      subtitle: '+$pts XP (Skills: $selectedCount)',
      icon: diyTierIcon(tier),
      reservedBottomPx: reservedBottomPx,
      position: RewardToastPosition.top,
    );
  }

  // ===========================================================================
  // TRACK TROPHY – used by TrackExperienceStepWidget
  // ===========================================================================

  /// Call when user selects "hasTrackExperience = true".
  /// This method is signature-flexible to match older calls: awardTrackTrophyOnce(context);
  static Future<void> awardTrackTrophyOnce(
    BuildContext context, {
    bool? hasTrackExperience,
    double reservedBottomPx = 120,
  }) async {
    if (hasTrackExperience == false) return;

    final sp = await SharedPreferences.getInstance();
    final done = sp.getBool(_kTrackTrophyAwarded) ?? false;
    if (done) return;

    await sp.setBool(_kTrackTrophyAwarded, true);

    const pts = 150;
    await _setPointsKey('track', pts);
    await _addBadge('🏁 Track Trophy');

    RewardToast.show(
      context,
      title: 'Track Trophy',
      subtitle: '+$pts XP – Karo-Flagge im Herzen! 🏁',
      icon: Icons.emoji_events,
      reservedBottomPx: reservedBottomPx,
      position: RewardToastPosition.top,
    );
  }
}
