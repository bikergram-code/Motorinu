import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';

class StepCardWidget extends StatelessWidget {
  final Map<String, dynamic> step;
  final int stepNumber;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const StepCardWidget({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = step["isCompleted"] ?? false;
    final hasBeforeImage = step["beforeImage"] != null;
    final hasAfterImage = step["afterImage"] != null;
    final workDuration = step["workDuration"] ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Slidable(
        key: ValueKey(step["id"]),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                onEdit();
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              icon: Icons.edit,
              label: 'Bearbeiten',
            ),
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                onDuplicate();
              },
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
              icon: Icons.content_copy,
              label: 'Duplizieren',
            ),
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.heavyImpact();
                onDelete();
              },
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              icon: Icons.delete,
              label: 'Löschen',
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isCompleted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(4.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onToggleComplete();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green
                                : theme.colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? CustomIconWidget(
                                iconName: 'check',
                                color: Colors.white,
                                size: 20,
                              )
                            : Center(
                                child: Text(
                                  stepNumber.toString(),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step["title"] ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (workDuration > 0) ...[
                            SizedBox(height: 0.5.h),
                            Row(
                              children: [
                                CustomIconWidget(
                                  iconName: 'schedule',
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 14,
                                ),
                                SizedBox(width: 1.w),
                                Flexible(
                                  child: Text(
                                    '$workDuration Min.',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: CustomIconWidget(
                        iconName: 'more_vert',
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) =>
                              _buildActionSheet(context, theme),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (step["description"] != null &&
                  (step["description"] as String).isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    step["description"],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (hasBeforeImage || hasAfterImage) ...[
                SizedBox(height: 2.h),
                SizedBox(
                  height: 20.h,
                  child: Row(
                    children: [
                      if (hasBeforeImage)
                        Expanded(
                          child: _buildImagePreview(
                            context,
                            imageUrl: step["beforeImage"],
                            label: 'Vorher',
                            semanticLabel: step["beforeImageLabel"],
                          ),
                        ),
                      if (hasBeforeImage && hasAfterImage) SizedBox(width: 2.w),
                      if (hasAfterImage)
                        Expanded(
                          child: _buildImagePreview(
                            context,
                            imageUrl: step["afterImage"],
                            label: 'Nachher',
                            semanticLabel: step["afterImageLabel"],
                          ),
                        ),
                      if (!hasBeforeImage || !hasAfterImage)
                        Expanded(
                          child: _buildAddPhotoButton(
                            context,
                            label: !hasBeforeImage
                                ? 'Vorher-Foto'
                                : 'Nachher-Foto',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (step["notes"] != null &&
                  (step["notes"] as String).isNotEmpty) ...[
                SizedBox(height: 2.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(3.w),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'note',
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 16,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Notizen',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        step["notes"],
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(
    BuildContext context, {
    required String imageUrl,
    required String label,
    required String semanticLabel,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomImageWidget(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 50.h,
                  fit: BoxFit.contain,
                  semanticLabel: semanticLabel,
                ),
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
          ),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomImageWidget(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton(BuildContext context, {required String label}) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label hinzufügen')));
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'add_a_photo',
              color: theme.colorScheme.onSurfaceVariant,
              size: 32,
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheet(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CustomIconWidget(
              iconName: 'edit',
              color: theme.colorScheme.primary,
              size: 24,
            ),
            title: const Text('Bearbeiten'),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: CustomIconWidget(
              iconName: 'content_copy',
              color: theme.colorScheme.primary,
              size: 24,
            ),
            title: const Text('Duplizieren'),
            onTap: () {
              Navigator.pop(context);
              onDuplicate();
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
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
