import 'package:flutter/material.dart';
import 'package:bikergram/widgets/bikergram_progress_bar.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class CostSummaryWidget extends StatelessWidget {
  final double totalCost;
  final double budgetLimit;
  final List<dynamic> parts;

  const CostSummaryWidget({
    super.key,
    required this.totalCost,
    required this.budgetLimit,
    required this.parts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverBudget = totalCost > budgetLimit;
    final budgetPercentage = (totalCost / budgetLimit * 100).clamp(0, 100);
    final remainingBudget = budgetLimit - totalCost;

    final installedParts = parts
        .where((p) => p["isInstalled"] == true)
        .toList();
    final pendingParts = parts.where((p) => p["isInstalled"] == false).toList();

    final installedCost = installedParts.fold<double>(
      0.0,
      (sum, part) => sum + (part["price"] ?? 0.0),
    );
    final pendingCost = pendingParts.fold<double>(
      0.0,
      (sum, part) => sum + (part["price"] ?? 0.0),
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isOverBudget ? 2 : 1,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kostenübersicht',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isOverBudget)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'warning',
                        color: theme.colorScheme.error,
                        size: 16,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Über Budget',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gesamtkosten',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${totalCost.toStringAsFixed(2)} €',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isOverBudget ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${budgetLimit.toStringAsFixed(2)} €',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOverBudget ? 'Über Budget' : 'Verbleibend',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${remainingBudget.abs().toStringAsFixed(2)} €',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOverBudget
                          ? theme.colorScheme.error
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: budgetPercentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOverBudget
                          ? theme.colorScheme.error
                          : budgetPercentage > 80
                          ? Colors.orange
                          : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildCostBreakdown(
                  context,
                  icon: 'check_circle',
                  label: 'Eingebaut',
                  amount: installedCost,
                  count: installedParts.length,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildCostBreakdown(
                  context,
                  icon: 'pending',
                  label: 'Ausstehend',
                  amount: pendingCost,
                  count: pendingParts.length,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown(
    BuildContext context, {
    required String icon,
    required String label,
    required double amount,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(iconName: icon, color: color, size: 16),
              SizedBox(width: 1.w),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            '${amount.toStringAsFixed(2)} €',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$count ${count == 1 ? 'Teil' : 'Teile'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
