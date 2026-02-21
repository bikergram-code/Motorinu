import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);

  // Only relax TLS checks when connecting to an IP over HTTPS.
  if (uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      InternetAddress.tryParse(uri.host) != null) {
    final hc = HttpClient();
    hc.badCertificateCallback = (cert, host, port) => true;
    return IOClient(hc);
  }

  return http.Client();
}
