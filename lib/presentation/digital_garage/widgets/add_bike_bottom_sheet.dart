import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';

class AddBikeBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onBikeAdded;

  const AddBikeBottomSheet({super.key, required this.onBikeAdded});

  @override
  State<AddBikeBottomSheet> createState() => _AddBikeBottomSheetState();
}

class _AddBikeBottomSheetState extends State<AddBikeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _displacementController = TextEditingController();
  final _powerController = TextEditingController();
  final _torqueController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedCategory = 'Sport';
  String? _selectedImageUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Sport',
    'Naked',
    'Tour',
    'Adventure',
    'Cruiser',
    'Enduro',
    'Supermoto',
    'Classic',
  ];

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _displacementController.dispose();
    _powerController.dispose();
    _torqueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();

    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoberechtigung erforderlich'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImageUrl =
            'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=800';
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte füge ein Foto hinzu'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final bikeData = {
        "make": _makeController.text,
        "model": _modelController.text,
        "year": int.parse(_yearController.text),
        "imageUrl": _selectedImageUrl!,
        "semanticLabel":
            "${_makeController.text} ${_modelController.text} motorcycle",
        "category": _selectedCategory,
        "specifications": {
          "Hubraum": "${_displacementController.text} ccm",
          "Leistung": "${_powerController.text} PS",
          "Drehmoment": "${_torqueController.text} Nm",
          "Gewicht": "${_weightController.text} kg",
          "Baujahr": _yearController.text,
        },
      };

      widget.onBikeAdded(bikeData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 10.w,
              height: 0.5.h,
              margin: EdgeInsets.symmetric(vertical: 1.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Motorrad hinzufügen',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 25.h,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.5,
                              ),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _selectedImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CustomImageWidget(
                                    imageUrl: _selectedImageUrl!,
                                    width: double.infinity,
                                    height: 25.h,
                                    fit: BoxFit.cover,
                                    semanticLabel: "Selected motorcycle image",
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'add_a_photo',
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'Foto hinzufügen',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 3.h),
                      // Make
                      TextFormField(
                        controller: _makeController,
                        decoration: const InputDecoration(
                          labelText: 'Marke *',
                          hintText: 'z.B. Ducati, BMW, Yamaha',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Marke eingeben';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 2.h),
                      // Model
                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Modell *',
                          hintText: 'z.B. Panigale V4, S 1000 RR',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Modell eingeben';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 2.h),
                      // Year
                      TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'Baujahr *',
                          hintText: 'z.B. 2023',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Baujahr eingeben';
                          }
                          final year = int.tryParse(value);
                          if (year == null || year < 1900 || year > 2026) {
                            return 'Ungültiges Jahr';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 2.h),
                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategorie *',
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Technische Daten (optional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // Displacement
                      TextFormField(
                        controller: _displacementController,
                        decoration: const InputDecoration(
                          labelText: 'Hubraum',
                          hintText: 'z.B. 1103',
                          suffixText: 'ccm',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      SizedBox(height: 2.h),
                      // Power
                      TextFormField(
                        controller: _powerController,
                        decoration: const InputDecoration(
                          labelText: 'Leistung',
                          hintText: 'z.B. 214',
                          suffixText: 'PS',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      SizedBox(height: 2.h),
                      // Torque
                      TextFormField(
                        controller: _torqueController,
                        decoration: const InputDecoration(
                          labelText: 'Drehmoment',
                          hintText: 'z.B. 124',
                          suffixText: 'Nm',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      SizedBox(height: 2.h),
                      // Weight
                      TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Gewicht',
                          hintText: 'z.B. 195',
                          suffixText: 'kg',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      SizedBox(height: 4.h),
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(
                            'Motorrad hinzufügen',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
