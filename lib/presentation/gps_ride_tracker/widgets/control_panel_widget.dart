import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ControlPanelWidget extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const ControlPanelWidget({
    super.key,
    required this.isTracking,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isTracking)
                _buildStartButton(context)
              else ...[
                Row(
                  children: [
                    Expanded(child: _buildPauseResumeButton(context)),
                    SizedBox(width: 4.w),
                    Expanded(child: _buildStopButton(context)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton(
        onPressed: onStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'play_arrow',
              color: Colors.white,
              size: 28,
            ),
            SizedBox(width: 2.w),
            Text(
              'Fahrt starten',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseResumeButton(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 6.h,
      child: OutlinedButton(
        onPressed: isPaused ? onResume : onPause,
        style: OutlinedButton.styleFrom(
          foregroundColor: isPaused
              ? AppTheme.successLight
              : AppTheme.warningLight,
          side: BorderSide(
            color: isPaused ? AppTheme.successLight : AppTheme.warningLight,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: isPaused ? 'play_arrow' : 'pause',
              color: isPaused ? AppTheme.successLight : AppTheme.warningLight,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text(
              isPaused ? 'Fortsetzen' : 'Pause',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isPaused ? AppTheme.successLight : AppTheme.warningLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 6.h,
      child: ElevatedButton(
        onPressed: onStop,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.errorLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(iconName: 'stop', color: Colors.white, size: 24),
            SizedBox(width: 2.w),
            Text(
              'Beenden',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
