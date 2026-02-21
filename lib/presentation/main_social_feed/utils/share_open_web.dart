import 'dart:html' as html;

/// Web opener using window.open.
Future<void> openExternalUrl(String url) async {
  html.window.open(url, '_blank');
}
