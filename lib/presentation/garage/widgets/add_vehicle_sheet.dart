import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/community.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/garage/garage_notifier.dart';
import '../../../theme/app_theme.dart';

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
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _ccmController = TextEditingController();
  final _psController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;
  String? _error;

  // Image
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _brandController.text = v.brand;
      _modelController.text = v.model;
      if (v.year != null) _yearController.text = '${v.year}';
      if (v.displacementCc != null) {
        _ccmController.text = '${v.displacementCc}';
      }
      if (v.horsepower != null) _psController.text = '${v.horsepower}';
      _selectedCategory = v.category;
      _existingImageUrl = v.imageUrl;
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _ccmController.dispose();
    _psController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = picked.name;
    });
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
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: accentColor),
                title: Text('Kamera',
                    style: GoogleFonts.inter(color: pickerText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_selectedImageBytes != null || _existingImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: Text('Bild entfernen',
                      style: GoogleFonts.inter(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedImageBytes = null;
                      _selectedImageName = null;
                      _existingImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();

    if (brand.isEmpty || model.isEmpty) {
      setState(() => _error = 'Marke und Modell sind Pflichtfelder.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(vehicleRepositoryProvider);

      // Upload image if new one was selected
      String? imageUrl = _existingImageUrl;
      if (_selectedImageBytes != null && _selectedImageName != null) {
        imageUrl = await repo.uploadVehicleImage(
            _selectedImageBytes!, _selectedImageName!);
      }

      if (widget.isEditing) {
        await ref.read(garageNotifierProvider.notifier).updateVehicle(
              widget.vehicle!.id,
              brand: brand,
              model: model,
              year: int.tryParse(_yearController.text.trim()),
              displacementCc: int.tryParse(_ccmController.text.trim()),
              horsepower: int.tryParse(_psController.text.trim()),
              category: _selectedCategory,
              imageUrl: imageUrl,
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
              imageUrl: imageUrl,
              community: community?.name,
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
                  // ── Fahrzeugbild ──
                  _buildLabel('Foto'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showImageSourcePicker(accentColor),
                    child: _buildImagePreview(accentColor, isBiker),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel('Marke *'),
                  const SizedBox(height: 8),
                  _buildInput(
                      controller: _brandController,
                      hint: isBiker
                          ? 'z.B. Kawasaki, Ducati...'
                          : 'z.B. BMW, Mercedes...',
                      accentColor: accentColor),

                  const SizedBox(height: 20),
                  _buildLabel('Modell *'),
                  const SizedBox(height: 8),
                  _buildInput(
                      controller: _modelController,
                      hint: isBiker
                          ? 'z.B. Z900, Panigale V4...'
                          : 'z.B. M3, AMG C63...',
                      accentColor: accentColor),

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

  Widget _buildImagePreview(Color accentColor, bool isBiker) {
    // Newly selected image
    if (_selectedImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              _selectedImageBytes!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _imageActionButton(accentColor),
            ),
          ],
        ),
      );
    }

    // Existing image from server
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.network(
              _existingImageUrl!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildImagePlaceholder(accentColor, isBiker),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _imageActionButton(accentColor),
            ),
          ],
        ),
      );
    }

    // Placeholder
    return _buildImagePlaceholder(accentColor, isBiker);
  }

  Widget _imageActionButton(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.edit_rounded, color: accentColor, size: 20),
    );
  }

  Widget _buildImagePlaceholder(Color accentColor, bool isBiker) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            size: 32,
            color: accentColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isBiker ? 'Foto vom Bike' : 'Foto vom Auto',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: accentColor.withValues(alpha: 0.6),
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
  }) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: textOnCard),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 15, color: textOnCard.withValues(alpha: 0.2)),
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
}
