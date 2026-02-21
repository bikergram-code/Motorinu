import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'reward_icons.dart';
import 'reward_badge_icon.dart';

enum RewardToastPosition { bottom, top }

class RewardToast {
  static OverlayEntry? _entry;
  static double defaultReservedBottomPx = 120;

  static void showSeal(
    BuildContext context, {
    required String title,
    required String sealLabel,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 1600),
    double reservedBottomPx = 0,
    RewardToastPosition position = RewardToastPosition.top,
    IconData? icon,
  }) {
    _entry?.remove();

    final resolvedIcon = icon ?? RewardIcons.forAgeSeal(sealLabel);

    _entry = OverlayEntry(
      builder: (_) => _RewardToastWidget(
        title: title,
        label: sealLabel,
        subtitle: subtitle,
        icon: resolvedIcon,
        reservedBottomPx: reservedBottomPx,
        position: position,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);

    Future.delayed(duration, () {
      _entry?.remove();
      _entry = null;
    });
  }

  // Backwards compatible API used by the wizard.
  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
    IconData icon = Icons.verified,
    Duration duration = const Duration(seconds: 2),
    double reservedBottomPx = 0,
    RewardToastPosition position = RewardToastPosition.bottom,
  }) {
    final autoIcon = (icon == Icons.verified) ? RewardIcons.forAgeSeal(subtitle) : icon;

    showSeal(
      context,
      title: title,
      sealLabel: subtitle,
      subtitle: null,
      duration: duration,
      reservedBottomPx: reservedBottomPx,
      position: position,
      icon: autoIcon,
    );
  }
}

class _RewardToastWidget extends StatelessWidget {
  final String title;
  final String label;
  final String? subtitle;
  final IconData icon;
  final double reservedBottomPx;
  final RewardToastPosition position;

  const _RewardToastWidget({
    required this.title,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.reservedBottomPx,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final toast = IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 3.6.w, vertical: 1.25.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.22),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.black.withOpacity(0.85), width: 2),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                  color: Colors.black.withOpacity(0.35),
                ),
              ],
            ),
            child: Row(
              children: [
                RewardBadgeIcon(icon: icon, tierLabel: label, size: 56),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle ?? label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (position == RewardToastPosition.top) {
      return Positioned(left: 4.w, right: 4.w, top: 2.2.h, child: toast);
    }

    final safeBottom = MediaQuery.of(context).padding.bottom;
    final reserved = reservedBottomPx > 0 ? reservedBottomPx : RewardToast.defaultReservedBottomPx;
    final bottom = 2.2.h + safeBottom + reserved;

    return Positioned(left: 4.w, right: 4.w, bottom: bottom, child: toast);
  }
}
