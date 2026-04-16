import 'dart:typed_data';

/// Web stub — TUS video upload is not available on web.
Future<void> tusUploadFile({
  required String bucketName,
  required String objectPath,
  required String filePath,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('Video upload not supported on web');
}

/// Web stub — write bytes to temp file and TUS upload.
Future<void> tusUploadBytes({
  required String bucketName,
  required String objectPath,
  required Uint8List bytes,
  required String ext,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('Video upload not supported on web');
}
