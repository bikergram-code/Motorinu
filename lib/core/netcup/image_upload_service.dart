import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_config.dart';

class ImageUploadService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  static bool get _baseHasApi {
    try {
      final u = Uri.parse(baseUrl);
      final segs = u.pathSegments.where((s) => s.trim().isNotEmpty).toList();
      return segs.isNotEmpty && segs.last.toLowerCase() == 'api';
    } catch (_) {
      return false;
    }
  }

  static Uri _resolve(String path) {
    final b = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final p = path.startsWith('/') ? path.substring(1) : path;
    return b.resolve(p);
  }

  /// Erwartet Backend:
  /// POST /upload/profile-image (multipart form field: "file")
  /// Antwort: { "url": "https://www.bikergram.de/uploads/....jpg" }
  static Future<String> uploadProfileImage({
    required Uint8List bytes,
    required String filename,
    Future<String?> Function()? sessionTokenProvider,
  }) async {
    final candidates = <String>[
      'upload/profile-image',
      if (!_baseHasApi) 'api/upload/profile-image',
    ];

    http.Response? lastRes;
    for (final p in candidates) {
      final uri = _resolve(p);

      final req = http.MultipartRequest('POST', uri);
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final token = await sessionTokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      lastRes = res;

      // Retry on typical "wrong path" statuses.
      if (res.statusCode == 404 || res.statusCode == 405) {
        continue;
      }
      if (res.statusCode != 200) {
        throw Exception('Upload failed (${res.statusCode})');
      }

      final decodedBody = utf8.decode(res.bodyBytes, allowMalformed: true);
      final data = jsonDecode(decodedBody) as Map<String, dynamic>;
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) throw Exception('Upload response missing url');
      return url;
    }

    throw Exception('Upload failed (${lastRes?.statusCode ?? 'no_response'})');
  }
}
