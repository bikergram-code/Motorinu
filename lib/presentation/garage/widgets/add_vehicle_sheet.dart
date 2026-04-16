import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/community.dart';
import '../../../core/vehicle_brands.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/garage/garage_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../shared/widgets/vehicle_brand_picker.dart';

class AddVehicleSheet extends ConsumerStatefulWidget {
  const AddVehicleSheet({super.key, this.vehicle});

  final Vehicle? vehicle;

  bool get isEditing => vehicle != null;

  @override
  ConsumerState<AddVehicleSheet> createState() => _AddVehicleSheetState();

  static Future<void> show(BuildContext context, WidgetRef ref,
      {Vehicle? vehicle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddVehicleSheet(vehicle: vehicle),
    );
  }
}

class _AddVehicleSheetState extends ConsumerState<AddVehicleSheet> {
  String? _selectedBrand;
  String? _selectedModel;
  final _yearController = TextEditingController();
  final _ccmController = TextEditingController();
  final _psController = TextEditingController();
  final _kmController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedCategory;
  String? _selectedFuel;
  String? _selectedTransmission;
  String? _selectedColor;
  String? _selectedTuev; // "MM/YYYY"
  bool _isSubmitting = false;
  String? _error;

  // Images (multi)
  final List<String> _imageUrls = []; // uploaded URLs
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _selectedBrand = v.brand;
      _selectedModel = v.model;
      if (v.year != null) _yearController.text = '${v.year}';
      if (v.displacementCc != null) {
        _ccmController.text = '${v.displacementCc}';
      }
      if (v.horsepower != null) _psController.text = '${v.horsepower}';
      if (v.mileage != null) _kmController.text = '${v.mileage}';
      if (v.description != null) _descController.text = v.description!;
      _selectedCategory = v.category;
      _selectedFuel = v.fuel;
      _selectedTransmission = v.transmission;
      _selectedColor = v.color;
      _selectedTuev = v.tuevDate;
      _imageUrls.addAll(v.allImages);
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _ccmController.dispose();
    _psController.dispose();
    _kmController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_imageUrls.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximal 5 Bilder')));
      }
      return;
    }
    final picker = ImagePicker();

    // Gallery: allow multi-select, Camera: single image
    if (source == ImageSource.gallery) {
      final remaining = 5 - _imageUrls.length;
      final files = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        limit: remaining,
      );
      if (files.isEmpty) return;
      setState(() => _isUploading = true);
      try {
        final repo = ref.read(vehicleRepositoryProvider);
        for (final file in files) {
          if (_imageUrls.length >= 5) break;
          final bytes = await file.readAsBytes();
          final url = await repo.uploadVehicleImage(bytes, file.name);
          if (mounted) setState(() => _imageUrls.add(url));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _isUploading = true);
      try {
        final bytes = await picked.readAsBytes();
        final repo = ref.read(vehicleRepositoryProvider);
        final url = await repo.uploadVehicleImage(bytes, picked.name);
        if (mounted) setState(() => _imageUrls.add(url));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showImageSourcePicker(Color accentColor) {
    final brightness = Theme.of(context).brightness;
    final community = ref.read(communityProvider);
    final pickerBg = community?.cardFor(brightness) ??
        (brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white);
    final pickerText = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    showModalBottomSheet(
      context: context,
      backgroundColor: pickerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: accentColor),
                title: Text('Galerie',
                    style: GoogleFonts.inter(color: pickerText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: accentColor),
                title: Text('Kamera',
                    style: GoogleFonts.inter(color: pickerText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final brand = _selectedBrand?.trim() ?? '';
    final model = _selectedModel?.trim() ?? '';

    if (brand.isEmpty || model.isEmpty) {
      setState(() => _error = 'Marke und Modell sind Pflichtfelder.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final imageUrl = _imageUrls.isNotEmpty ? _imageUrls.first : null;
      final km = int.tryParse(_kmController.text.trim());
      final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();

      if (widget.isEditing) {
        await ref.read(garageNotifierProvider.notifier).updateVehicle(
              widget.vehicle!.id,
              brand: brand,
              model: model,
              year: int.tryParse(_yearController.text.trim()),
              displacementCc: int.tryParse(_ccmController.text.trim()),
              horsepower: int.tryParse(_psController.text.trim()),
              category: _selectedCategory,
              description: desc,
              imageUrl: imageUrl,
              images: _imageUrls,
              mileage: km,
              fuel: _selectedFuel,
              transmission: _selectedTransmission,
              color: _selectedColor,
              tuevDate: _selectedTuev,
              clearMileage: km == null && widget.vehicle?.mileage != null,
              clearFuel: _selectedFuel == null && widget.vehicle?.fuel != null,
              clearTransmission: _selectedTransmission == null && widget.vehicle?.transmission != null,
              clearColor: _selectedColor == null && widget.vehicle?.color != null,
              clearTuev: _selectedTuev == null && widget.vehicle?.tuevDate != null,
            );
      } else {
        final community = ref.read(communityProvider);
        await ref.read(garageNotifierProvider.notifier).addVehicle(
              brand: brand,
              model: model,
              year: int.tryParse(_yearController.text.trim()),
              displacementCc: int.tryParse(_ccmController.text.trim()),
              horsepower: int.tryParse(_psController.text.trim()),
              category: _selectedCategory,
              description: desc,
              imageUrl: imageUrl,
              images: _imageUrls,
              community: community?.name,
              mileage: km,
              fuel: _selectedFuel,
              transmission: _selectedTransmission,
              color: _selectedColor,
              tuevDate: _selectedTuev,
            );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isBiker = community == Community.bikergram;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final brightness = Theme.of(context).brightness;
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

    final categories = isBiker
        ? [
            'Naked Bike', 'Supersport', 'Touring', 'Enduro',
            'Chopper', 'Custom', 'Cafe Racer', 'Roller'
          ]
        : [
            'Limousine', 'SUV', 'Coup\u00e9', 'Cabrio',
            'Kombi', 'Sportwagen', 'Van', 'Oldtimer'
          ];

    final title = widget.isEditing
        ? (isBiker ? 'Bike bearbeiten' : 'Auto bearbeiten')
        : (isBiker ? 'Neues Bike' : 'Neues Auto');

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textOnCard.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Icon(
                  widget.isEditing
                      ? Icons.edit_rounded
                      : (isBiker
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_rounded),
                  color: accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textOnCard),
                      overflow: TextOverflow.ellipsis),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: faint),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fahrzeugbilder (multi) ──
                  _buildLabel('Fotos (max. 5)'),
                  const SizedBox(height: 10),
                  _buildImageGallery(accentColor, isBiker),

                  const SizedBox(height: 20),

                  // Marke + Modell via VehicleBrandPicker
                  VehicleBrandPicker(
                    selectedBrand: _selectedBrand,
                    selectedModel: _selectedModel,
                    isMotorcycle: isBiker,
                    accentColor: accentColor,
                    cardColor: textOnCard.withValues(alpha: 0.04),
                    textColor: textOnCard,
                    onBrandChanged: (brand) => setState(() {
                      _selectedBrand = brand;
                      _selectedModel = null;
                    }),
                    onModelChanged: (model) => setState(() {
                      _selectedModel = model;
                    }),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Baujahr'),
                            const SizedBox(height: 8),
                            _buildInput(
                                controller: _yearController,
                                hint: '2024',
                                accentColor: accentColor,
                                keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(isBiker ? 'ccm' : 'Hubraum'),
                            const SizedBox(height: 8),
                            _buildInput(
                                controller: _ccmController,
                                hint: isBiker ? '998' : '3000',
                                accentColor: accentColor,
                                keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('PS'),
                            const SizedBox(height: 8),
                            _buildInput(
                                controller: _psController,
                                hint: '203',
                                accentColor: accentColor,
                                keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Kilometerstand ──
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Kilometerstand'),
                            const SizedBox(height: 8),
                            _buildInput(
                                controller: _kmController,
                                hint: '25000',
                                accentColor: accentColor,
                                keyboardType: TextInputType.number,
                                suffix: 'km'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('TÜV bis'),
                            const SizedBox(height: 8),
                            _buildTuevPicker(accentColor, textOnCard, faint),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Kraftstoff + Getriebe ──
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Kraftstoff'),
                            const SizedBox(height: 8),
                            _buildDropdown(
                              value: _selectedFuel,
                              items: VehicleBrands.fuelTypes,
                              hint: 'Benzin',
                              accentColor: accentColor,
                              textColor: textOnCard,
                              faint: faint,
                              onChanged: (v) => setState(() => _selectedFuel = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Getriebe'),
                            const SizedBox(height: 8),
                            _buildDropdown(
                              value: _selectedTransmission,
                              items: VehicleBrands.transmissionTypes,
                              hint: 'Schaltung',
                              accentColor: accentColor,
                              textColor: textOnCard,
                              faint: faint,
                              onChanged: (v) => setState(() => _selectedTransmission = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Farbe ──
                  const SizedBox(height: 20),
                  _buildLabel('Farbe'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedColor,
                    items: VehicleBrands.vehicleColors,
                    hint: 'Farbe wählen',
                    accentColor: accentColor,
                    textColor: textOnCard,
                    faint: faint,
                    onChanged: (v) => setState(() => _selectedColor = v),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel('Beschreibung'),
                  const SizedBox(height: 8),
                  _buildInput(
                      controller: _descController,
                      hint: 'Zustand, Extras, Besonderheiten...',
                      accentColor: accentColor,
                      maxLines: 3),

                  const SizedBox(height: 20),
                  _buildLabel('Kategorie'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.15)
                                : textOnCard.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.4)
                                  : textOnCard.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? accentColor
                                      : textOnCard
                                          .withValues(alpha: 0.6))),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.red)),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              widget.isEditing
                                  ? 'Speichern'
                                  : 'Hinzuf\u00fcgen',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Color accentColor, bool isBiker) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing images
          for (int i = 0; i < _imageUrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _imageUrls[i],
                      width: 100, height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: const Icon(Icons.broken_image_rounded),
                      ),
                    ),
                  ),
                  // Delete button
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageUrls.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  // Badge number
                  if (i == 0)
                    Positioned(
                      bottom: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Hauptbild', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          // Upload spinner
          if (_isUploading)
            Container(
              width: 100, height: 100,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
            ),
          // Add button (if < 5)
          if (_imageUrls.length < 5 && !_isUploading)
            GestureDetector(
              onTap: () => _showImageSourcePicker(accentColor),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 28, color: accentColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 4),
                    Text(isBiker ? 'Foto' : 'Foto',
                      style: GoogleFonts.inter(fontSize: 11, color: accentColor.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textMuted));
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? suffix,
  }) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 15, color: textOnCard),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 15, color: textOnCard.withValues(alpha: 0.2)),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(fontSize: 14, color: textOnCard.withValues(alpha: 0.4)),
        filled: true,
        fillColor: textOnCard.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: textOnCard.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: textOnCard.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: accentColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required Color accentColor,
    required Color textColor,
    required Color faint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 15, color: textColor.withValues(alpha: 0.2))),
          dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor.withValues(alpha: 0.3)),
          style: GoogleFonts.inter(fontSize: 15, color: textColor),
          items: [
            // "Keine Angabe" option to clear
            DropdownMenuItem<String>(
              value: null,
              child: Text('—', style: GoogleFonts.inter(fontSize: 15, color: textColor.withValues(alpha: 0.3))),
            ),
            ...items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item, style: GoogleFonts.inter(fontSize: 15, color: textColor)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTuevPicker(Color accentColor, Color textColor, Color faint) {
    return GestureDetector(
      onTap: () => _showTuevDialog(accentColor, textColor),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedTuev ?? 'MM/JJJJ',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _selectedTuev != null
                      ? textColor
                      : textColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            Icon(Icons.calendar_month_rounded, size: 18, color: textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Future<void> _showTuevDialog(Color accentColor, Color textColor) async {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    // Parse existing value
    if (_selectedTuev != null) {
      final parts = _selectedTuev!.split('/');
      if (parts.length == 2) {
        selectedMonth = int.tryParse(parts[0]) ?? now.month;
        selectedYear = int.tryParse(parts[1]) ?? now.year;
      }
    }

    final brightness = Theme.of(context).brightness;
    final community = ref.read(communityProvider);
    final dialogBg = community?.cardFor(brightness) ??
        (brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final months = List.generate(12, (i) => i + 1);
          final years = List.generate(10, (i) => now.year + i);
          return AlertDialog(
            backgroundColor: dialogBg,
            title: Text('TÜV bis', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            content: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monat', style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.5))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: textColor.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            dropdownColor: dialogBg,
                            style: GoogleFonts.inter(fontSize: 15, color: textColor),
                            items: months.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text('${m.toString().padLeft(2, '0')}', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                            )).toList(),
                            onChanged: (v) => setDialogState(() => selectedMonth = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jahr', style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.5))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: textColor.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            dropdownColor: dialogBg,
                            style: GoogleFonts.inter(fontSize: 15, color: textColor),
                            items: years.map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y', style: GoogleFonts.inter(fontSize: 15, color: textColor)),
                            )).toList(),
                            onChanged: (v) => setDialogState(() => selectedYear = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (_selectedTuev != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, '__clear__'),
                  child: Text('Entfernen', style: GoogleFonts.inter(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Abbrechen', style: GoogleFonts.inter(color: textColor.withValues(alpha: 0.5))),
              ),
              TextButton(
                onPressed: () {
                  final value = '${selectedMonth.toString().padLeft(2, '0')}/$selectedYear';
                  Navigator.pop(ctx, value);
                },
                child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: accentColor)),
              ),
            ],
          );
        });
      },
    );

    if (result == '__clear__') {
      setState(() => _selectedTuev = null);
    } else if (result != null) {
      setState(() => _selectedTuev = result);
    }
  }
}
