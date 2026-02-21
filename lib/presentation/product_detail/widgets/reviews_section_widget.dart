import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class ReviewsSectionWidget extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const ReviewsSectionWidget({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bewertungen',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Alle ansehen')),
            ],
          ),
          const SizedBox(height: 16),
          ...reviews
              .take(2)
              .map((review) => _buildReviewCard(context, theme, review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> review,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipOval(
                  child: CustomImageWidget(
                    imageUrl: review["userAvatar"],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    semanticLabel: review["semanticLabel"],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review["userName"],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => CustomIconWidget(
                            iconName: index < review["rating"]
                                ? 'star'
                                : 'star_border',
                            color: AppTheme.warningLight,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review["date"]),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review["comment"],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if ((review["images"] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review["images"] as List).length,
                itemBuilder: (context, index) {
                  final image = (review["images"] as List)[index];
                  return Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomImageWidget(
                        imageUrl: image["url"],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        semanticLabel: image["semanticLabel"],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              CustomIconWidget(
                iconName: 'thumb_up_outlined',
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Hilfreich (${review["helpful"]})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (reviews.indexOf(review) < reviews.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 7) {
      return 'Vor ${difference.inDays} Tagen';
    } else if (difference.inDays < 30) {
      return 'Vor ${(difference.inDays / 7).floor()} Wochen';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
