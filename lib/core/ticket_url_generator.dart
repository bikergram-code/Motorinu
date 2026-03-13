/// Automatic AWIN affiliate ticket URL generator.
///
/// Generates motorsporttickets.com URLs based on event title/series
/// and wraps them in the AWIN affiliate link format.
/// This way, new events automatically get ticket links — no manual work.
class TicketUrlGenerator {
  TicketUrlGenerator._();

  static const String _awinBase =
      'https://www.awin1.com/cread.php?awinmid=21865&awinaffid=2798180&ued=';
  static const String _ticketBase = 'https://motorsporttickets.com/en';

  /// Generate an affiliate ticket URL from the event title.
  /// Returns `null` if the series can't be detected.
  static String? fromTitle(String title) {
    final lower = title.toLowerCase().trim();

    // Detect series and generate destination URL
    String? destination;

    if (lower.startsWith('motogp')) {
      final slug = _extractGpSlug(title, 'MotoGP');
      if (slug != null) {
        destination = '$_ticketBase/motogp/$slug';
      }
    } else if (lower.startsWith('f1') || lower.startsWith('formel 1')) {
      var slug = _extractGpSlug(title, lower.startsWith('f1') ? 'F1' : 'Formel 1');
      // F1-specific slug overrides
      if (slug == 'netherlands') slug = 'dutch';
      if (slug != null) {
        destination = '$_ticketBase/f1/$slug';
      }
    } else if (lower.startsWith('wsbk') || lower.startsWith('superbike')) {
      // WSBK has no per-event pages, use landing page
      destination = '$_ticketBase/worldsbk';
    } else if (lower.startsWith('dtm')) {
      destination = '$_ticketBase/dtm';
    } else if (lower.contains('isle of man') || lower.contains('iom tt') || lower.contains('tt 20')) {
      destination = '$_ticketBase/tt/iomtt';
    } else if (lower.contains('24h le mans') || lower.contains('le mans')) {
      destination = '$_ticketBase/wec/le-mans-24';
    } else if (lower.contains('24h n') || lower.contains('nuerburgring') || lower.contains('nürburgring')) {
      destination = '$_ticketBase/endurance/nurburgring24';
    } else if (lower.contains('moto2') || lower.contains('moto3')) {
      // Moto2/Moto3 races are at MotoGP events
      final slug = _extractGpSlug(title, lower.contains('moto2') ? 'Moto2' : 'Moto3');
      if (slug != null) {
        destination = '$_ticketBase/motogp/$slug';
      }
    }

    if (destination == null) return null;

    // URL-encode the destination and wrap in AWIN link
    final encoded = Uri.encodeComponent(destination);
    return '$_awinBase$encoded';
  }

  /// Get the effective ticket URL: use DB-stored URL if available,
  /// otherwise auto-generate from title.
  static String? resolveTicketUrl(String? storedUrl, String title) {
    if (storedUrl != null && storedUrl.isNotEmpty) return storedUrl;
    return fromTitle(title);
  }

  // ── Slug extraction helpers ──

  /// Extract country slug from GP-style titles like "MotoGP - Spanish GP"
  static String? _extractGpSlug(String title, String prefix) {
    // Remove prefix and " - " separator
    var name = title;
    final dashIndex = name.indexOf(' - ');
    if (dashIndex >= 0) {
      name = name.substring(dashIndex + 3).trim();
    } else {
      name = name.substring(prefix.length).trim();
    }

    // Remove "GP" suffix
    name = name.replaceAll(RegExp(r'\s*GP\s*$', caseSensitive: false), '').trim();

    // Map common names to URL slugs
    return _countryToSlug(name);
  }

  /// Extract circuit slug from titles like "WSBK - Phillip Island"
  static String? _extractCircuitSlug(String title, String prefix) {
    var name = title;
    final dashIndex = name.indexOf(' - ');
    if (dashIndex >= 0) {
      name = name.substring(dashIndex + 3).trim();
    } else {
      name = name.substring(prefix.length).trim();
    }

    // Convert to URL-friendly slug
    return _slugify(name);
  }

  /// Map country/track names to URL slugs
  static String? _countryToSlug(String name) {
    final lower = name.toLowerCase().trim();

    const mapping = <String, String>{
      // Countries / GP names
      'thai': 'thailand',
      'thailand': 'thailand',
      'brazilian': 'brazil',
      'brazil': 'brazil',
      'americas': 'americas',
      'qatar': 'qatar',
      'spanish': 'spain',
      'spain': 'spain',
      'french': 'france',
      'france': 'france',
      'catalan': 'catalunya',
      'catalonia': 'catalunya',
      'catalunya': 'catalunya',
      'italian': 'italy',
      'italy': 'italy',
      'hungarian': 'hungary',
      'hungary': 'hungary',
      'czech': 'czech-republic',
      'czech republic': 'czech-republic',
      'dutch': 'netherlands',
      'dutch tt': 'netherlands',
      'netherlands': 'netherlands',
      'german': 'germany',
      'germany': 'germany',
      'british': 'britain',
      'britain': 'britain',
      'aragon': 'aragon',
      'san marino': 'san-marino',
      'austrian': 'austria',
      'austria': 'austria',
      'japanese': 'japan',
      'japan': 'japan',
      'indonesian': 'indonesia',
      'indonesia': 'indonesia',
      'australian': 'australia',
      'australia': 'australia',
      'malaysian': 'malaysia',
      'malaysia': 'malaysia',
      'portuguese': 'portugal',
      'portugal': 'portugal',
      'valencia': 'valencia',
      'chinese': 'china',
      'china': 'china',
      'bahrain': 'bahrain',
      'saudi arabian': 'saudi-arabia',
      'saudi arabia': 'saudi-arabia',
      'miami': 'miami',
      'canadian': 'canada',
      'canada': 'canada',
      'monaco': 'monaco',
      'belgian': 'belgium',
      'belgium': 'belgium',
      'madrid': 'madrid',
      'azerbaijan': 'azerbaijan',
      'singapore': 'singapore',
      'us': 'united-states',
      'united states': 'united-states',
      'mexican': 'mexico',
      'mexico': 'mexico',
      'las vegas': 'las-vegas',
      'abu dhabi': 'abu-dhabi',
    };

    // Direct match
    if (mapping.containsKey(lower)) return mapping[lower];

    // Partial match
    for (final entry in mapping.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Fallback: slugify the name
    return _slugify(name);
  }

  /// Convert any string to a URL-friendly slug
  static String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[äÄ]'), 'ae')
        .replaceAll(RegExp(r'[öÖ]'), 'oe')
        .replaceAll(RegExp(r'[üÜ]'), 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }
}
