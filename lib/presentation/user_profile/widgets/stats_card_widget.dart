import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/bikergram_progress_bar.dart';

class StatsCardWidget extends StatelessWidget {
  final Map<String, dynamic> stats;

  const StatsCardWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final int currentXP = (stats['currentXP'] as int?) ?? 0;
    final int nextLevelXP = (stats['nextLevelXP'] as int?) ?? 100;
    final double p = nextLevelXP <= 0 ? 0.0 : (currentXP / nextLevelXP).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dein Fortschritt',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 1.1.h),
          Row(
            children: [
              Text(
                '$currentXP XP',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.secondary,
                ),
              ),
              const Spacer(),
              Text(
                '$nextLevelXP XP',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.9.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BikergramProgressBar(
              progress: p,
              height: 16,
            ),
          ),
        ],
      ),
    );
  }
}
