import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class TrophyGridWidget extends StatelessWidget {
  /// Erwartet eine Liste von Trophy-Maps wie:
  /// {
  ///  "id": 1,
  ///  "name": "1000 km",
  ///  "description": "...",
  ///  "icon": "route",
  ///  "category": "Distanz",
  ///  "rarity": "Bronze",
  ///  "unlocked": true,
  /// }
  final List<Map<String, dynamic>> trophies;

  /// Optionaler Tap-Callback
  final void Function(Map<String, dynamic> trophy)? onTrophyTap;

  const TrophyGridWidget({
    super.key,
    required this.trophies,
    this.onTrophyTap,
  });

  String _str(Map<String, dynamic> t, String key, {String fallback = ''}) {
    final v = t[key];
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  bool _bool(Map<String, dynamic> t, String key, {bool fallback = false}) {
    final v = t[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'ja') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'nein') return false;
    }
    return fallback;
  }

  Color _rarityColor(String rarity, ColorScheme scheme) {
    switch (rarity) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silber':
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platin':
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (trophies.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(4.w),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
          ),
          child: Row(
            children: [
              CustomIconWidget(
                iconName: 'emoji_events',
                color: theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Noch keine Trophäen vorhanden.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: trophies.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 2.h,
        crossAxisSpacing: 4.w,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final trophy = trophies[index];
        return _buildTrophyCard(context, trophy);
      },
    );
  }

  Widget _buildTrophyCard(BuildContext context, Map<String, dynamic> trophy) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final name = _str(trophy, 'name', fallback: 'Unbekannte Trophäe');
    final description = _str(trophy, 'description', fallback: '');
    final iconName = _str(trophy, 'icon', fallback: 'emoji_events');
    final rarity = _str(trophy, 'rarity', fallback: 'Bronze');
    final category = _str(trophy, 'category', fallback: '');
    final unlocked = _bool(trophy, 'unlocked', fallback: false);

    final rarityColor = _rarityColor(rarity, scheme);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTrophyTap == null ? null : () => onTrophyTap!(trophy),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: unlocked
              ? scheme.surface
              : scheme.surfaceContainerHighest.withOpacity(0.25),
          border: Border.all(
            color: unlocked
                ? rarityColor.withOpacity(0.55)
                : scheme.outline.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Rarity chip
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? rarityColor.withOpacity(0.12)
                        : scheme.outline.withOpacity(0.10),
                  ),
                  child: CustomIconWidget(
                    iconName: iconName,
                    color: unlocked
                        ? rarityColor
                        : scheme.onSurfaceVariant.withOpacity(0.55),
                    size: 26,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: unlocked
                        ? rarityColor.withOpacity(0.10)
                        : scheme.outline.withOpacity(0.10),
                    border: Border.all(
                      color: unlocked
                          ? rarityColor.withOpacity(0.55)
                          : scheme.outline.withOpacity(0.30),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    rarity,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? rarityColor
                          : scheme.onSurfaceVariant.withOpacity(0.65),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 1.6.h),

            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            if (category.isNotEmpty) ...[
              SizedBox(height: 0.6.h),
              Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],

            const Spacer(),

            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

            SizedBox(height: 0.8.h),

            Row(
              children: [
                CustomIconWidget(
                  iconName: unlocked ? 'lock_open' : 'lock',
                  color: unlocked
                      ? scheme.secondary
                      : scheme.onSurfaceVariant.withOpacity(0.55),
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Flexible(
                  child: Text(
                    unlocked ? 'Freigeschaltet' : 'Gesperrt',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: unlocked
                          ? scheme.secondary
                          : scheme.onSurfaceVariant.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
