import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class FilterModalWidget extends StatefulWidget {
  final double minRating;
  final bool showOpenOnly;
  final String? priceRange;
  final List<String> selectedServices;
  final Function(double, bool, String?, List<String>) onApply;

  const FilterModalWidget({
    super.key,
    required this.minRating,
    required this.showOpenOnly,
    required this.priceRange,
    required this.selectedServices,
    required this.onApply,
  });

  @override
  State<FilterModalWidget> createState() => _FilterModalWidgetState();
}

class _FilterModalWidgetState extends State<FilterModalWidget> {
  late double _minRating;
  late bool _showOpenOnly;
  late String? _priceRange;
  late List<String> _selectedServices;

  final List<String> _priceRanges = ['\$', '\$\$', '\$\$\$'];
  final List<String> _availableServices = [
    'Wartung',
    'Reparatur',
    'Tuning',
    'Verkauf',
    'Übernachtung',
    'Trackdays',
    'Training',
    'Führerschein',
  ];

  @override
  void initState() {
    super.initState();
    _minRating = widget.minRating;
    _showOpenOnly = widget.showOpenOnly;
    _priceRange = widget.priceRange;
    _selectedServices = List.from(widget.selectedServices);
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
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _minRating = 0.0;
                        _showOpenOnly = false;
                        _priceRange = null;
                        _selectedServices.clear();
                      });
                    },
                    child: Text('Zurücksetzen'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mindestbewertung',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            label: _minRating.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() => _minRating = value);
                            },
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_minRating.toStringAsFixed(1)} ⭐',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Checkbox(
                          value: _showOpenOnly,
                          onChanged: (value) {
                            setState(() => _showOpenOnly = value ?? false);
                          },
                        ),
                        Text(
                          'Nur geöffnete Geschäfte',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Preisklasse',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w,
                      children: _priceRanges.map((range) {
                        final isSelected = _priceRange == range;
                        return ChoiceChip(
                          label: Text(range),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _priceRange = selected ? range : null;
                            });
                          },
                          selectedColor: theme.colorScheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onSecondary
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Services',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: _availableServices.map((service) {
                        final isSelected = _selectedServices.contains(service);
                        return FilterChip(
                          label: Text(service),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServices.add(service);
                              } else {
                                _selectedServices.remove(service);
                              }
                            });
                          },
                          selectedColor: theme.colorScheme.secondaryContainer,
                          checkmarkColor:
                              theme.colorScheme.onSecondaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Abbrechen'),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _minRating,
                          _showOpenOnly,
                          _priceRange,
                          _selectedServices,
                        );
                        Navigator.pop(context);
                      },
                      child: Text('Anwenden'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
