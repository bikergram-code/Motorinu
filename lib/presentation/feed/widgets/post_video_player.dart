import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Global mute state shared across all video players in the feed.
/// When a user mutes one video, all auto-playing videos are muted.
final _globalMuteNotifier = ValueNotifier<bool>(true); // Start muted

/// Inline video player with viewport-triggered autoplay for feed posts.
///
/// Features:
/// - Auto-plays (muted) when ≥50% visible in viewport
/// - Auto-pauses when scrolled out of view
/// - Tap to toggle play/pause
/// - Tap mute icon to toggle mute (shared across all players)
/// - Progress bar at bottom
/// - Double-tap passthrough for like overlay
class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    this.postId,
    this.onDoubleTap,
    this.onPlayStarted,
    this.onPlayCompleted,
  });

  final String videoUrl;
  final int? postId;
  final VoidCallback? onDoubleTap;

  /// Called when video starts playing (for analytics tracking).
  final VoidCallback? onPlayStarted;

  /// Called when video plays past 75% (for analytics tracking).
  final VoidCallback? onPlayCompleted;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _isVisible = false;
  bool _userPaused = false; // User explicitly tapped to pause
  bool _hasTrackedPlay = false;
  bool _hasTrackedComplete = false;
  String? _error;

  // Progress tracking
  double _progress = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Show play/pause feedback animation
  bool _showPlayFeedback = false;
  IconData _feedbackIcon = Icons.play_arrow_rounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _globalMuteNotifier.addListener(_onGlobalMuteChanged);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    }
  }

  void _onGlobalMuteChanged() {
    if (_controller != null && _initialized) {
      _controller!.setVolume(_globalMuteNotifier.value ? 0 : 1);
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeVideo() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      if (mounted) setState(() => _error = 'Ung\u00fcltige Video-URL');
      return;
    }

    try {
      _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(_globalMuteNotifier.value ? 0 : 1);
      _controller!.addListener(_onVideoProgress);

      if (mounted) {
        setState(() {
          _initialized = true;
          _duration = _controller!.value.duration;
        });

        // If already visible when initialization completes, auto-play
        if (_isVisible && !_userPaused) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error: $e');
      if (mounted) {
        setState(() => _error = 'Video konnte nicht geladen werden');
      }
    }
  }

  void _onVideoProgress() {
    if (_controller == null || !_initialized) return;

    final value = _controller!.value;
    final newPosition = value.position;
    final totalDuration = value.duration;

    if (totalDuration.inMilliseconds > 0) {
      final newProgress =
          newPosition.inMilliseconds / totalDuration.inMilliseconds;

      // Track 75% completion for analytics
      if (!_hasTrackedComplete && newProgress >= 0.75) {
        _hasTrackedComplete = true;
        widget.onPlayCompleted?.call();
      }

      if (mounted) {
        setState(() {
          _progress = newProgress.clamp(0.0, 1.0);
          _position = newPosition;
        });
      }
    }
  }

  void _playVideo() {
    if (_controller == null || !_initialized) return;
    _controller!.play();
    if (mounted) setState(() => _isPlaying = true);

    // Track first play
    if (!_hasTrackedPlay) {
      _hasTrackedPlay = true;
      widget.onPlayStarted?.call();
    }
  }

  void _pauseVideo() {
    if (_controller == null || !_initialized) return;
    _controller!.pause();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _togglePlayPause() {
    if (_controller == null || !_initialized) return;

    if (_isPlaying) {
      _pauseVideo();
      _userPaused = true;
      _showFeedback(Icons.pause_rounded);
    } else {
      _playVideo();
      _userPaused = false;
      _showFeedback(Icons.play_arrow_rounded);
    }
  }

  void _showFeedback(IconData icon) {
    setState(() {
      _feedbackIcon = icon;
      _showPlayFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPlayFeedback = false);
    });
  }

  void _toggleMute() {
    _globalMuteNotifier.value = !_globalMuteNotifier.value;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;

    if (visible != _isVisible) {
      _isVisible = visible;

      if (_initialized && _controller != null) {
        if (visible && !_userPaused) {
          _playVideo();
        } else if (!visible) {
          _pauseVideo();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalMuteNotifier.removeListener(_onGlobalMuteChanged);
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibilityKey = Key('video_${widget.postId ?? widget.videoUrl.hashCode}');

    // Error state
    if (_error != null) {
      return GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          height: 200,
          color: Colors.black,
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off_rounded,
                    color: Colors.white.withValues(alpha: 0.4), size: 40),
                const SizedBox(height: 8),
                Text(_error!,
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _initialized = false;
                      _hasTrackedPlay = false;
                      _hasTrackedComplete = false;
                    });
                    _controller?.dispose();
                    _controller = null;
                    _initializeVideo();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Erneut versuchen'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return VisibilityDetector(
      key: visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onTap: _togglePlayPause,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          color: Colors.black,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Video Surface ──
              if (_initialized && _controller != null)
                AspectRatio(
                  aspectRatio:
                      _controller!.value.aspectRatio.clamp(0.5, 3.0),
                  child: VideoPlayer(_controller!),
                )
              else
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),

              // ── Play/Pause feedback animation ──
              if (_showPlayFeedback)
                AnimatedOpacity(
                  opacity: _showPlayFeedback ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: Icon(_feedbackIcon,
                        color: Colors.white, size: 36),
                  ),
                ),

              // ── Paused overlay (only when user explicitly paused) ──
              if (_initialized && !_isPlaying && _userPaused)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),

              // ── Video badge (top right) ──
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Video',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              // ── Mute toggle (top left) ──
              if (_initialized)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _globalMuteNotifier,
                      builder: (_, isMuted, __) => Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        child: Icon(
                          isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Duration badge (bottom right) ──
              if (_initialized && _duration.inSeconds > 0)
                Positioned(
                  bottom: 14,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // ── Progress bar (bottom) ──
              if (_initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }
}
