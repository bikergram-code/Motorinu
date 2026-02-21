import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class FilterModalWidget extends StatefulWidget {
  final Function(int) onApplyFilters;

  const FilterModalWidget({super.key, required this.onApplyFilters});

  @override
  State<FilterModalWidget> createState() => _FilterModalWidgetState();
}

class _FilterModalWidgetState extends State<FilterModalWidget> {
  String _selectedCategory = 'Alle';
  RangeValues _priceRange = const RangeValues(0, 20000);
  String _selectedCondition = 'Alle';
  double _locationRadius = 50;
  String _sellerType = 'Alle';

  final List<String> _categories = [
    'Alle',
    'Teile',
    'Ausrüstung',
    'Motorräder',
    'Track-Gear',
  ];
  final List<String> _conditions = ['Alle', 'Neu', 'Neuwertig', 'Gebraucht'];
  final List<String> _sellerTypes = ['Alle', 'Privat', 'Gewerblich'];

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategory != 'Alle') count++;
    if (_priceRange.start > 0 || _priceRange.end < 20000) count++;
    if (_selectedCondition != 'Alle') count++;
    if (_locationRadius < 50) count++;
    if (_sellerType != 'Alle') count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'Alle';
      _priceRange = const RangeValues(0, 20000);
      _selectedCondition = 'Alle';
      _locationRadius = 50;
      _sellerType = 'Alle';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 90.h,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, colorScheme),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategorySection(theme, colorScheme),
                    SizedBox(height: 3.h),
                    _buildPriceRangeSection(theme, colorScheme),
                    SizedBox(height: 3.h),
                    _buildConditionSection(theme, colorScheme),
                    SizedBox(height: 3.h),
                    _buildLocationRadiusSection(theme, colorScheme),
                    SizedBox(height: 3.h),
                    _buildSellerTypeSection(theme, colorScheme),
                  ],
                ),
              ),
            ),
            _buildFooter(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _resetFilters();
                },
                child: Text(
                  'Zurücksetzen',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              IconButton(
                icon: CustomIconWidget(
                  iconName: 'close',
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategorie',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.secondary
                        : colorScheme.outline.withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preisspanne',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '€ ${_priceRange.start.toInt()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '€ ${_priceRange.end.toInt()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 20000,
          divisions: 200,
          activeColor: colorScheme.secondary,
          inactiveColor: colorScheme.outline.withValues(alpha: 0.3),
          onChanged: (RangeValues values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
      ],
    );
  }

  Widget _buildConditionSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zustand',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _conditions.map((condition) {
            final isSelected = _selectedCondition == condition;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedCondition = condition;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.secondary
                        : colorScheme.outline.withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  condition,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationRadiusSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Umkreis',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_locationRadius.toInt()} km',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: _locationRadius,
          min: 5,
          max: 100,
          divisions: 19,
          activeColor: colorScheme.secondary,
          inactiveColor: colorScheme.outline.withValues(alpha: 0.3),
          onChanged: (double value) {
            setState(() {
              _locationRadius = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSellerTypeSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verkäufertyp',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _sellerTypes.map((type) {
            final isSelected = _sellerType == type;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _sellerType = type;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.secondary
                        : colorScheme.outline.withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  type,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.onApplyFilters(_getActiveFilterCount());
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 6.h),
        ),
        child: Text(
          'Filter anwenden (${_getActiveFilterCount()})',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSecondary,
          ),
        ),
      ),
    );
  }
}
