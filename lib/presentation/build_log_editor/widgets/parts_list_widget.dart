import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class PartsListWidget extends StatelessWidget {
  final List<dynamic> parts;
  final Function(int) onToggleInstalled;
  final VoidCallback onAddPart;

  const PartsListWidget({
    super.key,
    required this.parts,
    required this.onToggleInstalled,
    required this.onAddPart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: parts.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, index) {
              final part = parts[index];
              return _buildPartItem(context, part);
            },
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          InkWell(
            onTap: onAddPart,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'add',
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Teil hinzufügen',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartItem(BuildContext context, Map<String, dynamic> part) {
    final theme = Theme.of(context);
    final isInstalled = part["isInstalled"] ?? false;
    final price = part["price"] ?? 0.0;

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => _buildPartDetailsSheet(context, part),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggleInstalled(part["id"]);
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isInstalled ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: isInstalled
                        ? Colors.green
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isInstalled
                    ? CustomIconWidget(
                        iconName: 'check',
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part["name"] ?? '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isInstalled
                          ? TextDecoration.lineThrough
                          : null,
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
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            part["category"] ?? '',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          part["supplier"] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${price.toStringAsFixed(2)} €',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (part["partNumber"] != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(
                    part["partNumber"],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartDetailsSheet(
    BuildContext context,
    Map<String, dynamic> part,
  ) {
    final theme = Theme.of(context);
    final isInstalled = part["isInstalled"] ?? false;

    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  part["name"] ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: CustomIconWidget(
                  iconName: 'close',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildDetailRow(
            context,
            icon: 'category',
            label: 'Kategorie',
            value: part["category"] ?? '',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            context,
            icon: 'store',
            label: 'Lieferant',
            value: part["supplier"] ?? '',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            context,
            icon: 'tag',
            label: 'Teilenummer',
            value: part["partNumber"] ?? '',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            context,
            icon: 'euro',
            label: 'Preis',
            value: '${(part["price"] ?? 0.0).toStringAsFixed(2)} €',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            context,
            icon: 'calendar_today',
            label: 'Kaufdatum',
            value: part["purchaseDate"] ?? '',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            context,
            icon: isInstalled ? 'check_circle' : 'pending',
            label: 'Status',
            value: isInstalled ? 'Eingebaut' : 'Ausstehend',
            valueColor: isInstalled
                ? Colors.green
                : theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teil bearbeiten')),
                    );
                  },
                  icon: CustomIconWidget(
                    iconName: 'edit',
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  label: const Text('Bearbeiten'),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    onToggleInstalled(part["id"]);
                  },
                  icon: CustomIconWidget(
                    iconName: isInstalled ? 'remove_circle' : 'check_circle',
                    color: theme.colorScheme.onSecondary,
                    size: 20,
                  ),
                  label: Text(isInstalled ? 'Entfernen' : 'Einbauen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CustomIconWidget(
          iconName: icon,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
