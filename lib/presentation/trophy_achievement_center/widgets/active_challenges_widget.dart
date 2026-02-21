import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class ActiveChallengesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> challenges;

  const ActiveChallengesWidget({
    super.key,
    required this.challenges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (challenges.isEmpty) {
      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(
          'Keine aktiven Challenges.',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktive Challenges',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 1.2.h),
        ...challenges.map((c) {
          final title = (c['title'] ?? 'Challenge') as String;
          final subtitle = (c['subtitle'] ?? '') as String;
          return Container(
            margin: EdgeInsets.only(bottom: 1.2.h),
            padding: EdgeInsets.all(3.6.w),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: cs.secondary),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 0.4.h),
                        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
