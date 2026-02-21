import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom sheet showing attachment options like WhatsApp.
class AttachmentPicker extends StatelessWidget {
  const AttachmentPicker({
    super.key,
    required this.accentColor,
    required this.onGallery,
    required this.onCamera,
    required this.onLocation,
  });

  final Color accentColor;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onLocation;

  static void show(
    BuildContext context, {
    required Color accentColor,
    required VoidCallback onGallery,
    required VoidCallback onCamera,
    required VoidCallback onLocation,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentPicker(
        accentColor: accentColor,
        onGallery: () {
          Navigator.pop(context);
          onGallery();
        },
        onCamera: () {
          Navigator.pop(context);
          onCamera();
        },
        onLocation: () {
          Navigator.pop(context);
          onLocation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(
                    icon: Icons.photo_rounded,
                    label: 'Galerie',
                    color: Colors.purple,
                    onTap: onGallery,
                  ),
                  _AttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: Colors.red,
                    onTap: onCamera,
                  ),
                  _AttachmentOption(
                    icon: Icons.location_on_rounded,
                    label: 'Standort',
                    color: Colors.green,
                    onTap: onLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
