import 'package:flutter/material.dart';

/// Floating action buttons for the feed:
/// - Camera (kept as-is)
/// - Plus (new) right next to it, same style
///
/// Compatibility:
/// Existing code passes only `onPressed`. We keep that and wire both buttons to it by default.
/// You can optionally provide dedicated callbacks later.
class CreatePostFabWidget extends StatelessWidget {
  final VoidCallback onPressed;

  /// Optional: dedicated action for the camera button.
  final VoidCallback? onCameraPressed;

  /// Optional: dedicated action for the plus button.
  final VoidCallback? onPlusPressed;

  const CreatePostFabWidget({
    super.key,
    required this.onPressed,
    this.onCameraPressed,
    this.onPlusPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Match the existing dark UI: light-ish FAB on dark background.
    final bg = theme.colorScheme.surface;
    final fg = theme.colorScheme.onSurface;

    Widget buildFab({
      required String heroTag,
      required VoidCallback onTap,
      required IconData icon,
      String? tooltip,
    }) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onTap,
        tooltip: tooltip,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildFab(
          heroTag: 'bg_fab_camera',
          onTap: onCameraPressed ?? onPressed,
          icon: Icons.camera_alt_outlined,
          tooltip: 'Bild hinzufügen',
        ),
        const SizedBox(width: 12),
        buildFab(
          heroTag: 'bg_fab_plus',
          onTap: onPlusPressed ?? onPressed,
          icon: Icons.add,
          tooltip: 'Neuer Post',
        ),
      ],
    );
  }
}
