import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/share_open.dart';

class ShareSheetWidget extends StatelessWidget {
  final String shareText;
  final String shareLink;
  final String fullText;

  const ShareSheetWidget({
    super.key,
    required this.shareText,
    required this.shareLink,
    required this.fullText,
  });

  String _enc(String v) => Uri.encodeComponent(v);

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: fullText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link kopiert ✅')),
    );
  }

  Future<void> _open(BuildContext context, String url, {bool copyFirst = true}) async {
    if (copyFirst) {
      await _copy(context);
    }
    await openExternalUrl(url);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Share URLs (work well on web; on mobile the buttons still copy the link).
    final waUrl = 'https://wa.me/?text=${_enc(fullText)}';
    final fbUrl = 'https://www.facebook.com/sharer/sharer.php?u=${_enc(shareLink)}&quote=${_enc(shareText)}';

    // These platforms don't provide a reliable direct "share URL" for our use case.
    // We still provide buttons that copy the link and open the platform website.
    final igUrl = 'https://www.instagram.com/';
    final ttUrl = 'https://www.tiktok.com/';
    final ytUrl = 'https://www.youtube.com/';

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        onTap: onTap,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Teilen',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),

            tile(
              icon: Icons.link,
              title: 'Link kopieren',
              subtitle: 'Kopiert Text + Link in die Zwischenablage',
              onTap: () async {
                await _copy(context);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
            tile(
              icon: Icons.chat_bubble_outline,
              title: 'WhatsApp',
              subtitle: 'Link kopieren & WhatsApp öffnen',
              onTap: () => _open(context, waUrl),
            ),
            tile(
              icon: Icons.public,
              title: 'Facebook',
              subtitle: 'Link kopieren & Facebook Share öffnen',
              onTap: () => _open(context, fbUrl),
            ),
            tile(
              icon: Icons.camera_alt_outlined,
              title: 'Instagram',
              subtitle: 'Link kopieren – dann in Instagram einfügen',
              onTap: () => _open(context, igUrl),
            ),
            tile(
              icon: Icons.music_video_outlined,
              title: 'TikTok',
              subtitle: 'Link kopieren – dann in TikTok einfügen',
              onTap: () => _open(context, ttUrl),
            ),
            tile(
              icon: Icons.ondemand_video_outlined,
              title: 'YouTube',
              subtitle: 'Link kopieren – dann in YouTube einfügen',
              onTap: () => _open(context, ytUrl),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
