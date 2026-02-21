import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';

class MotorcycleCardWidget extends StatelessWidget {
  final Map<String, dynamic> bike;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback onSetPrimary;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onDuplicate;

  const MotorcycleCardWidget({
    super.key,
    required this.bike,
    required this.isPrimary,
    required this.onTap,
    required this.onSetPrimary,
    required this.onArchive,
    required this.onDelete,
    required this.onShare,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Slidable(
        key: ValueKey(bike["id"]),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                HapticFeedback.lightImpact();
                onShare();
              },
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
              icon: Icons.share,
              label: 'Teilen',
              borderRadius: BorderRadius.circular(12),
            ),
            SlidableAction(
              onPressed: (context) {
                HapticFeedback.lightImpact();
                onDuplicate();
              },
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              icon: Icons.content_copy,
              label: 'Duplizieren',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showContextMenu(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CustomImageWidget(
                        imageUrl: bike["imageUrl"],
                        width: double.infinity,
                        height: 25.h,
                        fit: BoxFit.cover,
                        semanticLabel: bike["semanticLabel"],
                      ),
                    ),
                    // Primary badge
                    isPrimary
                        ? Positioned(
                            top: 2.h,
                            left: 3.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 3.w,
                                vertical: 0.8.h,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'star',
                                    color: theme.colorScheme.onSecondary,
                                    size: 16,
                                  ),
                                  SizedBox(width: 1.w),
                                  Text(
                                    'Hauptbike',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    // Modification count badge
                    Positioned(
                      top: 2.h,
                      right: 3.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 0.8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomIconWidget(
                              iconName: 'build',
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              '${bike["modificationCount"]}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Details section
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Make and model
                      Text(
                        '${bike["make"]} ${bike["model"]}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 0.5.h),
                      // Year and category
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'calendar_today',
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 16,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            '${bike["year"]}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bike["category"],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pushNamed(
                                  context,
                                  '/build-log-editor',
                                );
                              },
                              icon: CustomIconWidget(
                                iconName: 'edit_note',
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                'Build-Log',
                                style: theme.textTheme.labelMedium,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 1.2.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pushNamed(
                                  context,
                                  '/marketplace-browse',
                                );
                              },
                              icon: CustomIconWidget(
                                iconName: 'shopping_cart',
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                'Teile',
                                style: theme.textTheme.labelMedium,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 1.2.h),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10.w,
                height: 0.5.h,
                margin: EdgeInsets.symmetric(vertical: 1.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: isPrimary ? 'star' : 'star_outline',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  isPrimary ? 'Hauptbike (aktiv)' : 'Als Hauptbike festlegen',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (!isPrimary) {
                    onSetPrimary();
                  }
                },
                enabled: !isPrimary,
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'archive',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text('Archivieren', style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  onArchive();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete',
                  color: theme.colorScheme.error,
                  size: 24,
                ),
                title: Text(
                  'Löschen',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }
}
