import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_image_widget.dart';

class StoryItemWidget extends StatelessWidget {
  final Map<String, dynamic> story;
  final VoidCallback onTap;

  const StoryItemWidget({super.key, required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNewStory = story["hasNewStory"] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasNewStory
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.secondary,
                          theme.colorScheme.secondary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !hasNewStory
                    ? Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: CustomImageWidget(
                    imageUrl: story["avatar"] as String? ?? "",
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    semanticLabel:
                        story["semanticLabel"] as String? ?? "User avatar",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              story["username"] as String? ?? "",
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: hasNewStory ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
