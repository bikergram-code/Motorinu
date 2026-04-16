import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/video_cache_service.dart';
import 'post_video_player.dart' show globalMuteNotifier;

/// Access NativePlayer for mpv property tuning.
import 'package:media_kit/src/player/native/player/real.dart'
    show NativePlayer;

/// Fullscreen video player (media_kit) for the Reels tab.
///
/// Strategy: tries **hardware decoding** first (smooth, GPU-accelerated).
/// If the device's MediaCodec can't handle the format, automatically
/// retries with **software decoding** (ffmpeg / libmpv).
///
/// Optimizations for fast startup:
/// - Thumbnail shown immediately while video loads
/// - mpv demuxer/cache tuned for minimal buffering before first frame
/// - Crossfade from thumbnail to video when ready
class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isActive,
    this.postId,
    this.thumbnailUrl,
    this.onPlayStarted,
    this.onPlayCompleted,
    this.onTap,
    this.onDoubleTap,
    this.onProgressChanged,
  });

  final String videoUrl;
  final bool isActive;
  final int? postId;
  final String? thumbnailUrl;
  final VoidCallback? onPlayStarted;
  final VoidCallback? onPlayCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<double>? onProgressChanged;

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool _initialized = false;

  /// True once the first video frame has been decoded (video surface ready).
  bool _videoReady = false;
  bool _isPlaying = false;
  bool _userPaused = false;
  bool _hasTrackedPlay = false;
  bool _hasTrackedComplete = false;
  String? _error;

  /// true = try HW decoding first, false = SW fallback active
  bool _hwAccel = true;

  /// Retry counter for init failures (handles resource contention on tablets).
  int _retryCount = 0;

  Duration _duration = Duration.zero;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalMuteNotifier.addListener(_onGlobalMuteChanged);
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive && _initialized && !_userPaused) {
        _playVideo();
      } else if (!widget.isActive) {
        _pauseVideo();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    } else if (state == AppLifecycleState.resumed &&
        widget.isActive &&
        !_userPaused) {
      _playVideo();
    }
  }

  void _onGlobalMuteChanged() {
    _player?.setVolume(globalMuteNotifier.value ? 0 : 100);
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

      _player = Player(
        configuration: PlayerConfiguration(
          bufferSize: 8 * 1024 * 1024, // 8 MB für alle Geräte
        ),
      );

      // ── mpv decode optimizations ──
      if (_player!.platform is NativePlayer) {
        final mpv = _player!.platform as NativePlayer;

        // Skip deblocking filter — CPU saver
        await mpv.setProperty('vd-lavc-skiploopfilter', 'nonref');
        // Fast decode flags in libavcodec
        await mpv.setProperty('vd-lavc-fast', 'yes');
        // Use all CPU cores for software decode
        await mpv.setProperty('vd-lavc-threads', '0');
        // Drop frames if decoder can't keep up
        await mpv.setProperty('framedrop', 'vo');
        // Buffering before first frame
        await mpv.setProperty('demuxer-readahead-secs', '1');
        // Smooth playback sync
        await mpv.setProperty('video-sync', 'display-resample');
        // Low-latency hacks
        await mpv.setProperty('video-latency-hacks', 'yes');
      }

      // Reels are fullscreen — same scale for all devices
      final scale = isTablet ? 0.5 : 0.75;

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
            _duration = d;
          }
        }),
      );

      _subs.add(
        _player!.stream.position.listen((pos) {
          if (!mounted) return;
          final totalMs = _duration.inMilliseconds;
          if (totalMs <= 0) return;

          final progress =
              (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
          widget.onProgressChanged?.call(progress);

          if (!_hasTrackedComplete && progress >= 0.75) {
            _hasTrackedComplete = true;
            widget.onPlayCompleted?.call();
          }
        }),
      );

      _subs.add(
        _player!.stream.playing.listen((playing) {
          if (mounted) setState(() => _isPlaying = playing);
        }),
      );

      // Track video dimensions → mark video surface ready
      _subs.add(
        _player!.stream.width.listen((_) => _markVideoReady()),
      );
      _subs.add(
        _player!.stream.height.listen((_) => _markVideoReady()),
      );

      _subs.add(
        _player!.stream.error.listen((error) {
          if (!mounted || error.isEmpty) return;
          debugPrint('[ReelVideoPlayer] Stream error (hw=$_hwAccel, retry=$_retryCount): $error');

          if (_hwAccel) {
            _hwAccel = false;
            _disposePlayer();
            _initializeVideo();
          } else if (_retryCount < 1) {
            _retryCount++;
            _hwAccel = true;
            _disposePlayer();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && widget.isActive) {
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
        if (widget.isActive && !_userPaused) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('[ReelVideoPlayer] Init error (hw=$_hwAccel, retry=$_retryCount): $e');

      if (_hwAccel) {
        _hwAccel = false;
        _disposePlayer();
        _initializeVideo();
      } else if (_retryCount < 1) {
        _retryCount++;
        _hwAccel = true;
        _disposePlayer();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && widget.isActive) {
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

  void _handleTap() {
    if (_player == null || !_initialized) return;

    if (_isPlaying) {
      _pauseVideo();
      _userPaused = true;
    } else {
      _playVideo();
      _userPaused = false;
    }
    widget.onTap?.call();
  }

  bool get _hasThumbnail =>
      widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalMuteNotifier.removeListener(_onGlobalMuteChanged);
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildErrorState();

    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Thumbnail placeholder (shown until video surface ready) ──
            if (_hasThumbnail && !_videoReady)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),

            // ── Video surface — fullscreen cover (media_kit) ──
            if (_initialized && _videoController != null)
              AnimatedOpacity(
                opacity: _videoReady ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SizedBox.expand(
                  child: IgnorePointer(
                    child: Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fit: BoxFit.cover,
                      fill: Colors.black,
                      pauseUponEnteringBackgroundMode: false,
                      resumeUponEnteringForegroundMode: false,
                    ),
                  ),
                ),
              ),

            // ── Loading spinner (only if no thumbnail) ──
            if (!_videoReady && !_hasThumbnail)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),

            // Paused overlay
            if (_initialized && !_isPlaying && _userPaused)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: () {
        if (!_hasThumbnail) {
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
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasThumbnail)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Container(
              color: Colors.black
                  .withValues(alpha: _hasThumbnail ? 0.4 : 1.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasThumbnail
                          ? Icons.hd_outlined
                          : Icons.videocam_off_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!_hasThumbnail) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tippen zum erneut laden',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
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
}
