import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../../core/community.dart';
import '../../data/repositories/live_repository.dart';
import '../../domain/models/live_stream.dart';
import '../../providers/core/providers.dart';
import '../../providers/live/live_notifier.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/topic_picker.dart';

/// Screen to start a live broadcast.
class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _titleController = TextEditingController();
  final List<int> _selectedTopicIds = [];
  bool _isStarting = false;

  /// Local camera preview track (before going live).
  lk.LocalVideoTrack? _previewTrack;
  bool _permissionDenied = false;

  /// Streams history with month filter.
  List<LiveStream> _historyStreams = [];
  late int _selectedYear;
  late int _selectedMonth;
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _startCameraPreview();
    _loadStreamsForMonth();
  }

  Future<void> _loadStreamsForMonth() async {
    setState(() => _historyLoading = true);
    try {
      final repo = ref.read(liveRepositoryProvider);
      final streams = await repo.getMyStreams(
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _historyStreams = streams;
          _historyLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[GoLive] Load streams error: $e');
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
    _loadStreamsForMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    // Don't go past current month
    if (_selectedYear == now.year && _selectedMonth >= now.month) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
    _loadStreamsForMonth();
  }

  String _monthName(int month) {
    const names = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return names[month];
  }

  @override
  void dispose() {
    _stopCameraPreview();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startCameraPreview() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }

      final track = await lk.LocalVideoTrack.createCameraTrack(
        const lk.CameraCaptureOptions(
          cameraPosition: lk.CameraPosition.front,
        ),
      );

      if (mounted) {
        setState(() => _previewTrack = track);
      } else {
        await track.stop();
      }
    } catch (e) {
      debugPrint('[GoLive] Camera preview error: $e');
    }
  }

  Future<void> _stopCameraPreview() async {
    if (_previewTrack != null) {
      await _previewTrack!.stop();
      _previewTrack = null;
    }
  }

  Future<void> _startLive() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib einen Titel ein'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);
    HapticFeedback.heavyImpact();

    // Stop preview camera so LiveKit can take over
    await _stopCameraPreview();

    try {
      final community = ref.read(communityProvider)?.name ?? 'bikergram';
      debugPrint('[_startLive] calling goLive...');
      await ref.read(goLiveProvider.notifier).goLive(
            title: title,
            topicId: _selectedTopicIds.isNotEmpty ? _selectedTopicIds.first : null,
            community: community,
          );
      debugPrint('[_startLive] goLive returned, mounted=$mounted');

      if (!mounted) return;

      // Check for errors from the notifier (caught internally)
      final goLiveState = ref.read(goLiveProvider);
      debugPrint('[_startLive] isLive=${goLiveState.isLive}, error=${goLiveState.error}, session=${goLiveState.session?.id}');

      if (goLiveState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: ${goLiveState.error}'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      if (goLiveState.isLive && goLiveState.session != null) {
        debugPrint('[_startLive] → navigating to broadcast screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _BroadcastActiveScreen(
              sessionId: goLiveState.session!.id,
              title: title,
            ),
          ),
        );
      } else {
        debugPrint('[_startLive] ⚠ Not navigating: isLive=${goLiveState.isLive}, session=${goLiveState.session != null}');
      }
    } catch (e) {
      debugPrint('[_startLive] EXCEPTION: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));
    final cardBg = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return Scaffold(
      backgroundColor:
          community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.close_rounded, color: textColor),
        ),
        title: Text(
          'Go Live',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera preview (live)
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111111) : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _previewTrack != null
                  ? lk.VideoTrackRenderer(
                      _previewTrack!,
                      fit: lk.VideoViewFit.cover,
                      mirrorMode: lk.VideoViewMirrorMode.mirror,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_permissionDenied) ...[
                            Icon(
                              Icons.videocam_off_rounded,
                              size: 36,
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Kamera-Berechtigung verweigert',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: mutedColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Kamera wird gestartet...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // Title input
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _titleController,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Titel deines Streams...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: mutedColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.title_rounded, color: mutedColor),
                ),
                maxLength: 100,
                maxLines: 1,
              ),
            ),

            const SizedBox(height: 16),

            // Topic picker
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TopicPicker(
                selectedTopicIds: _selectedTopicIds,
                maxTopics: 1,
                onChanged: (ids) => setState(() {
                  _selectedTopicIds.clear();
                  _selectedTopicIds.addAll(ids);
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Community info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: accentColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dein Stream wird in der ${community?.displayName ?? 'Community'}-Community live sein.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Go Live button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startLive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isStarting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Go Live',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Stream History with month filter ──
            const SizedBox(height: 32),

            // Month selector
            Row(
              children: [
                Icon(Icons.history_rounded, color: mutedColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Meine Streams',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Month navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _previousMonth,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.1),
                      ),
                      child: Icon(Icons.chevron_left_rounded,
                          color: accentColor, size: 22),
                    ),
                  ),
                  Text(
                    '${_monthName(_selectedMonth)} $_selectedYear',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final now = DateTime.now();
                      final isCurrentMonth = _selectedYear == now.year &&
                          _selectedMonth == now.month;
                      if (!isCurrentMonth) _nextMonth();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_selectedYear == DateTime.now().year &&
                                _selectedMonth == DateTime.now().month)
                            ? Colors.white.withValues(alpha: 0.03)
                            : accentColor.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: (_selectedYear == DateTime.now().year &&
                                _selectedMonth == DateTime.now().month)
                            ? mutedColor.withValues(alpha: 0.3)
                            : accentColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stream list
            if (_historyLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: mutedColor,
                    ),
                  ),
                ),
              )
            else if (_historyStreams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Keine Streams in ${_monthName(_selectedMonth)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: mutedColor,
                    ),
                  ),
                ),
              )
            else
              ..._historyStreams.map((stream) => _RecentStreamCard(
                    stream: stream,
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    cardBg: cardBg,
                  )),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Active broadcast screen (shown while streaming).
class _BroadcastActiveScreen extends ConsumerStatefulWidget {
  const _BroadcastActiveScreen({
    required this.sessionId,
    required this.title,
  });

  final String sessionId;
  final String title;

  @override
  ConsumerState<_BroadcastActiveScreen> createState() =>
      _BroadcastActiveScreenState();
}

class _BroadcastActiveScreenState
    extends ConsumerState<_BroadcastActiveScreen> {
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Start a timer to show elapsed time
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _elapsed += const Duration(seconds: 1));
      return true;
    });
  }

  Future<void> _endLive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Stream beenden?',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Dein Live-Stream wird für alle Zuschauer beendet.',
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Beenden',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(goLiveProvider.notifier).endLive();
      // Stats overlay will appear via state change (showStats == true)
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final goLiveState = ref.watch(goLiveProvider);

    final elapsedStr = _formatElapsed(_elapsed);

    // Show stats overlay when stream ended
    if (goLiveState.showStats) {
      return _LiveStatsScreen(
        stats: goLiveState.finalStats!,
        duration: goLiveState.streamDuration ?? _elapsed,
        accentColor: accentColor,
        onDismiss: () {
          ref.read(goLiveProvider.notifier).clearStats();
          if (mounted) Navigator.of(context).pop();
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview (LiveKit local video)
          if (goLiveState.localVideoTrack != null)
            Positioned.fill(
              child: lk.VideoTrackRenderer(
                goLiveState.localVideoTrack!,
                fit: lk.VideoViewFit.cover,
                mirrorMode: lk.VideoViewMirrorMode.auto,
              ),
            )
          else
            Container(
              color: const Color(0xFF111111),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kamera wird gestartet...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Elapsed time
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        elapsedStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Viewer count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${goLiveState.viewerCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Camera/Mic/Switch controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Toggle camera
                          _ControlButton(
                            icon: goLiveState.isCameraOn
                                ? Icons.videocam_rounded
                                : Icons.videocam_off_rounded,
                            label: goLiveState.isCameraOn ? 'Kamera' : 'Kamera aus',
                            isActive: goLiveState.isCameraOn,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(goLiveProvider.notifier).toggleCamera();
                            },
                          ),

                          // Toggle mic
                          _ControlButton(
                            icon: goLiveState.isMicOn
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            label: goLiveState.isMicOn ? 'Mikrofon' : 'Mikro aus',
                            isActive: goLiveState.isMicOn,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(goLiveProvider.notifier).toggleMic();
                            },
                          ),

                          // Switch camera
                          _ControlButton(
                            icon: Icons.flip_camera_ios_rounded,
                            label: 'Wechseln',
                            isActive: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(goLiveProvider.notifier).switchCamera();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // End button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _endLive,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Stream beenden',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

/// Compact card showing a recent live stream with key stats.
class _RecentStreamCard extends StatelessWidget {
  const _RecentStreamCard({
    required this.stream,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.cardBg,
  });

  final LiveStream stream;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    // Calculate duration
    final duration = (stream.startedAt != null && stream.endedAt != null)
        ? stream.endedAt!.difference(stream.startedAt!)
        : null;

    // Format date
    final dateStr = stream.endedAt != null
        ? _formatDate(stream.endedAt!)
        : 'Unbekannt';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + date
          Row(
            children: [
              Expanded(
                child: Text(
                  stream.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _MiniStat(
                icon: Icons.timer_rounded,
                value: duration != null ? _formatDuration(duration) : '-',
                color: accentColor,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.trending_up_rounded,
                value: '${stream.peakViewerCount}',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.people_rounded,
                value: '${stream.totalUniqueViewers}',
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.chat_bubble_rounded,
                value: '${stream.totalChatMessages}',
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'vor ${diff.inHours}h';
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Circular control button for camera/mic/switch.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.5),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  LIVE STREAM STATS SCREEN (shown after ending)
// ═══════════════════════════════════════════════════

class _LiveStatsScreen extends StatelessWidget {
  const _LiveStatsScreen({
    required this.stats,
    required this.duration,
    required this.accentColor,
    required this.onDismiss,
  });

  final LiveStream stats;
  final Duration duration;
  final Color accentColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Scrollbarer Content — vermeidet Overflow auf kleinen Geraeten
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Header icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 40,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Stream beendet',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 28),

                      // Stats grid (2x2)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.timer_rounded,
                              label: 'Dauer',
                              value: _formatDuration(duration),
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.trending_up_rounded,
                              label: 'Peak Zuschauer',
                              value: '${stats.peakViewerCount}',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_rounded,
                              label: 'Zuschauer gesamt',
                              value: '${stats.totalUniqueViewers}',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.chat_bubble_rounded,
                              label: 'Nachrichten',
                              value: '${stats.totalChatMessages}',
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Done button — immer sichtbar am unteren Rand
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Fertig',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          // FittedBox verhindert Wrap/Overflow bei langen Werten ("1m 38s")
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
