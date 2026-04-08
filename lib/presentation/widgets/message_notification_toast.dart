import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/messages/incoming_message_provider.dart';
import '../../providers/notifications/incoming_notification_provider.dart';

/// Manages a single global overlay entry for in-app toast notifications.
class InAppToast {
  static OverlayEntry? _entry;

  static void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  /// Show a new-message toast.
  static void showMessage(
    BuildContext context, {
    required IncomingMessage message,
    required Color accentColor,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dismiss();

    _entry = OverlayEntry(
      builder: (_) => _ToastWrapper(
        onTap: () {
          _dismiss();
          onTap?.call();
        },
        onDismiss: _dismiss,
        child: _MessageToastContent(
          message: message,
          accentColor: accentColor,
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    Future.delayed(duration, _dismiss);
  }

  /// Show a notification toast (like, comment, follow, etc.).
  static void showNotification(
    BuildContext context, {
    required IncomingNotification notification,
    required Color accentColor,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dismiss();

    _entry = OverlayEntry(
      builder: (_) => _ToastWrapper(
        onTap: () {
          _dismiss();
          onTap?.call();
        },
        onDismiss: _dismiss,
        child: _NotificationToastContent(
          notification: notification,
          accentColor: accentColor,
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    Future.delayed(duration, _dismiss);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toast wrapper with slide-in animation + swipe-to-dismiss
// ─────────────────────────────────────────────────────────────────────────────

class _ToastWrapper extends StatefulWidget {
  const _ToastWrapper({
    required this.child,
    this.onTap,
    this.onDismiss,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  State<_ToastWrapper> createState() => _ToastWrapperState();
}

class _ToastWrapperState extends State<_ToastWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Positioned(
      left: 12,
      right: 12,
      top: safeTop + 90,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: widget.onTap,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -5) {
                widget.onDismiss?.call();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: widget.child,
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message toast content
// ─────────────────────────────────────────────────────────────────────────────

class _MessageToastContent extends StatelessWidget {
  const _MessageToastContent({
    required this.message,
    required this.accentColor,
  });

  final IncomingMessage message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1A1A1A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF6C757D);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? accentColor.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_rounded,
                        size: 12, color: accentColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Jetzt',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subtextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = message.senderAvatarUrl;
    final name = message.senderName;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.15),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitial(name),
              )
            : _buildInitial(name),
      ),
    );
  }

  Widget _buildInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification toast content (likes, comments, follows, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationToastContent extends StatelessWidget {
  const _NotificationToastContent({
    required this.notification,
    required this.accentColor,
  });

  final IncomingNotification notification;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1A1A1A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF6C757D);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? accentColor.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                notification.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_rounded,
                        size: 12, color: accentColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Jetzt',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
                if (notification.body != null &&
                    notification.body!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification.body!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: subtextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
