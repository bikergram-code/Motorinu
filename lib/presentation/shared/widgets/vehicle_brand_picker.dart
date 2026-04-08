import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/vehicle_brands.dart';

/// Wiederverwendbares Marke/Modell-Dropdown Widget.
/// Wird von Marktplatz UND Garage genutzt.
class VehicleBrandPicker extends StatelessWidget {
  final String? selectedBrand;
  final String? selectedModel;
  final bool isMotorcycle;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<String?> onModelChanged;

  const VehicleBrandPicker({
    super.key,
    this.selectedBrand,
    this.selectedModel,
    required this.isMotorcycle,
    required this.accentColor,
    this.cardColor = const Color(0xFF1A1A1A),
    this.textColor = Colors.white,
    required this.onBrandChanged,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marke
        _buildSearchableDropdown(
          context: context,
          label: 'Marke *',
          hint: isMotorcycle ? 'z.B. BMW, Ducati, Yamaha...' : 'z.B. BMW, Mercedes, Audi...',
          value: selectedBrand,
          items: isMotorcycle
              ? VehicleBrands.motorcycleBrandNames
              : VehicleBrands.carBrandNames,
          onChanged: (brand) {
            onBrandChanged(brand);
            // Reset model when brand changes
            onModelChanged(null);
          },
        ),
        const SizedBox(height: 14),

        // Modell
        if (isMotorcycle && selectedBrand != null) ...[
          _buildSearchableDropdown(
            context: context,
            label: 'Modell *',
            hint: 'Modell wählen...',
            value: selectedModel,
            items: VehicleBrands.motorcycleModelsFor(selectedBrand!),
            allowCustom: true,
            onChanged: onModelChanged,
          ),
        ] else if (!isMotorcycle && selectedBrand != null) ...[
          _buildTextField(
            label: 'Modell *',
            hint: 'z.B. A4, C-Klasse, Golf...',
            value: selectedModel,
            onChanged: onModelChanged,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchableDropdown({
    required BuildContext context,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool allowCustom = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showSearchSheet(
            context: context,
            title: label.replaceAll(' *', ''),
            items: items,
            selected: value,
            allowCustom: allowCustom,
            onSelected: onChanged,
          ),
          child: Container(
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
                      color: value != null
                          ? textColor
                          : textColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textColor.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value),
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
          style: GoogleFonts.inter(fontSize: 16, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.25),
            ),
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
          ),
        ),
      ],
    );
  }

  void _showSearchSheet({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String? selected,
    required bool allowCustom,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BrandSearchSheet(
        title: title,
        items: items,
        selected: selected,
        allowCustom: allowCustom,
        accentColor: accentColor,
        onSelected: (val) {
          onSelected(val);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _BrandSearchSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final bool allowCustom;
  final Color accentColor;
  final ValueChanged<String?> onSelected;

  const _BrandSearchSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.allowCustom,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  State<_BrandSearchSheet> createState() => _BrandSearchSheetState();
}

class _BrandSearchSheetState extends State<_BrandSearchSheet> {
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
        final q = query.toLowerCase();
        _filtered = widget.items
            .where((item) => item.toLowerCase().contains(q))
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
    final mutedColor = textColor.withValues(alpha: 0.4);
    final searchBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          // Search
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
                  fontSize: 16,
                  color: textColor.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: mutedColor, size: 22),
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
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length + (widget.allowCustom && _searchController.text.isNotEmpty && !_filtered.contains(_searchController.text) ? 1 : 0),
              itemBuilder: (ctx, i) {
                // Custom entry at the end
                if (i == _filtered.length) {
                  final customText = _searchController.text.trim();
                  return ListTile(
                    leading: Icon(Icons.add_rounded, color: widget.accentColor, size: 22),
                    title: Text(
                      '"$customText" hinzufügen',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: widget.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => widget.onSelected(customText),
                  );
                }

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
