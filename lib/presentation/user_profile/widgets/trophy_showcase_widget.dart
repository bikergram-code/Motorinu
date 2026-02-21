import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Trophy showcase widget with horizontal category scrolling
class TrophyShowcaseWidget extends StatefulWidget {
  final List<Map<String, dynamic>> trophies;
  final Function(Map<String, dynamic>) onTrophyTap;

  const TrophyShowcaseWidget({
    super.key,
    required this.trophies,
    required this.onTrophyTap,
  });

  @override
  State<TrophyShowcaseWidget> createState() => _TrophyShowcaseWidgetState();
}

class _TrophyShowcaseWidgetState extends State<TrophyShowcaseWidget> {
  String _selectedCategory = 'Alle';
  final List<String> _categories = [
    'Alle',
    'Distanz',
    'Social',
    'Track',
    'DIY',
    'Saisonal',
  ];

  List<Map<String, dynamic>> get _filteredTrophies {
    if (_selectedCategory == 'Alle') {
      return widget.trophies;
    }
    return (widget.trophies as List)
        .where((trophy) => (trophy["category"] as String) == _selectedCategory)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trophäen',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/trophy-achievement-center');
                  },
                  icon: CustomIconWidget(
                    iconName: 'arrow_forward',
                    color: colorScheme.secondary,
                    size: 18,
                  ),
                  label: Text('Alle anzeigen'),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),

          // Category filter
          SizedBox(
            height: 5.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: EdgeInsets.only(right: 2.w),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: colorScheme.surface,
                    selectedColor: colorScheme.secondary.withValues(alpha: 0.2),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.secondary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.secondary
                          : colorScheme.outline.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 2.h),

          // Trophy grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: _filteredTrophies.isEmpty
                ? _buildEmptyState(context)
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3.w,
                      mainAxisSpacing: 2.h,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredTrophies.length,
                    itemBuilder: (context, index) {
                      final trophy = _filteredTrophies[index];
                      return _buildTrophyCard(context, trophy);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyCard(BuildContext context, Map<String, dynamic> trophy) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnlocked = trophy["unlocked"] as bool;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTrophyTap(trophy);
      },
      onLongPress: () {
        if (isUnlocked) {
          HapticFeedback.mediumImpact();
          _showShareOptions(context, trophy);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked
                ? _getTrophyColor(trophy["rarity"] as String, colorScheme)
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: _getTrophyColor(
                      trophy["rarity"] as String,
                      colorScheme,
                    ).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? _getTrophyColor(
                        trophy["rarity"] as String,
                        colorScheme,
                      ).withValues(alpha: 0.1)
                    : colorScheme.outline.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: trophy["icon"] as String,
                color: isUnlocked
                    ? _getTrophyColor(trophy["rarity"] as String, colorScheme)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 32,
              ),
            ),

            SizedBox(height: 1.h),

            // Trophy name
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Text(
                trophy["name"] as String,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isUnlocked
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (isUnlocked) ...[
              SizedBox(height: 0.5.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: _getTrophyColor(
                    trophy["rarity"] as String,
                    colorScheme,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trophy["rarity"] as String,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getTrophyColor(
                      trophy["rarity"] as String,
                      colorScheme,
                    ),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(8.w),
      child: Column(
        children: [
          CustomIconWidget(
            iconName: 'emoji_events',
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            size: 64,
          ),
          SizedBox(height: 2.h),
          Text(
            'Keine Trophäen in dieser Kategorie',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            'Fahre mehr, um Trophäen freizuschalten!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context, Map<String, dynamic> trophy) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'share',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text('Trophäe teilen'),
                onTap: () {
                  Navigator.pop(context);
                  // Share trophy
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'info',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text('Details anzeigen'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTrophyTap(trophy);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getTrophyColor(String rarity, ColorScheme colorScheme) {
    switch (rarity) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silber':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platin':
        return const Color(0xFFE5E4E2);
      default:
        return colorScheme.primary;
    }
  }
}
