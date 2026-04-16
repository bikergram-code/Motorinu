import 'dart:html' as html;

/// Redirect the browser to the given URL (web only).
/// Uses a programmatic <a> click which bypasses any Flutter-level
/// navigation interception that might block window.location.href.
void webRedirect(String url) {
  final anchor = html.AnchorElement(href: url)
    ..target = '_self'
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
