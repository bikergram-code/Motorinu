import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Achievement Timeline Widget
/// Displays unlock history with timestamps and celebration replays
class AchievementTimelineWidget extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;

  const AchievementTimelineWidget({super.key, required this.achievements});

  Color _getMetalColor(int colorValue) {
    return Color(colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return achievements.isEmpty
        ? _buildEmptyState(context, theme)
        : Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(4.w),
              itemCount: achievements.length,
              separatorBuilder: (context, index) => Divider(
                height: 3.h,
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                return _buildTimelineItem(context, theme, achievements[index]);
              },
            ),
          );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: 'timeline',
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            size: 48,
          ),
          SizedBox(height: 2.h),
          Text(
            'Noch keine Erfolge freigeschaltet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            'Starte deine Reise und sammle Trophäen!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> achievement,
  ) {
    final metalColor = _getMetalColor(achievement['metalColor'] as int);

    return Row(
      children: [
        // Trophy Icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: metalColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: metalColor, width: 2),
          ),
          child: Center(
            child: CustomIconWidget(
              iconName: achievement['icon'] as String,
              color: metalColor,
              size: 24,
            ),
          ),
        ),

        SizedBox(width: 4.w),

        // Achievement Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement['trophyTitle'] as String,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 0.5.h),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: metalColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        achievement['category'] as String,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: metalColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  CustomIconWidget(
                    iconName: 'access_time',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 12,
                  ),
                  SizedBox(width: 1.w),
                  Flexible(
                    child: Text(
                      achievement['timestamp'] as String,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Replay Button
        IconButton(
          icon: CustomIconWidget(
            iconName: 'replay',
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🎉 Erfolg erneut gefeiert: ${achievement['trophyTitle']}',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'Erfolg erneut feiern',
        ),
      ],
    );
  }
}
