import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom bottom navigation bar for BikerGram
/// Implements thumb-optimized bottom placement with context-aware navigation
/// Supports five primary screens: Feed, Garage, Tracker, Marketplace, Profile
class CustomBottomBar extends StatefulWidget {
  /// Current selected index
  final int currentIndex;

  /// Callback when navigation item is tapped
  final ValueChanged<int> onTap;

  /// Whether to show notification badges
  final bool showBadges;

  /// Badge counts for each navigation item (optional)
  final List<int>? badgeCounts;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showBadges = false,
    this.badgeCounts,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _lastTappedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;

    setState(() {
      _lastTappedIndex = index;
    });

    // Haptic feedback for tactile confirmation
    HapticFeedback.lightImpact();

    // Micro-feedback animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Feed',
              ),
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.garage_outlined,
                activeIcon: Icons.garage,
                label: 'Garage',
              ),
              _buildNavItem(
                context: context,
                index: 2,
                icon: Icons.navigation_outlined,
                activeIcon: Icons.navigation,
                label: 'Tracker',
              ),
              _buildNavItem(
                context: context,
                index: 3,
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Market',
              ),
              _buildNavItem(
                context: context,
                index: 4,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.currentIndex == index;
    final isAnimating = _lastTappedIndex == index;

    final itemColor = isSelected
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;

    final hasBadge =
        widget.showBadges &&
        widget.badgeCounts != null &&
        index < widget.badgeCounts!.length &&
        widget.badgeCounts![index] > 0;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(index),
          splashColor: colorScheme.secondary.withValues(alpha: 0.1),
          highlightColor: colorScheme.secondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isAnimating ? _scaleAnimation.value : 1.0,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? activeIcon : icon,
                        size: 24,
                        color: itemColor,
                      ),
                      if (hasBadge)
                        Positioned(
                          right: -8,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              widget.badgeCounts![index] > 99
                                  ? '99+'
                                  : widget.badgeCounts![index].toString(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onError,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: itemColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation helper class to manage bottom bar navigation
class BottomBarNavigation {
  /// Navigate to the appropriate screen based on index
  static void navigateToIndex(BuildContext context, int index) {
    final routes = [
      '/main-social-feed', // 0: Feed
      '/digital-garage', // 1: Garage
      '/gps-ride-tracker', // 2: Tracker
      '/marketplace-browse', // 3: Marketplace
      '/user-profile', // 4: Profile
    ];

    if (index >= 0 && index < routes.length) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  /// Get current index from route name
  static int getIndexFromRoute(String routeName) {
    switch (routeName) {
      case '/main-social-feed':
        return 0;
      case '/digital-garage':
        return 1;
      case '/gps-ride-tracker':
        return 2;
      case '/marketplace-browse':
        return 3;
      case '/user-profile':
        return 4;
      default:
        return 0;
    }
  }
}
