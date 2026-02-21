import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RideCompleteDialogWidget extends StatelessWidget {
  final Map<String, dynamic> rideData;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const RideCompleteDialogWidget({
    super.key,
    required this.rideData,
    required this.onShare,
    required this.onSave,
    required this.onDiscard,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours Std. $minutes Min.';
    }
    return '$minutes Min.';
  }

  String _formatDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatSpeed(double kmh) {
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = rideData['distance'] as double;
    final duration = rideData['duration'] as Duration;
    final averageSpeed = rideData['averageSpeed'] as double;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 90.w, maxHeight: 70.h),
        padding: EdgeInsets.all(5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.successLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: 'check_circle',
                color: AppTheme.successLight,
                size: 48,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Fahrt beendet!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Großartige Fahrt! Möchten Sie diese mit der Community teilen?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    context: context,
                    icon: 'route',
                    label: 'Gesamtstrecke',
                    value: _formatDistance(distance),
                  ),
                  SizedBox(height: 2.h),
                  _buildStatRow(
                    context: context,
                    icon: 'schedule',
                    label: 'Fahrzeit',
                    value: _formatDuration(duration),
                  ),
                  SizedBox(height: 2.h),
                  _buildStatRow(
                    context: context,
                    icon: 'speed',
                    label: 'Ø Geschwindigkeit',
                    value: _formatSpeed(averageSpeed),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: onShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'share',
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Im Feed teilen',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.h),
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: OutlinedButton(
                onPressed: onSave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outline, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'save',
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Nur speichern',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.h),
            TextButton(
              onPressed: onDiscard,
              child: Text(
                'Verwerfen',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required BuildContext context,
    required String icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CustomIconWidget(
          iconName: icon,
          color: theme.colorScheme.secondary,
          size: 24,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
