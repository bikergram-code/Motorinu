import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Web reel player — HTML5 video, fullscreen style.
class ReelVideoPlayer extends StatefulWidget {
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
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _isMuted = true;

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
      _controller!.setVolume(0); // Start muted (autoplay policy)
      _controller!.setLooping(true);
      _controller!.addListener(_onProgress);
      if (mounted) {
        setState(() => _initialized = true);
        if (widget.isActive) {
          _controller!.play();
          widget.onPlayStarted?.call();
        }
      }
    } catch (e) {
      debugPrint('[WebReel] init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onProgress() {
    if (_controller == null || !_initialized) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    if (dur.inMilliseconds > 0) {
      widget.onProgressChanged
          ?.call(pos.inMilliseconds / dur.inMilliseconds);
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer old) {
    super.didUpdateWidget(old);
    if (_controller == null || !_initialized) return;
    if (widget.isActive && !old.isActive) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
      _isPaused = false;
      widget.onPlayStarted?.call();
    } else if (!widget.isActive && old.isActive) {
      _controller!.pause();
    }
  }

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    if (_isPaused) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
    setState(() => _isPaused = !_isPaused);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _controller?.setVolume(_isMuted ? 0 : 1);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _togglePlay();
        widget.onTap?.call();
      },
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail
            if (widget.thumbnailUrl != null && (!_initialized || _isPaused))
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),

            // Video — fullscreen cover
            if (_initialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

            // Loading
            if (!_initialized && !_hasError)
              const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54),

            // Error
            if (_hasError)
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.white, size: 56),
                  SizedBox(height: 12),
                  Text('Reel — nur in der App',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ],
              ),

            // Pause icon
            if (_initialized && _isPaused)
              const Icon(Icons.play_circle_filled,
                  color: Colors.white70, size: 64),

            // Mute button
            if (_initialized)
              Positioned(
                right: 12,
                bottom: 80,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
