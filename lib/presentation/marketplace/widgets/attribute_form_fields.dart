import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/clothing_sizes.dart';
import '../../../core/marketplace_attributes.dart';
import '../../../core/marketplace_categories.dart';
import '../../../core/vehicle_brands.dart';
import '../../shared/widgets/vehicle_brand_picker.dart';

/// Dynamische Formularfelder basierend auf Kategorie/Unterkategorie.
/// Zeigt Marke/Modell/Baujahr/km bei Fahrzeugen, Größe bei Bekleidung, etc.
class AttributeFormFields extends StatefulWidget {
  final String category;
  final String? subcategory;
  final Map<String, dynamic> attributes;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final ValueChanged<Map<String, dynamic>> onAttributesChanged;

  const AttributeFormFields({
    super.key,
    required this.category,
    this.subcategory,
    required this.attributes,
    required this.accentColor,
    this.cardColor = const Color(0xFF1A1A1A),
    this.textColor = Colors.white,
    required this.onAttributesChanged,
  });

  @override
  State<AttributeFormFields> createState() => _AttributeFormFieldsState();
}

class _AttributeFormFieldsState extends State<AttributeFormFields> {
  final Map<String, TextEditingController> _controllers = {};

  String get category => widget.category;
  String? get subcategory => widget.subcategory;
  Map<String, dynamic> get attributes => widget.attributes;
  Color get accentColor => widget.accentColor;
  Color get cardColor => widget.cardColor;
  Color get textColor => widget.textColor;

  void _update(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(attributes);
    if (value == null || (value is String && value.isEmpty)) {
      updated.remove(key);
    } else {
      updated[key] = value;
    }
    widget.onAttributesChanged(updated);
  }

  TextEditingController _controllerFor(String key, {String? initialValue}) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue ?? '');
    }
    final ctrl = _controllers[key]!;
    // Sync if external value changed (e.g. reset)
    final expected = initialValue ?? '';
    if (ctrl.text != expected && expected.isEmpty) {
      ctrl.text = expected;
    }
    return ctrl;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = MarketplaceAttributes.fieldsFor(category, subcategory);
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          _sectionTitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: accentColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...fields.map((field) => _buildField(context, field)),
      ],
    );
  }

  String get _sectionTitle {
    if (MarketplaceCategories.needsVehicleAttributes(category)) {
      return 'FAHRZEUG-DETAILS';
    }
    if (MarketplaceCategories.needsClothingAttributes(category)) {
      return 'BEKLEIDUNGS-DETAILS';
    }
    if (MarketplaceCategories.needsPartAttributes(category)) {
      return 'PASSEND FÜR';
    }
    return 'DETAILS';
  }

  Widget _buildField(BuildContext context, AttributeField field) {
    // Skip dependent fields if parent not set
    if (field.dependsOn != null && attributes[field.dependsOn] == null) {
      return const SizedBox.shrink();
    }

    switch (field.type) {
      case FieldType.vehicleBrand:
        return _buildVehicleBrandField(context, field);
      case FieldType.vehicleModel:
        return _buildVehicleModelField(context, field);
      case FieldType.number:
        return _buildNumberField(field);
      case FieldType.yearPicker:
        return _buildYearPicker(context, field);
      case FieldType.monthYear:
        return _buildMonthYearField(context, field);
      case FieldType.colorPicker:
        return _buildDropdownField(field, VehicleBrands.vehicleColors);
      case FieldType.fuelType:
        return _buildDropdownField(field, VehicleBrands.fuelTypes);
      case FieldType.transmissionType:
        return _buildDropdownField(field, VehicleBrands.transmissionTypes);
      case FieldType.clothingSize:
        return _buildDropdownField(
          field,
          ClothingSizes.sizesForSubcategory(subcategory ?? ''),
        );
      case FieldType.gender:
        return _buildDropdownField(field, ClothingSizes.genders);
      case FieldType.text:
        return _buildTextField(field);
    }
  }

  Widget _buildVehicleBrandField(BuildContext context, AttributeField field) {
    final isMoto = subcategory == null || MarketplaceCategories.isMotorcycleSub(subcategory!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: VehicleBrandPicker(
        selectedBrand: attributes[field.key] as String?,
        selectedModel: attributes[field.dependsOn != null ? 'model' : field.key] as String?,
        isMotorcycle: field.vehicleType == VehicleType.motorcycle || isMoto,
        accentColor: accentColor,
        cardColor: cardColor,
        textColor: textColor,
        onBrandChanged: (brand) => _update(field.key, brand),
        onModelChanged: (model) {
          // For parts: fits_model
          final modelKey = field.key == 'fits_brand' ? 'fits_model' : 'model';
          _update(modelKey, model);
        },
      ),
    );
  }

  Widget _buildVehicleModelField(BuildContext context, AttributeField field) {
    // Model is handled by VehicleBrandPicker above — skip standalone rendering
    return const SizedBox.shrink();
  }

  Widget _buildNumberField(AttributeField field) {
    final ctrl = _controllerFor(field.key,
        initialValue: attributes[field.key]?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${field.label}${field.required ? ' *' : ''}'),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              final num = int.tryParse(v);
              _update(field.key, num);
            },
            style: GoogleFonts.inter(fontSize: 16, color: textColor),
            decoration: _inputDecoration(
              hint: field.hint ?? '0',
              suffix: field.suffix != null
                  ? Text(field.suffix!,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: textColor.withValues(alpha: 0.4)))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearPicker(BuildContext context, AttributeField field) {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1969, (i) => currentYear - i);
    final selected = attributes[field.key] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${field.label}${field.required ? ' *' : ''}'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showSearchSheet(
              context: context,
              title: field.label,
              items: years.map((y) => '$y').toList(),
              selected: selected?.toString(),
              onSelected: (val) => _update(field.key, int.tryParse(val ?? '')),
            ),
            child: _dropdownContainer(
              value: selected?.toString(),
              hint: 'Baujahr wählen...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearField(BuildContext context, AttributeField field) {
    final value = attributes[field.key] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${field.label}${field.required ? ' *' : ''}'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(1970),
                lastDate: DateTime(now.year + 5),
                initialDatePickerMode: DatePickerMode.year,
                builder: (ctx, child) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: isDark
                          ? ColorScheme.dark(
                              primary: accentColor,
                              surface: const Color(0xFF1A1A1A),
                            )
                          : ColorScheme.light(
                              primary: accentColor,
                              surface: Colors.white,
                            ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                final formatted = '${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                _update(field.key, formatted);
              }
            },
            child: _dropdownContainer(
              value: value,
              hint: 'MM/YYYY',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(AttributeField field, List<String> options) {
    final value = attributes[field.key] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${field.label}${field.required ? ' *' : ''}'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = value == option;
              return GestureDetector(
                onTap: () => _update(field.key, isSelected ? null : option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.15)
                        : textColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.4)
                          : textColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? accentColor : textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(AttributeField field) {
    final ctrl = _controllerFor(field.key,
        initialValue: attributes[field.key] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${field.label}${field.required ? ' *' : ''}'),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            onChanged: (v) => _update(field.key, v.isEmpty ? null : v),
            style: GoogleFonts.inter(fontSize: 16, color: textColor),
            decoration: _inputDecoration(hint: field.hint ?? ''),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor.withValues(alpha: 0.7),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 16,
        color: textColor.withValues(alpha: 0.25),
      ),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: textColor.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: textColor.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _dropdownContainer({required String? value, required String hint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null
              ? accentColor.withValues(alpha: 0.4)
              : textColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ?? hint,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: value != null ? textColor : textColor.withValues(alpha: 0.25),
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: textColor.withValues(alpha: 0.4), size: 22),
        ],
      ),
    );
  }

  void _showSearchSheet({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimpleSearchSheet(
        title: title,
        items: items,
        selected: selected,
        accentColor: accentColor,
        onSelected: (val) {
          onSelected(val);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _SimpleSearchSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final Color accentColor;
  final ValueChanged<String?> onSelected;

  const _SimpleSearchSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  State<_SimpleSearchSheet> createState() => _SimpleSearchSheetState();
}

class _SimpleSearchSheetState extends State<_SimpleSearchSheet> {
  final _searchController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final searchBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor,
              ),
            ),
          ),
          if (widget.items.length > 10)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _filter,
                style: GoogleFonts.inter(fontSize: 16, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Suchen...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16, color: textColor.withValues(alpha: 0.3),
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: textColor.withValues(alpha: 0.4), size: 22),
                  filled: true,
                  fillColor: searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final item = _filtered[i];
                final isSelected = item == widget.selected;
                return ListTile(
                  title: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isSelected ? widget.accentColor : textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: widget.accentColor, size: 20)
                      : null,
                  onTap: () => widget.onSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
