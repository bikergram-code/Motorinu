import 'package:flutter/material.dart';
import 'package:bikergram/widgets/bikergram_progress_bar.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';

/// Trophy Detail Modal Widget
/// Displays detailed trophy information with sharing options
class TrophyDetailModalWidget extends StatelessWidget {
  final Map<String, dynamic> trophy;

  const TrophyDetailModalWidget({super.key, required this.trophy});

  Color _getMetalColor() {
    return Color(trophy['metalColor'] as int);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = trophy['isUnlocked'] as bool;
    final metalColor = _getMetalColor();

    return Container(
      height: 75.h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 2.h),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trophy Image/Icon
                  Container(
                    height: 30.h,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? metalColor.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnlocked
                            ? metalColor.withValues(alpha: 0.3)
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isUnlocked)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomImageWidget(
                              imageUrl: trophy['imageUrl'] as String,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel: trophy['semanticLabel'] as String,
                            ),
                          ),
                        if (!isUnlocked)
                          CustomIconWidget(
                            iconName: trophy['icon'] as String,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                            size: 80,
                          ),
                        if (isUnlocked)
                          Positioned(
                            top: 4.w,
                            right: 4.w,
                            child: Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: metalColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Trophy Title
                  Text(
                    trophy['title'] as String,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isUnlocked
                          ? metalColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 1.h),

                  // Category Badge
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: metalColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: metalColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        trophy['category'] as String,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: metalColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Description
                  Text(
                    trophy['description'] as String,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 3.h),

                  // Unlock Status
                  if (isUnlocked)
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: metalColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: metalColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomIconWidget(
                            iconName: 'event_available',
                            color: metalColor,
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Freigeschaltet am ${trophy['unlockDate']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: metalColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Progress Indicator
                  if (!isUnlocked && trophy['progress'] != null)
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fortschritt',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (trophy['currentCount'] != null &&
                                  trophy['targetCount'] != null)
                                Text(
                                  '${trophy['currentCount']} / ${trophy['targetCount']}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 1.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: BikergramProgressBar(
                              progress: ((trophy['progress'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
                              height: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 3.h),

                  // Action Buttons
                  if (isUnlocked)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Trophäe wird geteilt...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: CustomIconWidget(
                              iconName: 'share',
                              color: theme.colorScheme.onSecondary,
                              size: 20,
                            ),
                            label: Text('Teilen'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            icon: CustomIconWidget(
                              iconName: 'close',
                              color: theme.colorScheme.onSurface,
                              size: 20,
                            ),
                            label: Text('Schließen'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (!isUnlocked)
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Text('Schließen'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      ),
                    ),

                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
