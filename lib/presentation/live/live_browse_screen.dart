import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../data/repositories/live_repository.dart';
import '../../domain/models/live_stream.dart';
import '../../providers/core/providers.dart';
import '../../providers/live/live_notifier.dart';
import '../../theme/app_theme.dart';

/// Browse active live streams — embedded in FeedScreen PageView.
class LiveBrowseScreen extends ConsumerStatefulWidget {
  const LiveBrowseScreen({super.key});

  @override
  ConsumerState<LiveBrowseScreen> createState() => _LiveBrowseScreenState();
}

class _LiveBrowseScreenState extends ConsumerState<LiveBrowseScreen>
    with TickerProviderStateMixin {
  List<LiveStream> _recentStreams = [];
  bool _recentLoading = true;

  // ── Swipe stack state (fuer "Jetzt live" im LOVO/TikTok-Stil) ──
  final Set<String> _skippedStreamIds = <String>{};
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isFlying = false;
  late final AnimationController _flyController;
  late final AnimationController _springController;
  Animation<Offset> _flyAnimation = const AlwaysStoppedAnimation(Offset.zero);
  Animation<Offset> _springAnimation = const AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _flyController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isFlying = false;
          _dragOffset = Offset.zero;
        });
      }
    });
    _springController.addListener(() {
      if (!mounted) return;
      setState(() => _dragOffset = _springAnimation.value);
    });

    Future.microtask(() {
      if (!mounted) return;
      ref.read(liveDiscoveryProvider.notifier).loadStreams();
      _loadRecentStreams();
    });
  }

  @override
  void dispose() {
    _flyController.dispose();
    _springController.dispose();
    super.dispose();
  }

  // ── Swipe handlers ─────────────────────────────────────────────

  void _onSwipeStart(DragStartDetails details) {
    if (_isFlying) return;
    _springController.stop();
    _isDragging = true;
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() => _dragOffset += details.delta);
  }

  void _onSwipeEnd(DragEndDetails details, LiveStream topStream) {
    if (!_isDragging) return;
    _isDragging = false;

    if (_dragOffset.dx.abs() > 100) {
      _flyOff(_dragOffset.dx > 0, topStream);
    } else {
      _springBack();
    }
  }

  void _flyOff(bool isLike, LiveStream stream) {
    final targetX = isLike ? 500.0 : -500.0;
    setState(() => _isFlying = true);
    _flyAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, _dragOffset.dy - 60),
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeIn));
    _flyController.forward(from: 0).then((_) {
      if (!mounted) return;
      if (isLike) {
        // YES → Stream oeffnen
        context.push('/live/${stream.id}');
      } else {
        // NOPE → lokal aus Stack entfernen
        setState(() => _skippedStreamIds.add(stream.id));
      }
    });
  }

  void _springBack() {
    _springAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
    _springController.forward(from: 0);
  }

  void _onNopeButton(LiveStream stream) {
    if (_isFlying || _isDragging) return;
    setState(() => _dragOffset = const Offset(-20, 0));
    _flyOff(false, stream);
  }

  void _onYesButton(LiveStream stream) {
    if (_isFlying || _isDragging) return;
    setState(() => _dragOffset = const Offset(20, 0));
    _flyOff(true, stream);
  }

  Future<void> _loadRecentStreams() async {
    try {
      final streams = await LiveRepository().getRecentStreams();
      if (mounted) setState(() { _recentStreams = streams; _recentLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final liveState = ref.watch(liveDiscoveryProvider);
    // Skipped Streams herausfiltern (bleibt innerhalb der Session lokal)
    final activeStreams = liveState.streams
        .where((s) => !_skippedStreamIds.contains(s.id))
        .toList();
    final bp = MediaQuery.of(context).padding.bottom;

    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));

    // No Scaffold — this is embedded in the FeedScreen PageView
    return Stack(
      children: [
        RefreshIndicator(
          color: accentColor,
          onRefresh: () async {
            await ref.read(liveDiscoveryProvider.notifier).refresh();
            await _loadRecentStreams();
          },
          child: CustomScrollView(
            slivers: [
              // ── Active Live Streams (TikTok/LOVO-Swipe) ──
              if (liveState.isLoading && liveState.streams.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (activeStreams.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jetzt live',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${activeStreams.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                  sliver: SliverToBoxAdapter(
                    child: _LiveSwipeStack(
                      streams: activeStreams,
                      accentColor: accentColor,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      dragOffset: _dragOffset,
                      isFlying: _isFlying,
                      flyController: _flyController,
                      springController: _springController,
                      flyAnimation: _flyAnimation,
                      onStart: _onSwipeStart,
                      onUpdate: _onSwipeUpdate,
                      onEnd: (d) => _onSwipeEnd(d, activeStreams.first),
                      onNope: () => _onNopeButton(activeStreams.first),
                      onYes: () => _onYesButton(activeStreams.first),
                    ),
                  ),
                ),
              ],

              // ── Empty state (oder alle durchgeswiped) ──
              if (!liveState.isLoading && activeStreams.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 8),
                    child: Center(
                      child: Column(children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.live_tv_rounded,
                            size: 40,
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          liveState.streams.isEmpty
                              ? 'Keine aktiven Live-Streams'
                              : 'Alle Streams durchgesehen',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          liveState.streams.isEmpty
                              ? 'Starte den ersten Stream!'
                              : 'Pull-to-Refresh fuer neue Streams',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: mutedColor,
                          ),
                        ),
                        if (liveState.streams.isNotEmpty &&
                            activeStreams.isEmpty) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _skippedStreamIds.clear());
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Zuruecksetzen'),
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),

              // ── Vergangene Streams ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('Vergangene Streams', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                ),
              ),

              if (_recentLoading)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
              else if (_recentStreams.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text('Noch keine vergangenen Streams', style: GoogleFonts.inter(fontSize: 14, color: mutedColor))),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final stream = _recentStreams[index];
                      final hostName = stream.hostDisplayName ?? stream.hostUsername ?? 'User';
                      final startedAt = stream.startedAt;
                      final endedAt = stream.endedAt;

                      // Stream duration
                      String durationStr = '';
                      if (startedAt != null && endedAt != null) {
                        final dur = endedAt.difference(startedAt);
                        if (dur.inHours > 0) {
                          durationStr = '${dur.inHours}h ${dur.inMinutes.remainder(60)}min';
                        } else {
                          durationStr = '${dur.inMinutes}min';
                        }
                      }

                      // Date + time
                      String dateStr = '';
                      if (startedAt != null) {
                        dateStr = '${startedAt.day.toString().padLeft(2, '0')}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.year} ${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}';
                      }

                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            ClipOval(
                              child: stream.hostAvatarUrl != null
                                  ? CachedNetworkImage(imageUrl: stream.hostAvatarUrl!, width: 44, height: 44, fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _avatarFallback(hostName, accentColor, 44))
                                  : _avatarFallback(hostName, accentColor, 44),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stream.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(hostName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: accentColor)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: mutedColor),
                                  const SizedBox(width: 4),
                                  Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                                  if (durationStr.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    Icon(Icons.timer_outlined, size: 12, color: mutedColor),
                                    const SizedBox(width: 4),
                                    Text(durationStr, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                                  ],
                                ]),
                              ],
                            )),
                            // Viewer stats
                            Column(
                              children: [
                                Icon(Icons.visibility_rounded, size: 16, color: mutedColor),
                                const SizedBox(height: 2),
                                Text('${stream.peakViewerCount}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _recentStreams.length,
                  ),
                ),

              // Bottom spacing
              SliverToBoxAdapter(child: SizedBox(height: bp + 100)),
            ],
          ),
        ),

        // FAB: Go Live (+)
        Positioned(
          right: 16,
          bottom: bp + 70,
          child: FloatingActionButton(
            heroTag: 'go_live_fab',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () => context.push('/live/start'),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name, Color accentColor, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withValues(alpha: 0.3)),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Colors.white))),
    );
  }
}

class _LiveStreamCard extends StatelessWidget {
  const _LiveStreamCard({
    required this.stream,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  final LiveStream stream;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hostName = stream.hostDisplayName ?? stream.hostUsername ?? 'User';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or gradient
            if (stream.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: stream.thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _buildGradientBackground(accentColor),
              )
            else
              _buildGradientBackground(accentColor),

            // Dark gradient overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),

            // LIVE badge + viewer count
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_rounded,
                            color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          _formatViewers(stream.viewerCount),
                          style: GoogleFonts.inter(
                            fontSize: 10,
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

            // Bottom info
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildAvatar(hostName),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hostName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    if (stream.hostAvatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: stream.hostAvatarUrl!,
          width: 18,
          height: 18,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _avatarFallback(name),
        ),
      );
    }
    return _avatarFallback(name);
  }

  Widget _avatarFallback(String name) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBackground(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.live_tv_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  String _formatViewers(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

// ═══════════════════════════════════════════════════════════════
//  LIVE SWIPE STACK (LOVO / TikTok Style)
// ═══════════════════════════════════════════════════════════════

class _LiveSwipeStack extends StatelessWidget {
  const _LiveSwipeStack({
    required this.streams,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.dragOffset,
    required this.isFlying,
    required this.flyController,
    required this.springController,
    required this.flyAnimation,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onNope,
    required this.onYes,
  });

  final List<LiveStream> streams;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final Offset dragOffset;
  final bool isFlying;
  final AnimationController flyController;
  final AnimationController springController;
  final Animation<Offset> flyAnimation;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final VoidCallback onNope;
  final VoidCallback onYes;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Karte: ~70% Bildschirmbreite, Aspect Ratio 3:4 (hochformat wie TikTok/LOVO)
    final cardWidth = screenWidth * 0.82;
    final cardHeight = cardWidth * 1.35;
    final visibleCount = min(3, streams.length);

    return SizedBox(
      height: cardHeight + 90, // Platz fuer Karten + Buttons
      child: Column(
        children: [
          SizedBox(
            height: cardHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background cards (hinter der aktiven Karte)
                for (int i = visibleCount - 1; i >= 1; i--)
                  Positioned(
                    top: 4.0 + (i * 6),
                    child: Transform.scale(
                      scale: 1.0 - (i * 0.04),
                      child: Opacity(
                        opacity: 1.0 - (i * 0.2),
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _LiveStreamCard(
                            stream: streams[i],
                            accentColor: accentColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                  ),

                // Top card (draggable)
                GestureDetector(
                  // onHorizontalDrag* statt onPan — gewinnt gegen PageView
                  onHorizontalDragStart: onStart,
                  onHorizontalDragUpdate: onUpdate,
                  onHorizontalDragEnd: onEnd,
                  onTap: onYes, // Tap = direkt reingehen
                  child: ListenableBuilder(
                    listenable: isFlying ? flyController : springController,
                    builder: (context, child) {
                      final offset = isFlying ? flyAnimation.value : dragOffset;
                      final rotation = offset.dx * 0.0005;
                      final likeOpacity = (offset.dx / 150).clamp(0.0, 1.0);
                      final nopeOpacity = (-offset.dx / 150).clamp(0.0, 1.0);

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translate(offset.dx, offset.dy)
                          ..rotateZ(rotation),
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _LiveStreamCard(
                                stream: streams.first,
                                accentColor: accentColor,
                                textColor: textColor,
                                mutedColor: mutedColor,
                                onTap: onYes,
                              ),
                              // YES Overlay (gruen, rechts)
                              if (likeOpacity > 0)
                                Positioned(
                                  top: 40,
                                  left: 24,
                                  child: Opacity(
                                    opacity: likeOpacity,
                                    child: Transform.rotate(
                                      angle: -0.3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 3,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'YES',
                                          style: GoogleFonts.inter(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // NOPE Overlay (rot, links)
                              if (nopeOpacity > 0)
                                Positioned(
                                  top: 40,
                                  right: 24,
                                  child: Opacity(
                                    opacity: nopeOpacity,
                                    child: Transform.rotate(
                                      angle: 0.3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 3,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'NOPE',
                                          style: GoogleFonts.inter(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // NOPE / YES Buttons wie bei LOVO/Tinder
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SwipeActionButton(
                icon: Icons.close_rounded,
                color: Colors.red,
                onTap: onNope,
              ),
              const SizedBox(width: 32),
              _SwipeActionButton(
                icon: Icons.play_arrow_rounded,
                color: Colors.green,
                onTap: onYes,
                large: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 68.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: large ? 38 : 30),
      ),
    );
  }
}
