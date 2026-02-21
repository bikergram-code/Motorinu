import 'package:flutter/material.dart';

@immutable
class ExperienceBadge {
  final String title;
  final String icon;
  final String comment;
  final Color color;

  const ExperienceBadge({
    required this.title,
    required this.icon,
    required this.comment,
    required this.color,
  });
}

@immutable
class LicenseBuildResult {
  final ExperienceBadge experience;
  final List<String> extraBadges;
  final int totalXp;

  const LicenseBuildResult({
    required this.experience,
    required this.extraBadges,
    required this.totalXp,
  });
}

class BadgeLogic {
  /// Minimal buildLicense used by bikergram_license_step_widget.dart.
  /// This does NOT award XP. It only creates nice labels for the license.
  static LicenseBuildResult buildLicense({
    required int age,
    required int ridingYears,
    required bool hasTrackExperience,
    required int bikeCount,
    required List<String> diySkills,
  }) {
    final exp = _experienceBadge(ridingYears);

    final extras = <String>[];
    extras.add(_garageBadge(bikeCount));
    if (hasTrackExperience) extras.add('🏁 Track');
    if (diySkills.isNotEmpty) extras.add('🔧 DIY x${diySkills.length}');

    // base XP for license card itself = 0 (your XP comes from BikerRewards and is shown separately)
    return LicenseBuildResult(experience: exp, extraBadges: extras, totalXp: 0);
  }

  static ExperienceBadge _experienceBadge(int years) {
    final y = years.clamp(0, 102);
    if (y >= 70) {
      return const ExperienceBadge(
        title: 'Asphalt-Gott',
        icon: '🏆',
        comment: '70+ Jahre? Du bist Benzin in Menschform. 👑',
        color: Color(0xFFFFD54F),
      );
    }
    if (y >= 50) {
      return const ExperienceBadge(
        title: 'Legende',
        icon: '👑',
        comment: '50+ Jahre – Respekt, Legende!',
        color: Color(0xFFB39DDB),
      );
    }
    if (y >= 20) {
      return const ExperienceBadge(
        title: 'Profi',
        icon: '🛣️',
        comment: 'Kurven kennen deinen Namen.',
        color: Color(0xFF90CAF9),
      );
    }
    if (y >= 5) {
      return const ExperienceBadge(
        title: 'Rider',
        icon: '🏍️',
        comment: 'Du bist auf Temperatur.',
        color: Color(0xFFA5D6A7),
      );
    }
    return const ExperienceBadge(
      title: 'Frischling',
      icon: '🐣',
      comment: 'Alles beginnt mit dem ersten Kilometer.',
      color: Color(0xFFEF9A9A),
    );
  }

  static String _garageBadge(int count) {
    final c = count.clamp(0, 60);
    if (c >= 60) return '🏛️ Museum 60+';
    if (c >= 50) return '🛰️ Intergalaktisch 50+';
    if (c >= 40) return '🏰 Palast 40+';
    if (c >= 30) return '💎 Sammlungs-Gott 30+';
    if (c >= 20) return '🏛️ Museum 20+';
    if (c >= 10) return '🛒 Händler 10+';
    if (c >= 4) return '📦 Sammler 4+';
    if (c == 3) return '👥 Trio Biker';
    if (c == 2) return '🤝 Duo Biker';
    if (c == 1) return '🛵 Solo Rider';
    return '🚶 Noch kein Bike';
  }
}
