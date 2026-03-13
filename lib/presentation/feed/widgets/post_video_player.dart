import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/video_cache_service.dart';

/// Access NativePlayer for mpv property tuning.
import 'package:media_kit/src/player/native/player/real.dart'
    show NativePlayer;

/// Global mute state shared across all video players in the feed.
/// When a user mutes one video, all auto-playing videos are muted.
/// Accessible as [globalMuteNotifier] for Reels player too.
final globalMuteNotifier = ValueNotifier<bool>(true); // Start muted

/// Inline video player (media_kit) with viewport-triggered autoplay.
///
/// Strategy: tries **hardware decoding** first (smooth, GPU-accelerated).
/// If the device's MediaCodec can't handle the format (e.g. 4K HEVC on
/// older tablets), automatically retries with **software decoding** (ffmpeg).
///
/// Optimizations for fast startup:
/// - Thumbnail shown immediately while video loads (no blank screen)
/// - mpv demuxer/cache tuned for minimal buffering before first frame
/// - Crossfade from thumbnail to video when ready
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

class _PostVideoPlayerState extends State<PostVideoPlayer>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool _initialized = false;

  /// True once the first video frame has been decoded (video surface ready).
  bool _videoReady = false;
  bool _isPlaying = false;
  bool _isVisible = true;  // Default true — initState only fires near viewport
  bool _userPaused = false;
  bool _hasTrackedPlay = false;
  bool _hasTrackedComplete = false;
  String? _error;

  /// true = try HW decoding first, false = SW fallback active
  bool _hwAccel = true;

  /// Retry counter for init failures (handles resource contention on tablets
  /// where two videos might try to init simultaneously).
  int _retryCount = 0;

  // Progress tracking
  double _progress = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Aspect ratio (default 16:9, updated from video metadata)
  double _aspectRatio = 16 / 9;

  // Show play/pause feedback animation
  bool _showPlayFeedback = false;
  IconData _feedbackIcon = Icons.play_arrow_rounded;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalMuteNotifier.addListener(_onGlobalMuteChanged);
    // Initialize video immediately — ListView.builder only creates widgets
    // that are within cacheExtent (~250px of viewport), so this won't create
    // unnecessary players. VisibilityDetector handles play/pause only.
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    }
  }

  void _onGlobalMuteChanged() {
    _player?.setVolume(globalMuteNotifier.value ? 0 : 100);
    if (mounted) setState(() {});
  }

  void _disposePlayer() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  Future<void> _initializeVideo() async {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final screenWidth = view.physicalSize.width / view.devicePixelRatio;
      final isTablet = screenWidth > 600;

      // Smaller buffer for faster first-frame display.
      _player = Player(
        configuration: PlayerConfiguration(
          bufferSize: isTablet ? 4 * 1024 * 1024 : 8 * 1024 * 1024,
        ),
      );

      // ── mpv decode optimizations ──
      if (_player!.platform is NativePlayer) {
        final mpv = _player!.platform as NativePlayer;

        // Use all CPU cores for software decode
        await mpv.setProperty('vd-lavc-threads', '0');
        // Drop frames if decoder can't keep up
        await mpv.setProperty('framedrop', 'vo');
        // Faster startup: less buffering before first frame
        await mpv.setProperty('demuxer-readahead-secs', '1');
        // Skip deblocking filter for non-ref frames (safe optimization)
        await mpv.setProperty('vd-lavc-skiploopfilter', 'nonref');
      }

      // Scale video surface down for rendering.
      final scale = isTablet ? 0.5 : 0.5;

      final config = _hwAccel
          ? VideoControllerConfiguration(scale: scale)
          : VideoControllerConfiguration(
              enableHardwareAcceleration: false,
              scale: scale,
            );

      _videoController = VideoController(_player!, configuration: config);

      // ── Reactive stream listeners ──

      _subs.add(
        _player!.stream.duration.listen((d) {
          if (mounted && d > Duration.zero) {
            setState(() => _duration = d);
          }
        }),
      );

      _subs.add(
        _player!.stream.position.listen((pos) {
          if (!mounted) return;
          final totalMs = _duration.inMilliseconds;
          if (totalMs <= 0) return;

          final p = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

          if (!_hasTrackedComplete && p >= 0.75) {
            _hasTrackedComplete = true;
            widget.onPlayCompleted?.call();
          }

          setState(() {
            _progress = p;
            _position = pos;
          });
        }),
      );

      _subs.add(
        _player!.stream.playing.listen((playing) {
          if (mounted) {
            setState(() => _isPlaying = playing);
            // On some devices (Tab A9) width/height stay null even while
            // playing. Mark video ready after a short delay once playback starts.
            if (playing && !_videoReady) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && !_videoReady && _player != null) {
                  setState(() => _videoReady = true);
                }
              });
            }
          }
        }),
      );

      // Track video dimensions → aspect ratio + mark video surface ready
      _subs.add(
        _player!.stream.width.listen((_) {
          _updateAspectRatio();
          _markVideoReady();
        }),
      );
      _subs.add(
        _player!.stream.height.listen((_) {
          _updateAspectRatio();
          _markVideoReady();
        }),
      );

      _subs.add(
        _player!.stream.error.listen((error) {
          if (!mounted || error.isEmpty) return;
          debugPrint('[PostVideoPlayer] Stream error (hw=$_hwAccel, retry=$_retryCount): $error');

          if (_hwAccel) {
            // HW failed → try SW decoding
            _hwAccel = false;
            _disposePlayer();
            _initializeVideo();
          } else if (_retryCount < 1) {
            // Both HW+SW failed → wait and retry once (handles resource
            // contention when another player hasn't fully released yet)
            _retryCount++;
            _hwAccel = true;
            _disposePlayer();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _initializeVideo();
              }
            });
          } else {
            setState(() => _error =
                'Video-Auflösung wird auf diesem Gerät nicht unterstützt');
          }
        }),
      );

      // ── Configure player ──
      await _player!.setVolume(globalMuteNotifier.value ? 0 : 100);
      await _player!.setPlaylistMode(PlaylistMode.single); // loop

      // Check cache: if cached → instant local file, else → stream from URL
      final videoSource =
          await VideoCacheService.instance.getVideoPath(widget.videoUrl);
      await _player!.open(Media(videoSource), play: false);

      // If streamed from network, cache in background for next time
      if (videoSource == widget.videoUrl) {
        VideoCacheService.instance.prefetch(widget.videoUrl);
      }

      if (mounted) {
        setState(() => _initialized = true);

        if (_isVisible && !_userPaused) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('[PostVideoPlayer] Init error (hw=$_hwAccel, retry=$_retryCount): $e');

      if (_hwAccel) {
        // HW failed → try SW decoding
        _hwAccel = false;
        _disposePlayer();
        _initializeVideo();
      } else if (_retryCount < 1) {
        // Both HW+SW failed → wait and retry once (handles resource
        // contention when another player hasn't fully released yet)
        _retryCount++;
        _hwAccel = true;
        _disposePlayer();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _initializeVideo();
        }
      } else if (mounted) {
        setState(() => _error = 'Video konnte nicht geladen werden');
      }
    }
  }

  void _markVideoReady() {
    if (_videoReady || !mounted || _player == null) return;
    final w = _player!.state.width;
    final h = _player!.state.height;
    if (w != null && w > 0 && h != null && h > 0) {
      setState(() => _videoReady = true);
    }
  }

  void _updateAspectRatio() {
    if (!mounted || _player == null) return;
    final w = _player!.state.width;
    final h = _player!.state.height;
    if (w != null && w > 0 && h != null && h > 0) {
      setState(() => _aspectRatio = (w / h).clamp(0.5, 3.0));
    }
  }

  void _playVideo() {
    if (_player == null || !_initialized) return;
    _player!.play();

    if (!_hasTrackedPlay) {
      _hasTrackedPlay = true;
      widget.onPlayStarted?.call();
    }
  }

  void _pauseVideo() {
    if (_player == null || !_initialized) return;
    _player!.pause();
  }

  void _togglePlayPause() {
    if (_player == null || !_initialized) return;

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
    globalMuteNotifier.value = !globalMuteNotifier.value;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.3;

    if (visible != _isVisible) {
      _isVisible = visible;

      if (visible && _initialized && _player != null && !_userPaused) {
        // Scrolled into view → resume playback
        _playVideo();
      } else if (!visible && _initialized && _player != null) {
        // Scrolled out of view → pause to save resources
        _pauseVideo();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalMuteNotifier.removeListener(_onGlobalMuteChanged);
    _disposePlayer();
    super.dispose();
  }

  bool get _hasThumbnail =>
      widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final visibilityKey =
        Key('video_${widget.postId ?? widget.videoUrl.hashCode}');

    // Error state
    if (_error != null) return _buildErrorState();

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
              // ── Thumbnail placeholder (shown until video surface ready) ──
              if (_hasThumbnail && !_videoReady)
                AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: CachedNetworkImage(
                    imageUrl: widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // ── Video Surface (media_kit) ──
              if (_initialized && _videoController != null)
                AnimatedOpacity(
                  opacity: _videoReady ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: AspectRatio(
                    aspectRatio: _aspectRatio,
                    child: Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fill: Colors.black,
                      pauseUponEnteringBackgroundMode: false,
                      resumeUponEnteringForegroundMode: false,
                    ),
                  ),
                ),

              // ── Loading spinner (only if no thumbnail) ──
              if (!_initialized && !_hasThumbnail)
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),

              // ── Small loading indicator on thumbnail ──
              if (_hasThumbnail && !_videoReady && _error == null)
                Positioned(
                  bottom: 14,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('Laden...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10)),
                      ],
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

              // ── Paused overlay ──
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
                      valueListenable: globalMuteNotifier,
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
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        color: Colors.black,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_hasThumbnail)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Container(
              color: Colors.black
                  .withValues(alpha: _hasThumbnail ? 0.35 : 0.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasThumbnail
                          ? Icons.hd_outlined
                          : Icons.videocam_off_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (!_hasThumbnail) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _initialized = false;
                            _videoReady = false;
                            _hwAccel = true;
                            _hasTrackedPlay = false;
                            _hasTrackedComplete = false;
                          });
                          _disposePlayer();
                          _initializeVideo();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Erneut versuchen'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
