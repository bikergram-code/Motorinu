import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Global mute state — web version.
final globalMuteNotifier = ValueNotifier<bool>(true);

/// Web video player — HTML5 video via video_player, max 400px height.
class PostVideoPlayer extends StatefulWidget {
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
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller!.initialize();
      // Start muted (browser autoplay policy)
      _controller!.setVolume(0);
      _controller!.setLooping(true);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('[WebVideo] init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
      widget.onPlayStarted?.call();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _toggleMute() {
    if (_controller == null) return;
    final muted = globalMuteNotifier.value;
    globalMuteNotifier.value = !muted;
    _controller!.setVolume(!muted ? 0 : 1);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: _togglePlay,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: AspectRatio(
          aspectRatio: _initialized
              ? _controller!.value.aspectRatio.clamp(0.56, 2.0)
              : 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail
                if (widget.thumbnailUrl != null && !_isPlaying)
                  CachedNetworkImage(
                    imageUrl: widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),

                // Video
                if (_initialized)
                  VideoPlayer(_controller!),

                // Loading
                if (!_initialized && !_hasError)
                  const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54,
                  ),

                // Error fallback
                if (_hasError)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_filled,
                            color: Colors.white, size: 32),
                        SizedBox(width: 8),
                        Text('Video — nur in der App',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                // Play/pause overlay
                if (_initialized && !_isPlaying)
                  const Icon(Icons.play_circle_filled,
                      color: Colors.white70, size: 52),

                // Mute button
                if (_initialized && _isPlaying)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: globalMuteNotifier,
                        builder: (_, muted, __) => Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
