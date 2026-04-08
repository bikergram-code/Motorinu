import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Global mute state — stub version for web.
final globalMuteNotifier = ValueNotifier<bool>(true);

/// Web stub — shows thumbnail + play icon placeholder.
class PostVideoPlayer extends StatelessWidget {
  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    this.postId,
    this.thumbnailUrl,
    this.onDoubleTap,
    this.onPlayStarted,
    this.onPlayCompleted,
  });

  final String videoUrl;
  final int? postId;
  final String? thumbnailUrl;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onPlayStarted;
  final VoidCallback? onPlayCompleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                    'Video — nur in der App',
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
