import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_trimmer/video_trimmer.dart';

/// Full-screen video trim editor.
/// Returns the trimmed [File], or null if cancelled.
/// Accepts a file path (String) so callers don't need dart:io.
class VideoTrimScreen extends StatefulWidget {
  const VideoTrimScreen({
    super.key,
    required this.videoFile,
    required this.accentColor,
  });

  /// Accepts either a [File] or a [String] path.
  final dynamic videoFile;
  final Color accentColor;

  File _resolveFile() =>
      videoFile is File ? videoFile as File : File(videoFile as String);

  /// Opens the trim screen and returns the trimmed video [File], or null.
  static Future<File?> show(
    BuildContext context, {
    required dynamic videoFile,
    required Color accentColor,
  }) {
    return Navigator.of(context, rootNavigator: true).push<File?>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => VideoTrimScreen(
          videoFile: videoFile,
          accentColor: accentColor,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: loadVideo is called AFTER build, so TrimViewer is already
    // in the widget tree and can receive TrimmerEvent.initialized.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVideo());
  }

  Future<void> _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget._resolveFile());
    if (mounted) setState(() => _isLoaded = true);
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);

    await _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      onSave: (outputPath) {
        if (!mounted) return;
        if (outputPath != null) {
          Navigator.of(context).pop(File(outputPath));
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trimmen fehlgeschlagen')),
          );
        }
      },
    );
  }

  String _formatDuration(double ms) {
    final duration = Duration(milliseconds: ms.toInt());
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // TrimViewer is ALWAYS in the tree so it receives TrimmerEvent.initialized.
        // Loading overlay is shown on top until video is ready.
        child: Stack(
          children: [
            // ── Main content (always built) ──
            Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(null),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 26),
                      ),
                      Expanded(
                        child: Text(
                          'Video schneiden',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Skip trimming — use original
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () =>
                                Navigator.of(context).pop(widget._resolveFile()),
                        child: Text(
                          'Original',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Video Preview ──
                Expanded(
                  child: GestureDetector(
                    onTap: !_isLoaded
                        ? null
                        : () async {
                            final playing =
                                await _trimmer.videoPlaybackControl(
                              startValue: _startValue,
                              endValue: _endValue,
                            );
                            setState(() => _isPlaying = playing);
                          },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoViewer(trimmer: _trimmer),
                        if (!_isPlaying && _isLoaded)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 40),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Time labels ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_startValue),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.accentColor,
                        ),
                      ),
                      Text(
                        'Dauer: ${_formatDuration(_endValue - _startValue)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        _formatDuration(_endValue),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Trim Timeline (ALWAYS in tree) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TrimViewer(
                    trimmer: _trimmer,
                    viewerHeight: 60,
                    viewerWidth: MediaQuery.of(context).size.width - 32,
                    showDuration: false,
                    type: ViewerType.fixed,
                    maxVideoLength: const Duration(minutes: 3),
                    editorProperties: TrimEditorProperties(
                      borderPaintColor: widget.accentColor,
                      circlePaintColor: widget.accentColor,
                      scrubberPaintColor: Colors.white,
                      borderWidth: 3,
                      scrubberWidth: 2,
                      circleSize: 8,
                      circleSizeOnDrag: 12,
                      sideTapSize: 40,
                    ),
                    areaProperties: TrimAreaProperties(
                      thumbnailQuality: 25,
                    ),
                    onChangeStart: (value) =>
                        setState(() => _startValue = value),
                    onChangeEnd: (value) =>
                        setState(() => _endValue = value),
                    onChangePlaybackState: (playing) =>
                        setState(() => _isPlaying = playing),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Save Button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          (_isSaving || !_isLoaded) ? null : _saveAndReturn,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        disabledBackgroundColor:
                            widget.accentColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.content_cut_rounded,
                              color: Colors.white),
                      label: Text(
                        _isSaving
                            ? 'Wird geschnitten\u2026'
                            : 'Schneiden & Weiter',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Loading overlay (on top, blocks interaction until ready) ──
            if (!_isLoaded)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Video wird geladen\u2026',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
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
