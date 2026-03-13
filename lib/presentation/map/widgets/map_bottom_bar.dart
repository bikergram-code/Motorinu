import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom-Bar für die Community-Karte.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │  [🟢 5 Online]  [👥 Gruppen]  [📍 POIs]  [⚠️ Melden]  │
/// └──────────────────────────────────────┘
/// ```
class MapBottomBar extends StatelessWidget {
  final int onlineCount;
  final bool isLive;
  final Color accentColor;
  final VoidCallback onOnlineTap;
  final VoidCallback onGroupsTap;
  final VoidCallback onPoiTap;
  final VoidCallback onReportTap;
  final bool mapInteracting;

  const MapBottomBar({
    super.key,
    required this.onlineCount,
    required this.isLive,
    required this.accentColor,
    required this.onOnlineTap,
    required this.onGroupsTap,
    required this.onPoiTap,
    required this.onReportTap,
    this.mapInteracting = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 8 + bottomPadding,
      child: AnimatedOpacity(
        opacity: mapInteracting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: mapInteracting,
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // 🟢 Online
            _BarButton(
              icon: Icons.circle,
              iconSize: 10,
              label: '$onlineCount Online',
              iconColor: isLive ? Colors.green : Colors.grey,
              isHighlighted: isLive,
              highlightColor: Colors.green,
              onTap: onOnlineTap,
            ),
            // 👥 Gruppen
            _BarButton(
              icon: Icons.groups_rounded,
              iconSize: 18,
              label: 'Gruppen',
              iconColor: isDark ? Colors.white70 : Colors.black54,
              onTap: onGroupsTap,
            ),
            // 📍 POIs
            _BarButton(
              icon: Icons.place_rounded,
              iconSize: 18,
              label: 'POIs',
              iconColor: isDark ? Colors.white70 : Colors.black54,
              onTap: onPoiTap,
            ),
            // ⚠️ Melden
            _BarButton(
              icon: Icons.warning_amber_rounded,
              iconSize: 18,
              label: 'Melden',
              iconColor: Colors.amber.shade600,
              onTap: onReportTap,
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color iconColor;
  final bool isHighlighted;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.iconColor,
    this.isHighlighted = false,
    this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isHighlighted
        ? (highlightColor ?? iconColor)
        : (isDark ? Colors.white60 : Colors.black54);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: isHighlighted
                ? BoxDecoration(
                    color: (highlightColor ?? iconColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: iconColor),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
