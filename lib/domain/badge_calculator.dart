import 'dart:ui';

/// Badge info for display in profile and registration.
class BadgeInfo {
  const BadgeInfo({
    required this.emoji,
    required this.label,
    required this.category,
    required this.color,
    this.years,
  });

  final String emoji;
  final String label;
  final String category; // 'moto', 'car', 'age', 'track'
  final Color color;
  final int? years;

  String get displayText => '$emoji $label';
}

/// Pure calculation class — no state, no Flutter widgets.
/// Computes badges from user profile data.
class BadgeCalculator {
  BadgeCalculator._();

  // ── Motorrad-Erfahrung ──────────────────────────────────────────────

  static const _motoTiers = <int, String>{
    56: 'Mythos',
    41: 'Legende',
    26: 'Asphalt-Veteran',
    16: 'Veteran',
    11: 'Erfahren',
    6: 'Fortgeschritten',
    3: 'Anfaenger',
    0: 'Frischling',
  };

  static const _motoColors = <int, Color>{
    56: Color(0xFFFF6B00), // orange-gold
    41: Color(0xFFFFD700), // gold
    26: Color(0xFFC0C0C0), // silver
    16: Color(0xFF4CAF50), // green
    11: Color(0xFF2196F3), // blue
    6: Color(0xFF9C27B0),  // purple
    3: Color(0xFF607D8B),  // blue-grey
    0: Color(0xFF795548),  // brown
  };

  // ── Auto-Erfahrung ─────────────────────────────────────────────────

  static const _carTiers = <int, String>{
    56: 'Strassen-Mythos',
    41: 'Legende',
    26: 'Strassen-Veteran',
    16: 'Veteran',
    11: 'Erfahren',
    6: 'Routiniert',
    3: 'Anfaenger',
    0: 'Fahranfaenger',
  };

  static const _carColors = <int, Color>{
    56: Color(0xFFFF6B00),
    41: Color(0xFFFFD700),
    26: Color(0xFFC0C0C0),
    16: Color(0xFF4CAF50),
    11: Color(0xFF2196F3),
    6: Color(0xFF9C27B0),
    3: Color(0xFF607D8B),
    0: Color(0xFF795548),
  };

  // ── Alter-Badges ───────────────────────────────────────────────────

  static const _ageTiers = <int, _AgeTier>{
    76: _AgeTier('\u{1F396}\uFE0F', 'Lebende Legende', Color(0xFFFFD700)),
    66: _AgeTier('\u{1F451}', 'Goldene Aera', Color(0xFFFFD700)),
    56: _AgeTier('\u{1F3C6}', 'Silberpfeil', Color(0xFFC0C0C0)),
    46: _AgeTier('\u2B50', 'Erfahrener Hase', Color(0xFFFFA726)),
    36: _AgeTier('\u{1F525}', 'Prime Rider', Color(0xFFFF5722)),
    26: _AgeTier('\u{1F4AA}', 'Vollgas-Alter', Color(0xFF4CAF50)),
    16: _AgeTier('\u{1F3CD}\uFE0F', 'Young Rider', Color(0xFF2196F3)),
    8: _AgeTier('\u{1F9D2}', 'Jungspund', Color(0xFF9C27B0)),
  };

  // ── Public API ─────────────────────────────────────────────────────

  /// Calculate motorcycle experience in years.
  static int getMotoExperienceYears(int? motoStartAge, int? birthYear) {
    if (motoStartAge == null || birthYear == null) return 0;
    final currentAge = DateTime.now().year - birthYear;
    final years = currentAge - motoStartAge;
    return years.clamp(0, 120);
  }

  /// Calculate car experience in years.
  static int getCarExperienceYears(int? carStartAge, int? birthYear) {
    if (carStartAge == null || birthYear == null) return 0;
    final currentAge = DateTime.now().year - birthYear;
    final years = currentAge - carStartAge;
    return years.clamp(0, 120);
  }

  /// Calculate age from birth year.
  static int getAge(int? birthYear) {
    if (birthYear == null) return 0;
    return DateTime.now().year - birthYear;
  }

  /// Get motorcycle badge info, or null if no moto experience.
  static BadgeInfo? getMotoBadge(int? motoStartAge, int? birthYear) {
    if (motoStartAge == null || birthYear == null) return null;
    final years = getMotoExperienceYears(motoStartAge, birthYear);
    final entry = _findTier(years, _motoTiers);
    final color = _findTierColor(years, _motoColors);
    return BadgeInfo(
      emoji: '\u{1F3CD}\uFE0F',
      label: entry,
      category: 'moto',
      color: color,
      years: years,
    );
  }

  /// Get motorcycle badge label only (for registration preview).
  static String getMotoLabel(int experienceYears) {
    return _findTier(experienceYears, _motoTiers);
  }

  /// Get car badge info, or null if no car experience.
  static BadgeInfo? getCarBadge(int? carStartAge, int? birthYear) {
    if (carStartAge == null || birthYear == null) return null;
    final years = getCarExperienceYears(carStartAge, birthYear);
    final entry = _findTier(years, _carTiers);
    final color = _findTierColor(years, _carColors);
    return BadgeInfo(
      emoji: '\u{1F697}',
      label: entry,
      category: 'car',
      color: color,
      years: years,
    );
  }

  /// Get car badge label only (for registration preview).
  static String getCarLabel(int experienceYears) {
    return _findTier(experienceYears, _carTiers);
  }

  /// Get age badge info.
  static BadgeInfo? getAgeBadge(int? birthYear) {
    if (birthYear == null) return null;
    final age = getAge(birthYear);
    if (age < 8) return null;
    final tier = _findAgeTier(age);
    if (tier == null) return null;
    return BadgeInfo(
      emoji: tier.emoji,
      label: tier.label,
      category: 'age',
      color: tier.color,
      years: age,
    );
  }

  /// Get age badge label only (for registration preview).
  static String? getAgeLabel(int age) {
    final tier = _findAgeTier(age);
    return tier?.label;
  }

  /// Get age badge emoji only.
  static String? getAgeEmoji(int age) {
    final tier = _findAgeTier(age);
    return tier?.emoji;
  }

  /// Get track badge info, or null if no track experience.
  static BadgeInfo? getTrackBadge(bool hasTrackExperience) {
    if (!hasTrackExperience) return null;
    return const BadgeInfo(
      emoji: '\u{1F3C1}',
      label: 'Track Racer',
      category: 'track',
      color: Color(0xFFE53935),
    );
  }

  /// Get all badges for a user profile (used in profile screen).
  static List<BadgeInfo> getAllBadges({
    int? birthYear,
    int? motoStartAge,
    int? carStartAge,
    bool hasTrackExperience = false,
  }) {
    final badges = <BadgeInfo>[];

    final ageBadge = getAgeBadge(birthYear);
    if (ageBadge != null) badges.add(ageBadge);

    final motoBadge = getMotoBadge(motoStartAge, birthYear);
    if (motoBadge != null) badges.add(motoBadge);

    final carBadge = getCarBadge(carStartAge, birthYear);
    if (carBadge != null) badges.add(carBadge);

    final trackBadge = getTrackBadge(hasTrackExperience);
    if (trackBadge != null) badges.add(trackBadge);

    return badges;
  }

  // ── Private helpers ────────────────────────────────────────────────

  static String _findTier(int years, Map<int, String> tiers) {
    for (final entry in tiers.entries) {
      if (years >= entry.key) return entry.value;
    }
    return tiers.values.last;
  }

  static Color _findTierColor(int years, Map<int, Color> colors) {
    for (final entry in colors.entries) {
      if (years >= entry.key) return entry.value;
    }
    return colors.values.last;
  }

  static _AgeTier? _findAgeTier(int age) {
    for (final entry in _ageTiers.entries) {
      if (age >= entry.key) return entry.value;
    }
    return null;
  }
}

class _AgeTier {
  const _AgeTier(this.emoji, this.label, this.color);
  final String emoji;
  final String label;
  final Color color;
}
