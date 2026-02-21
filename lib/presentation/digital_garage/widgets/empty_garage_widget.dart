import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class EmptyGarageWidget extends StatelessWidget {
  final VoidCallback onAddBike;

  const EmptyGarageWidget({super.key, required this.onAddBike});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            Container(
              width: 60.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'two_wheeler',
                    color: theme.colorScheme.secondary,
                    size: 80,
                  ),
                  SizedBox(height: 2.h),
                  CustomIconWidget(
                    iconName: 'add_circle_outline',
                    color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    size: 40,
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            // Title
            Text(
              'Deine Garage ist leer',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            // Description
            Text(
              'Füge dein erstes Motorrad hinzu und beginne, deine Sammlung zu dokumentieren. Verfolge Modifikationen, erstelle Build-Logs und teile deine Bikes mit der Community.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            // CTA Button
            SizedBox(
              width: 70.w,
              height: 6.h,
              child: ElevatedButton.icon(
                onPressed: onAddBike,
                icon: CustomIconWidget(
                  iconName: 'add',
                  color: theme.colorScheme.onSecondary,
                  size: 24,
                ),
                label: Text(
                  'Erstes Motorrad hinzufügen',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            // Features list
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildFeatureItem(
                    context,
                    icon: 'photo_camera',
                    title: 'Fotos & Spezifikationen',
                    description:
                        'Dokumentiere dein Bike mit Bildern und technischen Details',
                  ),
                  SizedBox(height: 2.h),
                  _buildFeatureItem(
                    context,
                    icon: 'build',
                    title: 'Modifikationen tracken',
                    description:
                        'Halte alle Umbauten und Tuning-Maßnahmen fest',
                  ),
                  SizedBox(height: 2.h),
                  _buildFeatureItem(
                    context,
                    icon: 'share',
                    title: 'Mit Community teilen',
                    description:
                        'Zeige deine Bikes anderen Bikern auf BikerGram',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomIconWidget(
            iconName: icon,
            color: theme.colorScheme.secondary,
            size: 24,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
