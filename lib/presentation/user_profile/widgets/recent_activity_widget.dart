import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Recent activity feed widget showing latest rides, posts, and achievements
class RecentActivityWidget extends StatelessWidget {
  final List<Map<String, dynamic>> activities;

  const RecentActivityWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              'Letzte Aktivitäten',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(height: 2.h),

          // Activity list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: activities.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _buildActivityCard(context, activity);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    Map<String, dynamic> activity,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = activity["type"] as String;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity icon
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: _getActivityColor(
                type,
                colorScheme,
              ).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CustomIconWidget(
              iconName: _getActivityIcon(type),
              color: _getActivityColor(type, colorScheme),
              size: 24,
            ),
          ),

          SizedBox(width: 3.w),

          // Activity content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity["title"] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.5.h),
                Text(
                  activity["description"] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'schedule',
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      size: 14,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      _formatTimestamp(activity["timestamp"] as DateTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Activity image (if available)
          if (activity["image"] != null) ...[
            SizedBox(width: 3.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomImageWidget(
                imageUrl: activity["image"] as String,
                width: 15.w,
                height: 15.w,
                fit: BoxFit.cover,
                semanticLabel: activity["imageSemanticLabel"] as String,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getActivityIcon(String type) {
    switch (type) {
      case 'ride':
        return 'two_wheeler';
      case 'post':
        return 'photo_camera';
      case 'trophy':
        return 'emoji_events';
      case 'modification':
        return 'build';
      default:
        return 'notifications';
    }
  }

  Color _getActivityColor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'ride':
        return colorScheme.secondary;
      case 'post':
        return const Color(0xFF17A2B8);
      case 'trophy':
        return const Color(0xFFFFD700);
      case 'modification':
        return const Color(0xFF28A745);
      default:
        return colorScheme.primary;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'vor ${difference.inMinutes} Min.';
    } else if (difference.inHours < 24) {
      return 'vor ${difference.inHours} Std.';
    } else if (difference.inDays < 7) {
      return 'vor ${difference.inDays} Tag${difference.inDays > 1 ? 'en' : ''}';
    } else {
      return '${timestamp.day}.${timestamp.month}.${timestamp.year}';
    }
  }
}
