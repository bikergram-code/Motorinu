import 'package:flutter/material.dart';

/// Web stub — video trimming is not available on web.
class VideoTrimScreen extends StatelessWidget {
  const VideoTrimScreen({
    super.key,
    required this.videoFile,
    required this.accentColor,
  });

  final dynamic videoFile;
  final Color accentColor;

  /// Web: always returns null (trimming not supported).
  static Future<dynamic> show(
    BuildContext context, {
    required dynamic videoFile,
    required Color accentColor,
  }) async {
    return null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
