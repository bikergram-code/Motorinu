import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/models/live_stream.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/live/live_notifier.dart';
import '../../theme/app_theme.dart';

/// Browse active live streams in the community.
class LiveBrowseScreen extends ConsumerStatefulWidget {
  const LiveBrowseScreen({super.key});

  @override
  ConsumerState<LiveBrowseScreen> createState() => _LiveBrowseScreenState();
}

class _LiveBrowseScreenState extends ConsumerState<LiveBrowseScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(liveDiscoveryProvider.notifier).loadStreams();
    });

    // Register Speed-Dial for Live tab
    Future.microtask(() {
      if (!mounted) return;
      final community = ref.read(communityProvider);
      final accentColor = community?.accentColor ?? AppTheme.accentDark;
      ref.read(speedDialItemsProvider.notifier).register([
        SpeedDialItem(
          icon: Icons.videocam_rounded,
          label: 'Go Live',
          color: Colors.red,
          onTap: () {
            if (!mounted) return;
            context.push('/live/start');
          },
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final liveState = ref.watch(liveDiscoveryProvider);

    final scaffoldBg = community?.scaffoldFor(brightness) ??
        (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top spacer for global top bar
            SizedBox(height: MediaQuery.of(context).padding.top + 8),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Aktive Streams',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  if (liveState.streams.isNotEmpty)
                    Text(
                      '${liveState.streams.length}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                color: accentColor,
                onRefresh: () =>
                    ref.read(liveDiscoveryProvider.notifier).refresh(),
                child: liveState.isLoading && liveState.streams.isEmpty
                    ? _buildLoading()
                    : liveState.streams.isEmpty
                        ? _buildEmpty(accentColor, textColor, mutedColor)
                        : _buildStreamGrid(
                            liveState.streams, accentColor, textColor, mutedColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildEmpty(Color accentColor, Color textColor, Color mutedColor) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
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
                'Keine aktiven Live-Streams',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Starte den ersten Stream!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/live/start'),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Go Live'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamGrid(
    List<LiveStream> streams,
    Color accentColor,
    Color textColor,
    Color mutedColor,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: streams.length,
      itemBuilder: (context, index) {
        return _LiveStreamCard(
          stream: streams[index],
          accentColor: accentColor,
          textColor: textColor,
          mutedColor: mutedColor,
          onTap: () => context.push('/live/${streams[index].id}'),
        );
      },
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
                  // Title
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
                  // Host info
                  Row(
                    children: [
                      if (stream.hostAvatarUrl != null)
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: stream.hostAvatarUrl!,
                            width: 18,
                            height: 18,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: Text(
                                  hostName.isNotEmpty
                                      ? hostName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Text(
                              hostName.isNotEmpty
                                  ? hostName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
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
