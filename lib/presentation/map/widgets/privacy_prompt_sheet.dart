import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

/// DSGVO-konformer "Online gehen?" Privacy-Prompt.
///
/// Wird beim ersten Karten-Besuch pro Session angezeigt,
/// wenn der User noch nicht live ist.
///
/// Gibt `true` zurück wenn der User "Ja" gewählt hat, sonst `false`.
class PrivacyPromptSheet extends StatelessWidget {
  final Color accentColor;

  const PrivacyPromptSheet({
    super.key,
    required this.accentColor,
  });

  /// Zeigt das BottomSheet an und gibt `true` zurück wenn User zustimmt.
  static Future<bool> show(BuildContext context, {Color? accentColor}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrivacyPromptSheet(
        accentColor: accentColor ?? AppTheme.accentDark,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white60 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ──
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // ── Icon ──
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share_location_rounded,
                  size: 32,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ──
              Text(
                'Online gehen?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              // ── Description ──
              Text(
                'Du wirst auf der Karte für andere Biker sichtbar, '
                'solange du den Schalter nicht wieder auf OFF stellst.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),

              // ── Privacy hint ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: mutedColor),
                  const SizedBox(width: 4),
                  Text(
                    'Jederzeit in den Einstellungen deaktivierbar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Buttons ──
              Row(
                children: [
                  // Nein, danke
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: mutedColor.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Nein, danke',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Ja, online gehen
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ja, online gehen',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
