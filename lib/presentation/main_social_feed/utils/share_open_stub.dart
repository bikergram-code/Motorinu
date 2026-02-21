import 'package:url_launcher/url_launcher.dart';

/// Cross-platform safe opener (Non-Web).
/// Opens external URLs in the default browser/app.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (_) {
    // ignore (still copied link in UI)
  }
}
