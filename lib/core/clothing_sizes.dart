/// Größentabellen für Motorrad-Bekleidung & Rennbekleidung.
class ClothingSizes {
  ClothingSizes._();

  /// Helm-Größen (mit cm-Angabe).
  static const helmetSizes = [
    'XXS (51-52 cm)',
    'XS (53-54 cm)',
    'S (55-56 cm)',
    'M (57-58 cm)',
    'L (59-60 cm)',
    'XL (61-62 cm)',
    'XXL (63-64 cm)',
    'XXXL (65-66 cm)',
  ];

  /// Jacken/Hosen-Größen (Textil + EU).
  static const clothingSizes = [
    'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL',
    // EU-Größen
    '44', '46', '48', '50', '52', '54', '56', '58', '60', '62', '64',
  ];

  /// Handschuh-Größen.
  static const gloveSizes = [
    'XS (6-6.5)', 'S (7-7.5)', 'M (8-8.5)', 'L (9-9.5)',
    'XL (10-10.5)', 'XXL (11-11.5)', '3XL (12)',
  ];

  /// Schuh/Stiefel-Größen (EU).
  static const shoeSizes = [
    '36', '37', '38', '39', '40', '41', '42', '43',
    '44', '45', '46', '47', '48',
  ];

  /// Lederkombi-Größen.
  static const leatherSuitSizes = [
    '44', '46', '48', '50', '52', '54', '56', '58', '60',
  ];

  /// Knieschleifer-Größen.
  static const kneeSliderSizes = [
    'Einheitsgröße',
  ];

  /// Nierengurt-Größen.
  static const kidneyBeltSizes = [
    'S/M', 'L/XL', 'XXL/3XL',
  ];

  /// Protektoren-Größen.
  static const protectorSizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL',
  ];

  /// Geschlechter.
  static const genders = ['Herren', 'Damen', 'Unisex'];

  /// Gibt die passende Größen-Liste für eine Unterkategorie zurück.
  static List<String> sizesForSubcategory(String subcategory) {
    switch (subcategory) {
      case 'Helme':
      case 'Rennhelme':
        return helmetSizes;
      case 'Jacken':
      case 'Hosen':
      case 'Regenkleidung':
      case 'Sonstige Bekleidung':
      case 'Sonstige Rennbekleidung':
        return clothingSizes;
      case 'Handschuhe':
      case 'Rennhandschuhe':
        return gloveSizes;
      case 'Stiefel / Schuhe':
      case 'Rennstiefel':
        return shoeSizes;
      case 'Lederkombis':
        return leatherSuitSizes;
      case 'Protektoren':
      case 'Rückenprotektoren':
        return protectorSizes;
      case 'Knieschleifer':
        return kneeSliderSizes;
      case 'Nierengurte':
        return kidneyBeltSizes;
      default:
        return clothingSizes; // Fallback
    }
  }

  /// Bekannte Bekleidungs-Marken (Freitext, aber als Vorschläge).
  static const popularBrands = [
    'Alpinestars', 'Dainese', 'Rev\'it', 'Held', 'Büse',
    'IXS', 'Rukka', 'Klim', 'Shoei', 'Arai', 'AGV',
    'HJC', 'Schuberth', 'Shark', 'Nolan', 'X-Lite',
    'Sidi', 'TCX', 'Forma', 'Gaerne', 'Daytona',
    'Spidi', 'Furygan', 'Macna', 'Oxford', 'RST',
    'Bering', 'Richa', 'Modeka', 'Germot', 'Vanucci',
  ];
}
