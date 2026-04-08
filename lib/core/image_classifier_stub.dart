/// Web stub — ML Kit image classification not available on web.
class ImageClassifier {
  ImageClassifier._();

  /// Always returns null on web — user picks category manually.
  static Future<ClassificationResult?> classifyImage(String imagePath) async {
    return null;
  }

  static Future<void> dispose() async {}
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

  String get displayText {
    if (subcategory != null) {
      return '$category > $subcategory';
    }
    return category;
  }
}
