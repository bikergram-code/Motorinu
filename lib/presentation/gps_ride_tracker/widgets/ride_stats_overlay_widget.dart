import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RideStatsOverlayWidget extends StatelessWidget {
  final double distance;
  final Duration duration;
  final double averageSpeed;
  final double currentSpeed;
  final bool isTracking;
  final bool isPaused;

  const RideStatsOverlayWidget({
    super.key,
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.currentSpeed,
    required this.isTracking,
    required this.isPaused,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatSpeed(double kmh) {
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.all(4.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isTracking && isPaused)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                margin: EdgeInsets.only(bottom: 1.h),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningLight, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: 'pause_circle',
                      color: AppTheme.warningLight,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Fahrt pausiert',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.warningLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context: context,
                  icon: 'route',
                  label: 'Strecke',
                  value: _formatDistance(distance),
                  isPrimary: true,
                ),
                Container(
                  width: 1,
                  height: 6.h,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                _buildStatItem(
                  context: context,
                  icon: 'schedule',
                  label: 'Zeit',
                  value: _formatDuration(duration),
                  isPrimary: true,
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context: context,
                  icon: 'speed',
                  label: 'Ø Geschw.',
                  value: _formatSpeed(averageSpeed),
                  isPrimary: false,
                ),
                Container(
                  width: 1,
                  height: 5.h,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                _buildStatItem(
                  context: context,
                  icon: 'trending_up',
                  label: 'Aktuell',
                  value: _formatSpeed(currentSpeed),
                  isPrimary: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String icon,
    required String label,
    required String value,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          CustomIconWidget(
            iconName: icon,
            color: isPrimary
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurfaceVariant,
            size: isPrimary ? 24 : 20,
          ),
          SizedBox(height: 0.5.h),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            value,
            style: isPrimary
                ? theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  )
                : theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
          ),
        ],
      ),
    );
  }
}
