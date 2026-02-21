import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Profile header widget displaying cover photo, profile image, and basic stats
class ProfileHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isOwnProfile;
  final VoidCallback onEditProfile;
  final VoidCallback? onFollowToggle;

  const ProfileHeaderWidget({
    super.key,
    required this.userData,
    required this.isOwnProfile,
    required this.onEditProfile,
    this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover photo
        CustomImageWidget(
          imageUrl: userData["coverPhoto"] as String,
          width: 100.w,
          height: 25.h,
          fit: BoxFit.cover,
          semanticLabel: userData["coverPhotoSemanticLabel"] as String,
        ),

        // Gradient overlay for better text visibility
        Container(
          width: 100.w,
          height: 25.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
            ),
          ),
        ),

        // Profile content
        Positioned(
          top: 18.h,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Profile image with level border
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getLevelColor(
                      userData["level"] as String,
                      colorScheme,
                    ),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 4),
                  ),
                  child: ClipOval(
                    child: CustomImageWidget(
                      imageUrl: userData["profileImage"] as String,
                      width: 25.w,
                      height: 25.w,
                      fit: BoxFit.cover,
                      semanticLabel:
                          userData["profileImageSemanticLabel"] as String,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 2.h),

              // User name and level badge
              Text(
                userData["name"] as String,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 1.h),

              // Level badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: _getLevelColor(
                    userData["level"] as String,
                    colorScheme,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getLevelColor(
                      userData["level"] as String,
                      colorScheme,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: _getLevelIcon(userData["level"] as String),
                      color: _getLevelColor(
                        userData["level"] as String,
                        colorScheme,
                      ),
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      userData["level"] as String,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _getLevelColor(
                          userData["level"] as String,
                          colorScheme,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),

              // Action buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isOwnProfile)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onEditProfile,
                          icon: CustomIconWidget(
                            iconName: 'edit',
                            color: colorScheme.onSecondary,
                            size: 18,
                          ),
                          label: Text('Profil bearbeiten'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onFollowToggle,
                          icon: CustomIconWidget(
                            iconName: (userData["isFollowing"] as bool)
                                ? 'person_remove'
                                : 'person_add',
                            color: colorScheme.onSecondary,
                            size: 18,
                          ),
                          label: Text(
                            (userData["isFollowing"] as bool)
                                ? 'Entfolgen'
                                : 'Folgen',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to messages
                        },
                        icon: CustomIconWidget(
                          iconName: 'message',
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        label: Text('Nachricht'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.5.h,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Edit button (top-right)
        if (isOwnProfile)
          Positioned(
            top: 2.h,
            right: 4.w,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onEditProfile,
                icon: CustomIconWidget(
                  iconName: 'settings',
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'Einstellungen',
              ),
            ),
          ),
      ],
    );
  }

  Color _getLevelColor(String level, ColorScheme colorScheme) {
    switch (level) {
      case 'Rookie':
        return const Color(0xFFCD7F32); // Bronze
      case 'Rider':
        return const Color(0xFFC0C0C0); // Silver
      case 'Veteran':
        return const Color(0xFFFFD700); // Gold
      case 'Legend':
        return const Color(0xFFE5E4E2); // Platinum
      default:
        return colorScheme.primary;
    }
  }

  String _getLevelIcon(String level) {
    switch (level) {
      case 'Rookie':
        return 'star_border';
      case 'Rider':
        return 'star_half';
      case 'Veteran':
        return 'star';
      case 'Legend':
        return 'military_tech';
      default:
        return 'star';
    }
  }
}
