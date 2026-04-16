import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api_config.dart';

/// Native TUS upload from file path.
Future<void> tusUploadFile({
  required String bucketName,
  required String objectPath,
  required String filePath,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  final file = File(filePath);
  await _tusUpload(
    bucketName: bucketName,
    objectPath: objectPath,
    file: file,
    contentType: contentType,
    onProgress: onProgress,
  );
}

/// Native: write bytes to temp file, then TUS upload.
Future<void> tusUploadBytes({
  required String bucketName,
  required String objectPath,
  required Uint8List bytes,
  required String ext,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  final tempDir = Directory.systemTemp;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final tempFile = File('${tempDir.path}/upload_${timestamp}_vid.$ext');
  await tempFile.writeAsBytes(bytes);
  try {
    await _tusUpload(
      bucketName: bucketName,
      objectPath: objectPath,
      file: tempFile,
      contentType: contentType,
      onProgress: onProgress,
    );
  } finally {
    await tempFile.delete().catchError((_) {});
  }
}

Future<void> _tusUpload({
  required String bucketName,
  required String objectPath,
  required File file,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  final supabase = Supabase.instance.client;
  final accessToken = supabase.auth.currentSession?.accessToken;
  if (accessToken == null) throw Exception('Nicht eingeloggt');

  final baseUrl = ApiConfig.supabaseUrl;
  final fileSize = await file.length();

  // Step 1: Create the resumable upload
  final createUri = Uri.parse('$baseUrl/storage/v1/upload/resumable');
  final metaBucket = base64.encode(utf8.encode(bucketName));
  final metaObject = base64.encode(utf8.encode(objectPath));
  final metaType = base64.encode(utf8.encode(contentType));
  final metaCache = base64.encode(utf8.encode('3600'));

  final metadata =
      'bucketName $metaBucket,objectName $metaObject,contentType $metaType,cacheControl $metaCache';

  final createRes = await http.post(
    createUri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'x-upsert': 'false',
      'Upload-Length': '$fileSize',
      'Upload-Metadata': metadata,
      'Tus-Resumable': '1.0.0',
    },
  );

  if (createRes.statusCode != 201) {
    throw Exception(
        'Upload-Erstellung fehlgeschlagen (${createRes.statusCode}): ${createRes.body}');
  }

  final uploadUrl = createRes.headers['location'];
  if (uploadUrl == null) {
    throw Exception('Kein Upload-URL vom Server erhalten');
  }

  // Step 2: Upload in 6MB chunks
  const chunkSize = 6 * 1024 * 1024;
  int offset = 0;
  final raf = file.openSync(mode: FileMode.read);

  try {
    while (offset < fileSize) {
      final remaining = fileSize - offset;
      final currentSize = remaining < chunkSize ? remaining : chunkSize;

      raf.setPositionSync(offset);
      final chunk = raf.readSync(currentSize);

      final patchRes = await http.patch(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Upload-Offset': '$offset',
          'Content-Type': 'application/offset+octet-stream',
          'Tus-Resumable': '1.0.0',
        },
        body: chunk,
      );

      if (patchRes.statusCode != 204) {
        throw Exception(
            'Chunk-Upload fehlgeschlagen bei ${(offset / 1024 / 1024).toStringAsFixed(1)}MB '
            '(${patchRes.statusCode}): ${patchRes.body}');
      }

      offset += currentSize;
      onProgress?.call(offset / fileSize);
    }
  } finally {
    raf.closeSync();
  }
}
