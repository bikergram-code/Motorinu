import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../core/image_classifier.dart';
import '../../../core/marketplace_categories.dart';
import '../../../data/repositories/marketplace_repository.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/marketplace/marketplace_notifier.dart';
import '../../../theme/app_theme.dart';
import 'attribute_form_fields.dart';

class CreateListingSheet extends ConsumerStatefulWidget {
  const CreateListingSheet({
    super.key,
    this.listing,
    this.prefillTitle,
    this.prefillDescription,
    this.prefillImages,
  });

  final MarketplaceListing? listing;

  /// Pre-fill fields when converting a post to a listing.
  final String? prefillTitle;
  final String? prefillDescription;
  final List<String>? prefillImages;

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

  /// Open the listing sheet pre-filled with data from a feed post.
  static void showFromPost(
    BuildContext context, {
    required String? body,
    required String? imageUrl,
    List<String> attachmentUrls = const [],
  }) {
    // Use first line of body as title, rest as description
    String? title;
    String? description;
    if (body != null && body.isNotEmpty) {
      final lines = body.split('\n');
      title = lines.first.length > 80 ? lines.first.substring(0, 80) : lines.first;
      description = body;
    }

    // Collect images: main image + attachments
    final images = <String>[];
    if (imageUrl != null && imageUrl.isNotEmpty) images.add(imageUrl);
    for (final url in attachmentUrls) {
      if (url.isNotEmpty && !images.contains(url)) images.add(url);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateListingSheet(
        prefillTitle: title,
        prefillDescription: description,
        prefillImages: images.isNotEmpty ? images : null,
      ),
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
  String? _selectedSubcategory;
  Map<String, dynamic> _attributes = {};
  String _shippingType = 'pickup';
  bool _isNegotiable = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isClassifying = false;
  ClassificationResult? _suggestion;
  bool _detectedCar = false;
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

  // Kategorien kommen jetzt aus MarketplaceCategories

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
      _selectedSubcategory = l.subcategory;
      _attributes = Map<String, dynamic>.from(l.attributes);
      _shippingType = l.shippingType;
      _isNegotiable = l.isNegotiable;
      _imageUrls.addAll(l.images);
    } else {
      // Pre-fill from post conversion
      if (widget.prefillTitle != null) {
        _titleController.text = widget.prefillTitle!;
      }
      if (widget.prefillDescription != null) {
        _descController.text = widget.prefillDescription!;
      }
      if (widget.prefillImages != null) {
        _imageUrls.addAll(widget.prefillImages!);
      }
      // Default category to Fahrzeuge for post conversions
      if (widget.prefillTitle != null || widget.prefillImages != null) {
        _selectedCategory = 'Fahrzeuge';
      }
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
    if (_imageUrls.length >= 5) return;
    try {
      final picker = ImagePicker();
      final remaining = 5 - _imageUrls.length;
      final files = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
        limit: remaining,
      );
      if (files.isEmpty) return;

      setState(() => _isUploadingImage = true);

      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      for (final picked in files) {
        if (_imageUrls.length >= 5) break;
        final file = File(picked.path);
        final ext = picked.path.split('.').last.toLowerCase();
        final fileName = 'marketplace/${userId}_${DateTime.now().millisecondsSinceEpoch}_${_imageUrls.length}.$ext';

        await Supabase.instance.client.storage
            .from('posts')
            .upload(fileName, file);

        final url = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(fileName);

        if (!mounted) return;
        setState(() => _imageUrls.add(url));
      }

      if (mounted) setState(() => _isUploadingImage = false);

      // ── Bild-Erkennung: bei jedem neuen Upload ──
      if (files.isNotEmpty) {
        _classifyFirstImage(files.first.path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bild-Upload fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _classifyFirstImage(String imagePath) async {
    setState(() {
      _isClassifying = true;
      _detectedCar = false;
    });
    try {
      final result = await ImageClassifier.classifyImage(imagePath);
      if (!mounted) return;
      if (result != null) {
        final label = result.detectedLabel.toLowerCase();
        setState(() {
          _suggestion = result;
          _detectedCar = label == 'car' || label == 'vehicle' ||
              label == 'motor vehicle' || label == 'van' ||
              label == 'truck' || label == 'bus';
          _isClassifying = false;
        });
      } else {
        setState(() => _isClassifying = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  void _applySuggestion() {
    if (_suggestion == null) return;
    final cat = _suggestion!.category;
    setState(() {
      _selectedCategory = cat;
      _selectedSubcategory = null;
      _attributes = {};
      _suggestion = null;
    });

    // Bei Fahrzeugen direkt den Unterkategorie-Dropdown öffnen
    if (cat == 'Fahrzeuge') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final community = ref.read(communityProvider);
        final brightness = Theme.of(context).brightness;
        final accentColor = community?.accentColor ?? AppTheme.accentDark;
        final textOnCard = community?.textColor(brightness) ??
            (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
        final textMuted = community?.textMutedColor(brightness) ??
            (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
        _showVehicleSubSheet(accentColor, textOnCard, textMuted);
      });
    }
  }

  void _dismissSuggestion() {
    setState(() => _suggestion = null);
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
        final updates = <String, dynamic>{
          'title': title,
          'description': _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          'price': double.tryParse(_priceController.text.trim()),
          'condition': _selectedCondition,
          'category': _selectedCategory,
          'subcategory': _selectedSubcategory,
          'attributes': _attributes.isNotEmpty ? _attributes : {},
          'images': _imageUrls,
          'location_text': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          'shipping_type': _shippingType,
          'is_negotiable': _isNegotiable,
        };
        await ref.read(marketplaceNotifierProvider.notifier).updateListing(
          widget.listing!.id,
          title: title,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          price: double.tryParse(_priceController.text.trim()),
          condition: _selectedCondition,
          category: _selectedCategory,
          subcategory: _selectedSubcategory,
          attributes: _attributes.isNotEmpty ? _attributes : null,
          images: _imageUrls,
          locationText: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          shippingType: _shippingType,
          isNegotiable: _isNegotiable,
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
          subcategory: _selectedSubcategory,
          attributes: _attributes.isNotEmpty ? _attributes : null,
          community: community?.name,
          images: _imageUrls.isNotEmpty ? _imageUrls : null,
          locationText: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          shippingType: _shippingType,
          isNegotiable: _isNegotiable,
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
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final brightness = Theme.of(context).brightness;
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset, top: topPad),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height - topPad),
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

                  // ── KI-Vorschlag Banner ──
                  if (_isClassifying)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: accentColor),
                          ),
                          const SizedBox(width: 10),
                          Text('Bild wird analysiert...',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: textMuted)),
                        ],
                      ),
                    ),
                  if (_suggestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _suggestion!.detectedLabel.toLowerCase() == 'car' ||
                              _suggestion!.detectedLabel.toLowerCase() == 'vehicle' ||
                              _suggestion!.detectedLabel.toLowerCase() == 'motor vehicle' ||
                              _suggestion!.detectedLabel.toLowerCase() == 'van' ||
                              _suggestion!.detectedLabel.toLowerCase() == 'truck'
                                  ? Icons.directions_car_rounded
                                  : _suggestion!.detectedLabel.toLowerCase() == 'motorcycle'
                                      ? Icons.two_wheeler_rounded
                                      : Icons.search_rounded,
                              size: 20,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Erkannt: ${_suggestion!.category}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textOnCard,
                                    ),
                                  ),
                                  Text(
                                    '${(_suggestion!.confidence * 100).toStringAsFixed(0)}% Sicherheit',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _applySuggestion,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Übernehmen',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _dismissSuggestion,
                              child: Icon(Icons.close_rounded,
                                  size: 18, color: textMuted),
                            ),
                          ],
                        ),
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

                  // ── HAUPTKATEGORIE ──
                  _label('Kategorie'),
                  const SizedBox(height: 10),
                  // Primäre Kategorien (Fahrzeug & Teile)
                  Text('Fahrzeug & Teile',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withValues(alpha: 0.7),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MarketplaceCategories.primaryNames.map((cat) {
                      return _categoryChip(cat, accentColor, textOnCard);
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Sekundäre Kategorien (Andere)
                  Text('Andere Kategorien',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textOnCard.withValues(alpha: 0.35),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MarketplaceCategories.secondaryNames.map((cat) {
                      return _categoryChip(cat, accentColor, textOnCard);
                    }).toList(),
                  ),

                  // ── UNTERKATEGORIE ──
                  if (_selectedCategory != null &&
                      MarketplaceCategories.subsFor(_selectedCategory!).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _label('Unterkategorie'),
                    const SizedBox(height: 10),

                    // Fahrzeuge: gruppierter Dropdown (Motorräder / Autos / Sonstiges)
                    if (_selectedCategory == 'Fahrzeuge')
                      _buildVehicleSubDropdown(accentColor, textOnCard, textMuted)
                    else
                      // Alle anderen Kategorien: Wrap Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MarketplaceCategories.subsFor(_selectedCategory!).map((sub) {
                          final isSelected = _selectedSubcategory == sub;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedSubcategory = sub;
                              _attributes = {};
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor.withValues(alpha: 0.15)
                                    : textOnCard.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isSelected
                                        ? accentColor.withValues(alpha: 0.4)
                                        : textOnCard.withValues(alpha: 0.08)),
                              ),
                              child: Text(sub,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
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
                  ],

                  // ── DYNAMISCHE ATTRIBUTE ──
                  if (_selectedCategory != null)
                    AttributeFormFields(
                      category: _selectedCategory!,
                      subcategory: _selectedSubcategory,
                      attributes: _attributes,
                      accentColor: accentColor,
                      cardColor: brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                      textColor: textOnCard,
                      onAttributesChanged: (attrs) =>
                          setState(() => _attributes = attrs),
                    ),

                  const SizedBox(height: 20),

                  // Versandart
                  _label('Versandart'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('Nur Abholung', 'pickup'),
                      ('Versand', 'shipping'),
                      ('Beides', 'both'),
                    ].map((opt) {
                      final isSelected = _shippingType == opt.$2;
                      return GestureDetector(
                        onTap: () => setState(() => _shippingType = opt.$2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.withValues(alpha: 0.15)
                                : textOnCard.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.blue.withValues(alpha: 0.4)
                                    : textOnCard.withValues(alpha: 0.08)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              opt.$2 == 'pickup' ? Icons.place_rounded
                                  : opt.$2 == 'shipping' ? Icons.local_shipping_rounded
                                  : Icons.swap_horiz_rounded,
                              size: 16,
                              color: isSelected ? Colors.blue : textOnCard.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 6),
                            Text(opt.$1, style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.blue : textOnCard.withValues(alpha: 0.6),
                            )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // VB Toggle
                  GestureDetector(
                    onTap: () => setState(() => _isNegotiable = !_isNegotiable),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isNegotiable
                            ? Colors.orange.withValues(alpha: 0.1)
                            : textOnCard.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isNegotiable
                              ? Colors.orange.withValues(alpha: 0.4)
                              : textOnCard.withValues(alpha: 0.08)),
                      ),
                      child: Row(children: [
                        Icon(Icons.handshake_rounded, size: 18,
                          color: _isNegotiable ? Colors.orange.shade700 : textOnCard.withValues(alpha: 0.4)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('VB (Verhandlungsbasis)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: _isNegotiable ? FontWeight.w600 : FontWeight.w400,
                            color: _isNegotiable ? Colors.orange.shade700 : textOnCard.withValues(alpha: 0.6),
                          ))),
                        Icon(
                          _isNegotiable ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 22,
                          color: _isNegotiable ? Colors.orange.shade700 : textOnCard.withValues(alpha: 0.3),
                        ),
                      ]),
                    ),
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

  Widget _buildVehicleSubDropdown(Color accentColor, Color textOnCard, Color textMuted) {
    return GestureDetector(
      onTap: () => _showVehicleSubSheet(accentColor, textOnCard, textMuted),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: textOnCard.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedSubcategory != null
                ? accentColor.withValues(alpha: 0.4)
                : textOnCard.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedSubcategory != null
                  ? (MarketplaceCategories.isMotorcycleSub(_selectedSubcategory)
                      ? Icons.two_wheeler_rounded
                      : MarketplaceCategories.isCarSub(_selectedSubcategory)
                          ? Icons.directions_car_rounded
                          : Icons.category_rounded)
                  : Icons.arrow_drop_down_circle_outlined,
              size: 20,
              color: _selectedSubcategory != null
                  ? accentColor
                  : textOnCard.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedSubcategory ?? 'Fahrzeugtyp wählen...',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _selectedSubcategory != null
                      ? textOnCard
                      : textOnCard.withValues(alpha: 0.25),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: textOnCard.withValues(alpha: 0.4), size: 22),
          ],
        ),
      ),
    );
  }

  void _showVehicleSubSheet(Color accentColor, Color textOnCard, Color textMuted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final dividerColor = textOnCard.withValues(alpha: 0.06);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: textOnCard.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Fahrzeugtyp wählen',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textOnCard)),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                children: (_detectedCar
                    ? [
                        MarketplaceCategories.vehicleSubGroups[1], // Autos zuerst
                        MarketplaceCategories.vehicleSubGroups[0], // Motorräder
                        MarketplaceCategories.vehicleSubGroups[2], // Sonstiges
                      ]
                    : MarketplaceCategories.vehicleSubGroups
                ).map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gruppen-Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Row(
                          children: [
                            Icon(
                              group.label == 'Motorräder'
                                  ? Icons.two_wheeler_rounded
                                  : group.label == 'Autos'
                                      ? Icons.directions_car_rounded
                                      : Icons.category_rounded,
                              size: 16,
                              color: accentColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(group.label,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor.withValues(alpha: 0.7),
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      // Items
                      ...group.items.map((sub) {
                        final isSelected = _selectedSubcategory == sub;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          title: Text(sub,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? accentColor
                                      : textOnCard)),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: accentColor, size: 20)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedSubcategory = sub;
                              _attributes = {};
                            });
                            Navigator.of(ctx).pop();
                          },
                        );
                      }),
                      Divider(height: 1, color: dividerColor,
                          indent: 20, endIndent: 20),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String cat, Color accentColor, Color textOnCard) {
    final isSelected = _selectedCategory == cat;
    final icon = MarketplaceCategories.iconFor(cat);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = cat;
        _selectedSubcategory = null;
        _attributes = {};
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: isSelected ? accentColor : textOnCard.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(cat,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? accentColor
                        : textOnCard.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    final brightness = Theme.of(context).brightness;
    final community = ref.read(communityProvider);
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
    final community = ref.read(communityProvider);
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
