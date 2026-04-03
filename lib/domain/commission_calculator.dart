/// Bikergram Marketplace Commission Calculator
///
/// Provisionsmodell:
/// - Unter 100€: pauschal 1€
/// - Ab 100€: 2% vom Verkaufspreis
/// - Deckel: max. 50€
///
/// Nur bei erfolgreichem Verkauf. Keine Listing-Gebühr.
class CommissionCalculator {
  CommissionCalculator._();

  /// Minimum sale price to charge any commission (in EUR).
  static const double minPriceForCommission = 5.0;

  /// Flat fee for sales under the threshold (EUR).
  static const double flatFee = 1.0;

  /// Threshold above which percentage fee applies (EUR).
  static const double percentageThreshold = 100.0;

  /// Percentage fee rate (0.02 = 2%).
  static const double feeRate = 0.02;

  /// Maximum commission cap (EUR).
  static const double maxFee = 50.0;

  /// Calculate the commission for a given sale price.
  /// Returns 0 if price is null or below minimum.
  static double calculate(double? price) {
    if (price == null || price < minPriceForCommission) return 0;

    if (price < percentageThreshold) {
      return flatFee;
    }

    final fee = price * feeRate;
    return fee.clamp(flatFee, maxFee);
  }

  /// Human-readable fee string for display.
  static String formatFee(double? price) {
    final fee = calculate(price);
    if (fee <= 0) return 'Keine Gebühr';
    return '${fee.toStringAsFixed(2)} €';
  }

  /// Seller receives: price - commission
  static double sellerReceives(double? price) {
    if (price == null) return 0;
    return (price - calculate(price)).clamp(0, double.infinity);
  }

  /// Description of the fee model for display.
  static String get feeModelDescription =>
      'Unter ${percentageThreshold.toInt()}€: ${flatFee.toStringAsFixed(0)}€ pauschal\n'
      'Ab ${percentageThreshold.toInt()}€: ${(feeRate * 100).toInt()}% (max. ${maxFee.toInt()}€)';
}
