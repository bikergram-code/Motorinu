import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Variant types for CustomAppBar
enum AppBarVariant {
  /// Standard app bar with title and optional actions
  standard,

  /// Search-focused app bar with search field
  search,

  /// Profile/settings app bar with avatar
  profile,

  /// Transparent app bar for overlay scenarios
  transparent,
}

/// Custom app bar for BikerGram
/// Implements authentic minimalism with purposeful visual elements
/// Supports multiple variants for different screen contexts
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// App bar variant
  final AppBarVariant variant;

  /// Title text (for standard variant)
  final String? title;

  /// Custom title widget (overrides [title])
  final Widget? titleWidget;

  /// Leading widget (back button, menu, etc.)
  final Widget? leading;

  /// Action widgets (icons, buttons)
  final List<Widget>? actions;

  /// Whether to show back button automatically
  final bool automaticallyImplyLeading;

  /// Center the title
  final bool centerTitle;

  /// Search hint text (for search variant)
  final String? searchHint;

  /// Search callback (for search variant)
  final ValueChanged<String>? onSearchChanged;

  /// Profile image URL (for profile variant)
  final String? profileImageUrl;

  /// Notification badge count
  final int? notificationCount;

  /// Custom background color
  final Color? backgroundColor;

  /// Custom elevation
  final double? elevation;

  const CustomAppBar({
    super.key,
    this.variant = AppBarVariant.standard,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.searchHint,
    this.onSearchChanged,
    this.profileImageUrl,
    this.notificationCount,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (variant) {
      case AppBarVariant.standard:
        return _buildStandardAppBar(context, theme, colorScheme);
      case AppBarVariant.search:
        return _buildSearchAppBar(context, theme, colorScheme);
      case AppBarVariant.profile:
        return _buildProfileAppBar(context, theme, colorScheme);
      case AppBarVariant.transparent:
        return _buildTransparentAppBar(context, theme, colorScheme);
    }
  }

  Widget _buildStandardAppBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: backgroundColor ?? colorScheme.surface,
      elevation: elevation ?? 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  tooltip: 'Back',
                )
              : null),
      title: titleWidget ?? (title != null
          ? Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          : null),
      centerTitle: centerTitle,
      actions: actions,
    );
  }

  Widget _buildSearchAppBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: backgroundColor ?? colorScheme.surface,
      elevation: elevation ?? 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      leading:
          leading ??
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            tooltip: 'Back',
          ),
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: TextField(
          onChanged: onSearchChanged,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: searchHint ?? 'Search BikerGram...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
        ),
      ),
      actions: actions,
    );
  }

  Widget _buildProfileAppBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: backgroundColor ?? colorScheme.surface,
      elevation: elevation ?? 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      leading: leading,
      title: Row(
        children: [
          if (profileImageUrl != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.secondary, width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (profileImageUrl != null) const SizedBox(width: 12),
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      actions: [
        if (notificationCount != null && notificationCount! > 0)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // Navigate to notifications
                },
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    notificationCount! > 99
                        ? '99+'
                        : notificationCount.toString(),
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
        if (actions != null) ...actions!,
      ],
    );
  }

  Widget _buildTransparentAppBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.canPop(context)
              ? Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    tooltip: 'Back',
                  ),
                )
              : null),
      title: title != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      centerTitle: centerTitle,
      actions: actions?.map((action) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: action,
        );
      }).toList(),
    );
  }
}
