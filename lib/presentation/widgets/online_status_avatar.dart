import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../providers/core/online_status_cache.dart';

/// Avatar widget with a green (online) or red (offline) status ring.
///
/// Fetches online status from [OnlineStatusCache] and wraps the avatar image
/// with a colored border. Use across all screens for consistent look.
class OnlineStatusAvatar extends StatefulWidget {
  const OnlineStatusAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    required this.size,
    this.fallbackIcon,
    this.borderWidth = 2.5,
    this.showStatusRing = true,
    this.backgroundColor,
  });

  /// Supabase user ID — used to look up online status.
  final String userId;

  /// URL of the user's avatar image.
  final String? avatarUrl;

  /// Outer diameter of the entire widget (including ring).
  final double size;

  /// Fallback widget when avatar URL is null/empty.
  final Widget? fallbackIcon;

  /// Width of the status ring.
  final double borderWidth;

  /// Set to false to disable the ring (e.g. for group chats).
  final bool showStatusRing;

  /// Background color behind avatar (matches dark/light theme).
  final Color? backgroundColor;

  @override
  State<OnlineStatusAvatar> createState() => _OnlineStatusAvatarState();
}

class _OnlineStatusAvatarState extends State<OnlineStatusAvatar> {
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    if (widget.showStatusRing) _fetchStatus();
  }

  @override
  void didUpdateWidget(OnlineStatusAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final online = await OnlineStatusCache.instance.isUserOnline(widget.userId);
    if (mounted && _isOnline != online) setState(() => _isOnline = online);
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = !widget.showStatusRing || _isOnline == null
        ? Colors.grey.shade600
        : _isOnline!
            ? const Color(0xFF4CAF50) // green
            : const Color(0xFFEF5350); // red

    final innerSize = widget.size - (widget.borderWidth * 2) - 3;
    final bg = widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showStatusRing
            ? Border.all(color: ringColor, width: widget.borderWidth)
            : null,
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        padding: const EdgeInsets.all(1),
        child: ClipOval(
          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.avatarUrl!,
                  width: innerSize,
                  height: innerSize,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _fallback(innerSize),
                )
              : _fallback(innerSize),
        ),
      ),
    );
  }

  Widget _fallback(double size) {
    return widget.fallbackIcon ??
        Container(
          width: size,
          height: size,
          color: Colors.grey.shade800,
          child: Icon(Icons.person, color: Colors.grey.shade500, size: size * 0.6),
        );
  }
}
