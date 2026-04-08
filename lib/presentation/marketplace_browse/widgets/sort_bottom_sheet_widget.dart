import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SortBottomSheetWidget extends StatelessWidget {
  final Function(String) onSortSelected;

  const SortBottomSheetWidget({super.key, required this.onSortSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sortOptions = [
      {'label': 'Relevanz', 'icon': 'sort'},
      {'label': 'Preis aufsteigend', 'icon': 'arrow_upward'},
      {'label': 'Preis absteigend', 'icon': 'arrow_downward'},
      {'label': 'Entfernung', 'icon': 'location_on'},
      {'label': 'Neueste', 'icon': 'schedule'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 1.h),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Text(
                'Sortieren nach',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...sortOptions.map((option) {
              return ListTile(
                leading: CustomIconWidget(
                  iconName: option['icon'] as String,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  option['label'] as String,
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSortSelected(option['label'] as String);
                  Navigator.pop(context);
                },
              );
            }),
            SizedBox(height: 1.h),
          ],
        ),
      ),
    );
  }
}
