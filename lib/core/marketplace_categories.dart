import 'package:flutter/material.dart';

/// Zentrale Kategorie-Datenbank für Marktplatz.
/// Wird auch von Garage genutzt für Fahrzeug-Kategorien.
class MarketplaceCategories {
  MarketplaceCategories._();

  // ── Primäre Kategorien (Bike/Auto-fokussiert) ──

  static const primary = <String, _CategoryDef>{
    'Fahrzeuge': _CategoryDef(
      icon: Icons.two_wheeler_rounded,
      subs: [
        // Motorräder
        'Naked Bikes',
        'Sportler / Supersport',
        'Tourer',
        'Chopper / Cruiser',
        'Enduro / Offroad',
        'Supermoto',
        'Roller / Scooter',
        'Oldtimer Motorräder',
        // Autos
        'Autos',
        'Sportwagen',
        'SUV / Geländewagen',
        'Limousine',
        'Kombi',
        'Cabrio',
        'Kleinwagen',
        'Oldtimer Autos',
        // Sonstiges
        'Quads / ATVs',
        'E-Bikes / E-Roller',
        'Wohnmobile / Camper',
        'Anhänger',
        'Sonstige Fahrzeuge',
      ],
    ),
    'Ersatzteile': _CategoryDef(
      icon: Icons.build_rounded,
      subs: [
        'Motor & Getriebe',
        'Bremsen',
        'Auspuff / Abgasanlage',
        'Fahrwerk / Federung',
        'Elektrik / Elektronik',
        'Karosserie / Verkleidung',
        'Reifen & Felgen',
        'Kette / Ritzel / Antrieb',
        'Lenker / Griffe / Spiegel',
        'Beleuchtung',
        'Sonstige Teile',
      ],
    ),
    'Motorrad-Bekleidung': _CategoryDef(
      icon: Icons.checkroom_rounded,
      subs: [
        'Helme',
        'Jacken',
        'Hosen',
        'Handschuhe',
        'Stiefel / Schuhe',
        'Regenkleidung',
        'Protektoren',
        'Nierengurte',
        'Sonstige Bekleidung',
      ],
    ),
    'Rennbekleidung': _CategoryDef(
      icon: Icons.sports_motorsports_rounded,
      subs: [
        'Lederkombis',
        'Rennhelme',
        'Rennhandschuhe',
        'Rennstiefel',
        'Rückenprotektoren',
        'Knieschleifer',
        'Sonstige Rennbekleidung',
      ],
    ),
    'Zubehör': _CategoryDef(
      icon: Icons.backpack_rounded,
      subs: [
        'Koffer / Taschen',
        'Navigation / GPS',
        'Werkzeug',
        'Abdeckungen / Planen',
        'Schlösser / Diebstahlschutz',
        'Kommunikation / Intercom',
        'Kameras / Action Cams',
        'Aufkleber / Styling',
        'Pflege / Reinigung',
        'Sonstiges Zubehör',
      ],
    ),
  };

  // ── Sekundäre Kategorien (Andere) ──

  static const secondary = <String, _CategoryDef>{
    'Elektronik': _CategoryDef(
      icon: Icons.devices_rounded,
      subs: [
        'Smartphones & Tablets',
        'Laptops & PCs',
        'Kameras & Foto',
        'Audio & Kopfhörer',
        'Gaming',
        'Sonstige Elektronik',
      ],
    ),
    'Haus & Garten': _CategoryDef(
      icon: Icons.home_rounded,
      subs: [
        'Möbel',
        'Garten & Outdoor',
        'Werkstatt / Garage',
        'Dekoration',
        'Haushaltsgeräte',
        'Sonstiges',
      ],
    ),
    'Sport & Freizeit': _CategoryDef(
      icon: Icons.fitness_center_rounded,
      subs: [
        'Fitness',
        'Outdoor / Camping',
        'Fahrräder',
        'Wassersport',
        'Wintersport',
        'Sonstige Sportarten',
      ],
    ),
    'Mode & Beauty': _CategoryDef(
      icon: Icons.shopping_bag_rounded,
      subs: [
        'Herrenbekleidung',
        'Damenbekleidung',
        'Schuhe',
        'Uhren & Schmuck',
        'Pflege & Kosmetik',
        'Sonstiges',
      ],
    ),
    'Dienstleistungen': _CategoryDef(
      icon: Icons.handyman_rounded,
      subs: [
        'Reparatur & Wartung',
        'Transport',
        'Tuning',
        'Lackierung',
        'TÜV / Gutachten',
        'Sonstige Dienstleistungen',
      ],
    ),
    'Sonstiges': _CategoryDef(
      icon: Icons.more_horiz_rounded,
      subs: [],
    ),
  };

  /// Alle Kategorien (primär + sekundär).
  static Map<String, _CategoryDef> get all => {...primary, ...secondary};

  /// Hauptkategorie-Namen.
  static List<String> get mainCategoryNames => all.keys.toList();

  /// Primäre Kategorie-Namen.
  static List<String> get primaryNames => primary.keys.toList();

  /// Sekundäre Kategorie-Namen.
  static List<String> get secondaryNames => secondary.keys.toList();

  /// Icon für eine Hauptkategorie.
  static IconData iconFor(String category) =>
      all[category]?.icon ?? Icons.category_rounded;

  /// Unterkategorien für eine Hauptkategorie.
  static List<String> subsFor(String category) =>
      all[category]?.subs ?? [];

  /// Ob eine Kategorie primär (Bike/Auto) ist.
  static bool isPrimary(String category) => primary.containsKey(category);

  /// Ob die Kategorie Fahrzeug-Attribute braucht (Marke, Modell, etc.).
  static bool needsVehicleAttributes(String category) =>
      category == 'Fahrzeuge';

  /// Ob die Kategorie Bekleidungs-Attribute braucht (Größe).
  static bool needsClothingAttributes(String category) =>
      category == 'Motorrad-Bekleidung' || category == 'Rennbekleidung';

  /// Ob die Kategorie Ersatzteil-Attribute braucht (Passend für).
  static bool needsPartAttributes(String category) =>
      category == 'Ersatzteile';

  /// Fahrzeug-Unterkategorien die Motorräder sind (für Marken-Filter).
  static const motorcycleSubs = {
    'Naked Bikes',
    'Sportler / Supersport',
    'Tourer',
    'Chopper / Cruiser',
    'Enduro / Offroad',
    'Supermoto',
    'Roller / Scooter',
    'Oldtimer Motorräder',
    'E-Bikes / E-Roller',
  };

  /// Fahrzeug-Unterkategorien die Autos sind.
  static const carSubs = {
    'Autos',
    'Sportwagen',
    'SUV / Geländewagen',
    'Limousine',
    'Kombi',
    'Cabrio',
    'Kleinwagen',
    'Oldtimer Autos',
    'Wohnmobile / Camper',
  };

  /// Sonstige Fahrzeug-Unterkategorien (weder Moto noch Auto).
  static const otherVehicleSubs = {
    'Quads / ATVs',
    'E-Bikes / E-Roller',
    'Wohnmobile / Camper',
    'Anhänger',
    'Sonstige Fahrzeuge',
  };

  /// Prüft ob eine Unterkat ein Motorrad ist.
  static bool isMotorcycleSub(String? sub) =>
      sub != null && motorcycleSubs.contains(sub);

  /// Prüft ob eine Unterkat ein Auto ist.
  static bool isCarSub(String? sub) =>
      sub != null && carSubs.contains(sub);

  /// Gruppierte Fahrzeug-Unterkategorien für Dropdown-Darstellung.
  static List<({String label, List<String> items})> get vehicleSubGroups => [
    (label: 'Motorräder', items: motorcycleSubs.toList()),
    (label: 'Autos', items: carSubs.toList()),
    (label: 'Sonstiges', items: otherVehicleSubs.toList()),
  ];
}

class _CategoryDef {
  final IconData icon;
  final List<String> subs;

  const _CategoryDef({required this.icon, required this.subs});
}
