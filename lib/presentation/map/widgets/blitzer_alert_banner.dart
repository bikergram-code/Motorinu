import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blitzer-Warnung — Banner das oben auf der Karte erscheint.
///
/// Bestimmt die Schwere automatisch aus dem Warning-Text:
/// - 🚨 = Immediate (rot)
/// - ⚠️ = Approach (amber)
/// - sonst = Early (orange)
class BlitzerAlertBanner extends StatelessWidget {
  final String warning;
  const BlitzerAlertBanner({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    final isImmediate = warning.contains('🚨');
    final isApproach = warning.contains('⚠️');
    final bgColor = isImmediate
        ? Colors.red.shade700
        : isApproach
            ? Colors.amber.shade700
            : Colors.orange.shade600;
    final glowColor = isImmediate
        ? Colors.red.withValues(alpha: 0.5)
        : isApproach
            ? Colors.amber.withValues(alpha: 0.4)
            : Colors.orange.withValues(alpha: 0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: glowColor, blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Icon(
          isImmediate ? Icons.crisis_alert_rounded : Icons.warning_amber_rounded,
          color: Colors.white, size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(
          warning,
          style: GoogleFonts.inter(
            fontSize: isImmediate ? 16 : 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        )),
      ]),
    );
  }
}
