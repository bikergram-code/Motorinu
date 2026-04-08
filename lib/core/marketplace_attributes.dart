import 'marketplace_categories.dart';

/// Definiert welche Attribute pro Kategorie benötigt werden.
/// Wird von AttributeFormFields und AttributeFilterSheet genutzt.
class MarketplaceAttributes {
  MarketplaceAttributes._();

  /// Gibt die Liste der Attribut-Felder für eine Kategorie + Unterkategorie zurück.
  static List<AttributeField> fieldsFor(String category, String? subcategory) {
    if (MarketplaceCategories.needsVehicleAttributes(category)) {
      // Erst Unterkategorie wählen, dann Fahrzeug-Details zeigen
      if (subcategory == null || subcategory.isEmpty) return [];
      return _vehicleFields(subcategory);
    }
    if (MarketplaceCategories.needsClothingAttributes(category)) {
      if (subcategory == null || subcategory.isEmpty) return [];
      return _clothingFields(subcategory);
    }
    if (MarketplaceCategories.needsPartAttributes(category)) {
      return _partFields();
    }
    return [];
  }

  static List<AttributeField> _vehicleFields(String? subcategory) {
    final isMoto = subcategory == null || MarketplaceCategories.isMotorcycleSub(subcategory);
    // Quads/ATVs und Sonstige Fahrzeuge bekommen auch Moto-Marken
    final isOther = subcategory == 'Quads / ATVs' || subcategory == 'Anhänger' || subcategory == 'Sonstige Fahrzeuge';

    return [
      AttributeField(
        key: 'brand',
        label: 'Marke',
        type: FieldType.vehicleBrand,
        required: true,
        vehicleType: (isMoto || isOther) ? VehicleType.motorcycle : VehicleType.car,
      ),
      AttributeField(
        key: 'model',
        label: 'Modell',
        type: (isMoto || isOther) ? FieldType.vehicleModel : FieldType.text,
        required: true,
        dependsOn: 'brand',
      ),
      const AttributeField(
        key: 'year',
        label: 'Baujahr',
        type: FieldType.yearPicker,
        required: true,
      ),
      const AttributeField(
        key: 'mileage',
        label: 'Kilometerstand',
        type: FieldType.number,
        required: true,
        suffix: 'km',
        maxValue: 999999,
      ),
      const AttributeField(
        key: 'displacement',
        label: 'Hubraum',
        type: FieldType.number,
        required: false,
        suffix: 'ccm',
        maxValue: 9999,
      ),
      const AttributeField(
        key: 'power',
        label: 'Leistung',
        type: FieldType.number,
        required: false,
        suffix: 'PS',
        maxValue: 9999,
      ),
      const AttributeField(
        key: 'first_registration',
        label: 'Erstzulassung',
        type: FieldType.monthYear,
        required: false,
      ),
      const AttributeField(
        key: 'tuev_until',
        label: 'TÜV bis',
        type: FieldType.monthYear,
        required: false,
      ),
      const AttributeField(
        key: 'color',
        label: 'Farbe',
        type: FieldType.colorPicker,
        required: false,
      ),
      const AttributeField(
        key: 'fuel',
        label: 'Kraftstoff',
        type: FieldType.fuelType,
        required: false,
      ),
      const AttributeField(
        key: 'transmission',
        label: 'Getriebe',
        type: FieldType.transmissionType,
        required: false,
      ),
    ];
  }

  static List<AttributeField> _clothingFields(String? subcategory) {
    return [
      AttributeField(
        key: 'size',
        label: 'Größe',
        type: FieldType.clothingSize,
        required: true,
        clothingSubcategory: subcategory,
      ),
      const AttributeField(
        key: 'gender',
        label: 'Geschlecht',
        type: FieldType.gender,
        required: false,
      ),
      const AttributeField(
        key: 'clothing_brand',
        label: 'Marke',
        type: FieldType.text,
        required: false,
        hint: 'z.B. Alpinestars, Dainese...',
      ),
    ];
  }

  static List<AttributeField> _partFields() {
    return [
      const AttributeField(
        key: 'fits_brand',
        label: 'Passend für (Marke)',
        type: FieldType.vehicleBrand,
        required: false,
        vehicleType: VehicleType.motorcycle,
      ),
      const AttributeField(
        key: 'fits_model',
        label: 'Passend für (Modell)',
        type: FieldType.vehicleModel,
        required: false,
        dependsOn: 'fits_brand',
      ),
    ];
  }
}

enum FieldType {
  text,
  number,
  vehicleBrand,
  vehicleModel,
  yearPicker,
  monthYear,
  colorPicker,
  fuelType,
  transmissionType,
  clothingSize,
  gender,
}

enum VehicleType { motorcycle, car }

class AttributeField {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? suffix;
  final String? hint;
  final String? dependsOn;
  final double? maxValue;
  final VehicleType? vehicleType;
  final String? clothingSubcategory;

  const AttributeField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.suffix,
    this.hint,
    this.dependsOn,
    this.maxValue,
    this.vehicleType,
    this.clothingSubcategory,
  });
}
