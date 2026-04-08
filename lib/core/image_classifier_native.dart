import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// On-device Bild-Erkennung via Google ML Kit.
/// Erkennt Objekte auf Fotos und mappt sie auf Marktplatz-Kategorien.
class ImageClassifier {
  ImageClassifier._();

  static ImageLabeler? _labeler;

  static ImageLabeler get _instance {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.4),
    );
    return _labeler!;
  }

  /// Klassifiziert ein Bild und gibt Kategorie + Unterkategorie zurück.
  /// Returns null wenn nichts erkannt wird.
  static Future<ClassificationResult?> classifyImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final labels = await _instance.processImage(inputImage);

      if (labels.isEmpty) return null;

      // Debug: alle Labels loggen
      for (final label in labels) {
        debugPrint('[ImageClassifier] ${label.label} (${(label.confidence * 100).toStringAsFixed(0)}%)');
      }

      // Durch Labels iterieren und bestes Mapping finden
      ClassificationResult? bestMatch;
      double bestScore = 0;

      for (final label in labels) {
        final key = label.label.toLowerCase();
        final mapping = _labelMapping[key];
        if (mapping != null && label.confidence > bestScore) {
          bestMatch = ClassificationResult(
            category: mapping.category,
            subcategory: mapping.subcategory,
            confidence: label.confidence,
            detectedLabel: label.label,
          );
          bestScore = label.confidence;
        }
      }

      return bestMatch;
    } catch (e) {
      debugPrint('[ImageClassifier] Fehler: $e');
      return null;
    }
  }

  /// Aufräumen wenn nicht mehr benötigt.
  static Future<void> dispose() async {
    await _labeler?.close();
    _labeler = null;
  }

  // ══════════════════════════════════════════════
  //  ML Kit Label → Marktplatz-Kategorie Mapping
  // ══════════════════════════════════════════════

  static const _labelMapping = <String, _CategoryMapping>{
    // ── Fahrzeuge ──
    'motorcycle': _CategoryMapping('Fahrzeuge', 'Naked Bikes'),
    'motor vehicle': _CategoryMapping('Fahrzeuge', null),
    'vehicle': _CategoryMapping('Fahrzeuge', null),
    'car': _CategoryMapping('Fahrzeuge', 'Autos'),
    'land vehicle': _CategoryMapping('Fahrzeuge', null),
    'truck': _CategoryMapping('Fahrzeuge', 'Sonstige Fahrzeuge'),
    'bus': _CategoryMapping('Fahrzeuge', 'Sonstige Fahrzeuge'),
    'van': _CategoryMapping('Fahrzeuge', 'Wohnmobile / Camper'),
    'bicycle': _CategoryMapping('Sport & Freizeit', 'Fahrräder'),
    'scooter': _CategoryMapping('Fahrzeuge', 'Roller / Scooter'),
    'quad': _CategoryMapping('Fahrzeuge', 'Quads / ATVs'),

    // ── Ersatzteile ──
    'tire': _CategoryMapping('Ersatzteile', 'Reifen & Felgen'),
    'wheel': _CategoryMapping('Ersatzteile', 'Reifen & Felgen'),
    'rim': _CategoryMapping('Ersatzteile', 'Reifen & Felgen'),
    'engine': _CategoryMapping('Ersatzteile', 'Motor & Getriebe'),
    'exhaust': _CategoryMapping('Ersatzteile', 'Auspuff / Abgasanlage'),
    'brake': _CategoryMapping('Ersatzteile', 'Bremsen'),
    'headlight': _CategoryMapping('Ersatzteile', 'Beleuchtung'),
    'light': _CategoryMapping('Ersatzteile', 'Beleuchtung'),
    'mirror': _CategoryMapping('Ersatzteile', 'Lenker / Griffe / Spiegel'),
    'chain': _CategoryMapping('Ersatzteile', 'Kette / Ritzel / Antrieb'),

    // ── Motorrad-Bekleidung ──
    'helmet': _CategoryMapping('Motorrad-Bekleidung', 'Helme'),
    'headgear': _CategoryMapping('Motorrad-Bekleidung', 'Helme'),
    'jacket': _CategoryMapping('Motorrad-Bekleidung', 'Jacken'),
    'coat': _CategoryMapping('Motorrad-Bekleidung', 'Jacken'),
    'outerwear': _CategoryMapping('Motorrad-Bekleidung', 'Jacken'),
    'leather jacket': _CategoryMapping('Motorrad-Bekleidung', 'Jacken'),
    'glove': _CategoryMapping('Motorrad-Bekleidung', 'Handschuhe'),
    'boot': _CategoryMapping('Motorrad-Bekleidung', 'Stiefel / Schuhe'),
    'shoe': _CategoryMapping('Motorrad-Bekleidung', 'Stiefel / Schuhe'),
    'footwear': _CategoryMapping('Motorrad-Bekleidung', 'Stiefel / Schuhe'),
    'trousers': _CategoryMapping('Motorrad-Bekleidung', 'Hosen'),
    'pants': _CategoryMapping('Motorrad-Bekleidung', 'Hosen'),
    'jeans': _CategoryMapping('Motorrad-Bekleidung', 'Hosen'),

    // ── Zubehör ──
    'bag': _CategoryMapping('Zubehör', 'Koffer / Taschen'),
    'backpack': _CategoryMapping('Zubehör', 'Koffer / Taschen'),
    'luggage': _CategoryMapping('Zubehör', 'Koffer / Taschen'),
    'suitcase': _CategoryMapping('Zubehör', 'Koffer / Taschen'),
    'tool': _CategoryMapping('Zubehör', 'Werkzeug'),
    'wrench': _CategoryMapping('Zubehör', 'Werkzeug'),
    'lock': _CategoryMapping('Zubehör', 'Schlösser / Diebstahlschutz'),
    'padlock': _CategoryMapping('Zubehör', 'Schlösser / Diebstahlschutz'),
    'camera': _CategoryMapping('Zubehör', 'Kameras / Action Cams'),
    'action camera': _CategoryMapping('Zubehör', 'Kameras / Action Cams'),

    // ── Elektronik ──
    'mobile phone': _CategoryMapping('Elektronik', 'Smartphones & Tablets'),
    'telephone': _CategoryMapping('Elektronik', 'Smartphones & Tablets'),
    'smartphone': _CategoryMapping('Elektronik', 'Smartphones & Tablets'),
    'tablet computer': _CategoryMapping('Elektronik', 'Smartphones & Tablets'),
    'laptop': _CategoryMapping('Elektronik', 'Laptops & PCs'),
    'computer': _CategoryMapping('Elektronik', 'Laptops & PCs'),
    'headphones': _CategoryMapping('Elektronik', 'Audio & Kopfhörer'),
    'earbuds': _CategoryMapping('Elektronik', 'Audio & Kopfhörer'),
    'speaker': _CategoryMapping('Elektronik', 'Audio & Kopfhörer'),
    'game controller': _CategoryMapping('Elektronik', 'Gaming'),

    // ── Haus & Garten ──
    'furniture': _CategoryMapping('Haus & Garten', 'Möbel'),
    'chair': _CategoryMapping('Haus & Garten', 'Möbel'),
    'table': _CategoryMapping('Haus & Garten', 'Möbel'),
    'sofa': _CategoryMapping('Haus & Garten', 'Möbel'),
    'couch': _CategoryMapping('Haus & Garten', 'Möbel'),
    'desk': _CategoryMapping('Haus & Garten', 'Möbel'),
    'shelf': _CategoryMapping('Haus & Garten', 'Möbel'),
    'lamp': _CategoryMapping('Haus & Garten', 'Dekoration'),
    'plant': _CategoryMapping('Haus & Garten', 'Garten & Outdoor'),

    // ── Sport & Freizeit ──
    'sports equipment': _CategoryMapping('Sport & Freizeit', null),
    'dumbbell': _CategoryMapping('Sport & Freizeit', 'Fitness'),
    'ball': _CategoryMapping('Sport & Freizeit', null),
    'skateboard': _CategoryMapping('Sport & Freizeit', 'Sonstige Sportarten'),
    'surfboard': _CategoryMapping('Sport & Freizeit', 'Wassersport'),
    'tent': _CategoryMapping('Sport & Freizeit', 'Outdoor / Camping'),
    'ski': _CategoryMapping('Sport & Freizeit', 'Wintersport'),
    'snowboard': _CategoryMapping('Sport & Freizeit', 'Wintersport'),

    // ── Mode & Beauty ──
    'dress': _CategoryMapping('Mode & Beauty', 'Damenbekleidung'),
    'shirt': _CategoryMapping('Mode & Beauty', 'Herrenbekleidung'),
    't-shirt': _CategoryMapping('Mode & Beauty', 'Herrenbekleidung'),
    'suit': _CategoryMapping('Mode & Beauty', 'Herrenbekleidung'),
    'hat': _CategoryMapping('Mode & Beauty', 'Sonstiges'),
    'sunglasses': _CategoryMapping('Mode & Beauty', 'Sonstiges'),
    'watch': _CategoryMapping('Mode & Beauty', 'Uhren & Schmuck'),
    'necklace': _CategoryMapping('Mode & Beauty', 'Uhren & Schmuck'),
    'ring': _CategoryMapping('Mode & Beauty', 'Uhren & Schmuck'),
    'bracelet': _CategoryMapping('Mode & Beauty', 'Uhren & Schmuck'),
    'handbag': _CategoryMapping('Mode & Beauty', 'Sonstiges'),
    'perfume': _CategoryMapping('Mode & Beauty', 'Pflege & Kosmetik'),
  };
}

class _CategoryMapping {
  final String category;
  final String? subcategory;

  const _CategoryMapping(this.category, this.subcategory);
}

class ClassificationResult {
  final String category;
  final String? subcategory;
  final double confidence;
  final String detectedLabel;

  const ClassificationResult({
    required this.category,
    this.subcategory,
    required this.confidence,
    required this.detectedLabel,
  });

  /// Lesbarer Text für den User.
  String get displayText {
    if (subcategory != null) {
      return '$category > $subcategory';
    }
    return category;
  }
}
