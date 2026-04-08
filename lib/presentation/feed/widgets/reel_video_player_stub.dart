import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Web stub — shows thumbnail placeholder for reels.
class ReelVideoPlayer extends StatelessWidget {
  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isActive,
    this.postId,
    this.thumbnailUrl,
    this.onDoubleTap,
    this.onTap,
    this.onPlayStarted,
    this.onPlayCompleted,
    this.onProgressChanged,
  });

  final String videoUrl;
  final bool isActive;
  final int? postId;
  final String? thumbnailUrl;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;
  final VoidCallback? onPlayStarted;
  final VoidCallback? onPlayCompleted;
  final ValueChanged<double>? onProgressChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.white70, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Reel — nur in der App',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
