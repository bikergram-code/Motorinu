import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'animated_biker_character.dart';

class AchievementModal {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeName,
    String characterAsset = 'assets/images/11bikerin_picture.png',
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AchievementDialog(
        title: title,
        subtitle: subtitle,
        badgeName: badgeName,
        characterAsset: characterAsset,
      ),
    );
  }
}

class _AchievementDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeName;
  final String characterAsset;

  const _AchievementDialog({
    required this.title,
    required this.subtitle,
    required this.badgeName,
    required this.characterAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 6.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.18),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.black.withOpacity(0.9), width: 2.4),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                  color: Colors.black.withOpacity(0.45),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🏆 ACHIEVEMENT UNLOCKED!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1.2.h),

                AnimatedBikerCharacter(
                  assetPath: characterAsset,
                  height: 18.h,
                ),

                SizedBox(height: 1.2.h),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 0.8.h),

                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.88),
                  ),
                ),

                SizedBox(height: 1.6.h),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.85), width: 2),
                  ),
                  child: Text(
                    badgeName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 2.0.h),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.black.withOpacity(0.85), width: 2),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.4.h),
                  ),
                  child: const Text('Weiter!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
