import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:bikergram/widgets/bikergram_progress_bar.dart';

import '../../../../core/app_export.dart';
import '../../../domain/xp_calculator.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Level Progress Header Widget
/// Displays current user level with animated progress bar and XP information
class LevelProgressHeaderWidget extends StatefulWidget {
  final Map<String, dynamic> userLevelData;

  const LevelProgressHeaderWidget({super.key, required this.userLevelData});

  @override
  State<LevelProgressHeaderWidget> createState() =>
      _LevelProgressHeaderWidgetState();
}

class _LevelProgressHeaderWidgetState extends State<LevelProgressHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation =
        Tween<double>(
          begin: 0.0,
          end: (widget.userLevelData['levelProgress'] as num).toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getLevelColor(String level) {
    // XpCalculator-basierte Farben
    switch (level) {
      case 'Rookie':
        return const Color(0xFFCD7F32); // Bronze
      case 'Rider':
        return const Color(0xFF2196F3); // Blau
      case 'Cruiser':
        return const Color(0xFF4CAF50); // Grün
      case 'Veteran':
        return const Color(0xFFC0C0C0); // Silber
      case 'Roadmaster':
        return const Color(0xFFFFD700); // Gold
      case 'Legende':
        return const Color(0xFFFF6B35); // Orange
      default:
        return const Color(0xFFC0C0C0);
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Rookie':
        return Icons.star_border;
      case 'Rider':
        return Icons.star_half;
      case 'Cruiser':
        return Icons.two_wheeler_rounded;
      case 'Veteran':
        return Icons.star;
      case 'Roadmaster':
        return Icons.military_tech;
      case 'Legende':
        return Icons.emoji_events_rounded;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLevel = widget.userLevelData['currentLevel'] as String;
    final currentXP = widget.userLevelData['currentXP'] as int;
    final nextLevelXP = widget.userLevelData['nextLevelXP'] as int;
    final nextLevel = widget.userLevelData['nextLevel'] as String;
    final levelColor = _getLevelColor(currentLevel);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withValues(alpha: 0.2),
            levelColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Badge and Title
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: levelColor, width: 2),
                ),
                child: Icon(
                  _getLevelIcon(currentLevel),
                  color: levelColor,
                  size: 32,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktuelles Level',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      currentLevel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: levelColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: 'stars',
                      color: theme.colorScheme.secondary,
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      '$currentXP XP',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fortschritt zu $nextLevel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${currentXP} / ${nextLevelXP} XP',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return BikergramProgressBar(
                    progress: _progressAnimation.value,
                    height: 18,
                  );
                },
              ),
              SizedBox(height: 1.h),
              Text(
                'Noch ${nextLevelXP - currentXP} XP bis zum nächsten Level',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
