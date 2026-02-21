import 'dart:io';

void installDevHttpOverrides() {
  HttpOverrides.global = _DevHttpOverrides();
}

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // DEV only: allow self-signed / mismatched certs while bootstrapping HTTPS.
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return client;
  }
}
