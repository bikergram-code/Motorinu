import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nav_engine.dart';

// ─── Helper: maneuver → icon ────────────────────────────────────────────────
IconData maneuverIconData(String maneuver) => switch (maneuver) {
  String m when m.contains('uturn') => Icons.u_turn_left_rounded,
  String m when m.contains('roundabout') || m.contains('rotary') => Icons.roundabout_left_rounded,
  String m when m.contains('fork-left') => Icons.fork_left_rounded,
  String m when m.contains('fork-right') => Icons.fork_right_rounded,
  String m when m.contains('ferry') => Icons.directions_boat_rounded,
  String m when m.contains('ramp') => Icons.ramp_right_rounded,
  String m when m.contains('merge') => Icons.merge_rounded,
  String m when m.contains('left') => Icons.turn_left_rounded,
  String m when m.contains('right') => Icons.turn_right_rounded,
  'arrive' => Icons.flag_rounded,
  'depart' => Icons.navigation_rounded,
  _ => Icons.straight_rounded,
};

// ─── Helper: Road badge detection ────────────────────────────────────────────
final _highwayPattern = RegExp(r'\b([AaBbEeMm]\s?\d{1,4})\b');

String? extractHighwayNumber(String? roadName) {
  if (roadName == null) return null;
  final match = _highwayPattern.firstMatch(roadName);
  return match?.group(1)?.replaceAll(' ', '');
}

({Color bg, Color text}) roadBadgeStyle(String badge) {
  final c = badge.toUpperCase();
  if (c.startsWith('A')) return (bg: const Color(0xFF1565C0), text: Colors.white);
  if (c.startsWith('B')) return (bg: const Color(0xFFF9A825), text: Colors.black);
  if (c.startsWith('E')) return (bg: const Color(0xFF2E7D32), text: Colors.white);
  return (bg: Colors.blue.shade700, text: Colors.white);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NAV TURN BANNER — Top overlay during navigation
// ═══════════════════════════════════════════════════════════════════════════════

class NavTurnBanner extends StatelessWidget {
  final NavState navState;
  final Color accentColor;
  final Brightness brightness;

  const NavTurnBanner({
    super.key,
    required this.navState,
    required this.accentColor,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final step = navState.nextTurn;
    if (step == null) return const SizedBox.shrink();

    final distText = navState.nextTurnDistText;
    final afterStep = navState.afterNextTurn;

    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 16,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Current step ──
            Row(
              children: [
                // Maneuver icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      maneuverIconData(step.maneuver),
                      color: accentColor,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Instruction + distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Instruction text
                      Text(
                        step.instruction,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Distance + optional road badge
                      Row(
                        children: [
                          Text(
                            'in $distText',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: accentColor,
                            ),
                          ),
                          // Highway badge if applicable
                          if (extractHighwayNumber(step.roadName) != null) ...[
                            const SizedBox(width: 8),
                            _buildRoadBadge(extractHighwayNumber(step.roadName)!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── "Danach:" next step preview ──
            if (afterStep != null && afterStep.maneuver != 'arrive') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      maneuverIconData(afterStep.maneuver),
                      color: accentColor.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Danach: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        afterStep.instruction,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoadBadge(String badge) {
    final style = roadBadgeStyle(badge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: style.text,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NAV BOTTOM BAR — Speed, distance, time, ETA
// ═══════════════════════════════════════════════════════════════════════════════

class NavBottomBar extends StatelessWidget {
  final NavState navState;
  final Color accentColor;
  final Brightness brightness;
  final VoidCallback onStop;

  const NavBottomBar({
    super.key,
    required this.navState,
    required this.accentColor,
    required this.brightness,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final mutedColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF6C757D);

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Speed
            _stat(Icons.speed_rounded, '${navState.displaySpeed.round()}',
                'km/h', textColor, mutedColor),
            // Remaining distance
            _stat(Icons.straighten_rounded, navState.remainingDistText,
                '', textColor, mutedColor),
            // Remaining time
            _stat(Icons.schedule_rounded, navState.remainingTimeText,
                '', textColor, mutedColor),
            // ETA
            _stat(Icons.flag_rounded, navState.etaText,
                'Ank.', textColor, mutedColor),
            // Stop button
            GestureDetector(
              onTap: onStop,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color textColor, Color mutedColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: mutedColor),
          ),
      ],
    );
  }
}
