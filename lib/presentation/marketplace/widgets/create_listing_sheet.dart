import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../data/repositories/marketplace_repository.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/marketplace/marketplace_notifier.dart';
import '../../../theme/app_theme.dart';

class CreateListingSheet extends ConsumerStatefulWidget {
  const CreateListingSheet({super.key, this.listing});

  final MarketplaceListing? listing;

  bool get isEditing => listing != null;

  @override
  ConsumerState<CreateListingSheet> createState() => _CreateListingSheetState();

  static void show(BuildContext context, {MarketplaceListing? listing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateListingSheet(listing: listing),
    );
  }
}

class _CreateListingSheetState extends ConsumerState<CreateListingSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCondition;
  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  String? _error;

  final List<String> _imageUrls = [];
  final List<File> _newImages = [];

  static const _conditions = [
    ('Neu', 'new'),
    ('Wie neu', 'like_new'),
    ('Gut', 'good'),
    ('Akzeptabel', 'fair'),
    ('Ersatzteile', 'parts'),
  ];

  static const _categories = [
    'Teile', 'Zubeh\u00f6r', 'Bekleidung', 'Fahrzeuge',
  ];

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    if (l != null) {
      _titleController.text = l.title;
      _descController.text = l.description ?? '';
      if (l.price != null) _priceController.text = l.price!.toStringAsFixed(2);
      _locationController.text = l.locationText ?? '';
      _selectedCondition = l.condition;
      _selectedCategory = l.category;
      _imageUrls.addAll(l.images);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final ext = picked.path.split('.').last.toLowerCase();
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final fileName = 'marketplace/${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('posts')
          .upload(fileName, file);

      final url = Supabase.instance.client.storage
          .from('posts')
          .getPublicUrl(fileName);

      if (!mounted) return;
      setState(() {
        _imageUrls.add(url);
        _isUploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bild-Upload fehlgeschlagen: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Titel ist ein Pflichtfeld.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (widget.isEditing) {
        await ref.read(marketplaceNotifierProvider.notifier).updateListing(
          widget.listing!.id,
          title: title,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          price: double.tryParse(_priceController.text.trim()),
          condition: _selectedCondition,
          category: _selectedCategory,
          images: _imageUrls,
          locationText: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
        );
      } else {
        final community = ref.read(communityProvider);
        await ref.read(marketplaceNotifierProvider.notifier).createListing(
          title: title,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          price: double.tryParse(_priceController.text.trim()),
          condition: _selectedCondition,
          category: _selectedCategory,
          community: community?.name,
          images: _imageUrls.isNotEmpty ? _imageUrls : null,
          locationText: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final brightness = Theme.of(context).brightness;
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

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
            width: 36, height: 4,
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
                  widget.isEditing ? Icons.edit_rounded : Icons.add_business_rounded,
                  color: accentColor, size: 22,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.isEditing ? 'Inserat bearbeiten' : 'Neues Inserat',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textOnCard),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  // Image picker section
                  _label('Fotos'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Existing images
                        ..._imageUrls.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    url,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100, height: 100,
                                      decoration: BoxDecoration(
                                        color: textOnCard.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.broken_image_rounded,
                                          color: textOnCard.withValues(alpha: 0.2)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(idx),
                                    child: Container(
                                      width: 24, height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Add button
                        if (_imageUrls.length < 5)
                          GestureDetector(
                            onTap: _isUploadingImage ? null : _pickImage,
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: textOnCard.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: _isUploadingImage
                                  ? const Center(
                                      child: SizedBox(
                                        width: 24, height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            color: accentColor, size: 28),
                                        const SizedBox(height: 4),
                                        Text('Foto',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: accentColor,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _label('Titel *'),
                  const SizedBox(height: 8),
                  _input(_titleController, 'Was verkaufst du?', accentColor: accentColor),

                  const SizedBox(height: 20),
                  _label('Beschreibung'),
                  const SizedBox(height: 8),
                  _input(_descController, 'Details zum Artikel...', maxLines: 3, accentColor: accentColor),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Preis (\u20ac)'),
                            const SizedBox(height: 8),
                            _input(_priceController, '0.00',
                                keyboardType: TextInputType.number, accentColor: accentColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Standort'),
                            const SizedBox(height: 8),
                            _input(_locationController, 'z.B. K\u00f6ln', accentColor: accentColor),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _label('Zustand'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conditions.map((c) {
                      final isSelected = _selectedCondition == c.$2;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCondition = c.$2),
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
                                    : textOnCard.withValues(alpha: 0.08)),
                          ),
                          child: Text(c.$1,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? accentColor
                                      : textOnCard.withValues(alpha: 0.6))),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  _label('Kategorie'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
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
                                    : textOnCard.withValues(alpha: 0.08)),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? accentColor
                                      : textOnCard.withValues(alpha: 0.6))),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style:
                            GoogleFonts.inter(fontSize: 13, color: Colors.red)),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity, height: 52,
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
                              width: 20, height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              widget.isEditing
                                  ? 'Speichern'
                                  : 'Inserat erstellen',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
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

  Widget _label(String text) {
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

  Widget _input(TextEditingController controller, String hint,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      required Color accentColor}) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
