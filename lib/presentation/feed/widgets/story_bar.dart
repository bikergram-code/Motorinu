import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../theme/app_theme.dart';
import 'story_viewer.dart';

/// Result class for story bar data.
class StoryBarData {
  const StoryBarData({
    this.hasOwnStory = false,
    this.ownStoryData,
    this.stories = const [],
  });
  final bool hasOwnStory;
  final _StoryData? ownStoryData;
  final List<_StoryData> stories;
}

/// Provider that fetches active stories from the stories table.
final storyUsersProvider = FutureProvider.autoDispose<StoryBarData>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const StoryBarData();

  final now = DateTime.now().toUtc().toIso8601String();

  // 1) Fetch current user's active stories (full data for viewer)
  final ownStoriesData = await supabase
      .from('stories')
      .select('id, media_url, caption, created_at')
      .eq('user_id', userId)
      .gt('expires_at', now)
      .order('created_at', ascending: true);

  final hasOwnStory = ownStoriesData.isNotEmpty;

  _StoryData? ownStoryDataObj;
  if (hasOwnStory) {
    final ownItems = ownStoriesData.map((s) => _StoryMediaItem(
      id: s['id'] as int,
      mediaUrl: s['media_url'] as String,
      caption: s['caption'] as String?,
      createdAt: DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
    )).toList();

    // Get own profile info
    final ownProfile = await supabase
        .from('profiles')
        .select('username, display_name, avatar_url, bikername')
        .eq('id', userId)
        .maybeSingle();

    final ownName = ownProfile?['display_name'] as String? ??
        ownProfile?['bikername'] as String? ??
        ownProfile?['username'] as String? ??
        'Du';

    ownStoryDataObj = _StoryData(
      userId: userId,
      username: ownName,
      avatarUrl: ownProfile?['avatar_url'] as String?,
      isOwn: true,
      hasUnread: true,
      mediaItems: ownItems,
    );
  }

  // 2) Get IDs of users I follow
  final followData = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', userId);

  final followedIds =
      followData.map((r) => r['following_id'] as String).toList();

  debugPrint('[StoryBar] Following ${followedIds.length} users: $followedIds');

  if (followedIds.isEmpty) {
    return StoryBarData(
      hasOwnStory: hasOwnStory,
      ownStoryData: ownStoryDataObj,
    );
  }

  // 3) Get active stories from followed users — ALL stories, not just newest
  final storiesData = await supabase
      .from('stories')
      .select('id, user_id, media_url, caption, created_at, profiles!stories_user_id_fkey(username, display_name, avatar_url, bikername)')
      .inFilter('user_id', followedIds)
      .gt('expires_at', now)
      .order('created_at', ascending: true)
      .limit(100);

  debugPrint('[StoryBar] Found ${storiesData.length} stories from followed users');

  // Group stories by user_id
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in storiesData) {
    final uid = row['user_id'] as String;
    grouped.putIfAbsent(uid, () => []).add(row);
  }

  final stories = <_StoryData>[];

  for (final entry in grouped.entries) {
    final rows = entry.value;
    final firstRow = rows.first;
    final profile = firstRow['profiles'] as Map<String, dynamic>?;
    if (profile == null) continue;

    final displayName = profile['display_name'] as String? ??
        profile['bikername'] as String? ??
        profile['username'] as String? ??
        '?';
    final avatarUrl = profile['avatar_url'] as String?;

    final items = rows.map((r) => _StoryMediaItem(
      id: r['id'] as int,
      mediaUrl: r['media_url'] as String,
      caption: r['caption'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    )).toList();

    stories.add(_StoryData(
      userId: entry.key,
      username: displayName,
      avatarUrl: avatarUrl,
      hasUnread: true,
      mediaItems: items,
    ));
  }

  return StoryBarData(
    hasOwnStory: hasOwnStory,
    ownStoryData: ownStoryDataObj,
    stories: stories,
  );
});

class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    final authState = ref.watch(authNotifierProvider);
    final currentUser = authState is Authenticated ? authState.user : null;

    final storyBarAsync = ref.watch(storyUsersProvider);

    // The "add" button — always present, always opens gallery
    final addButton = _StoryData(
      username: 'Story',
      avatarUrl: currentUser?.avatarUrl,
      isOwn: true,
      hasUnread: false,
      mediaItems: const [],
    );

    return SizedBox(
      height: 100,
      child: storyBarAsync.when(
        data: (barData) {
          // Build the list: [+ Add] [Own active story?] [Other users...]
          final items = <_StoryData>[addButton];

          // If user has active stories → show as separate viewable circle
          if (barData.hasOwnStory && barData.ownStoryData != null) {
            items.add(_StoryData(
              username: 'Deine Story',
              userId: barData.ownStoryData!.userId,
              avatarUrl: barData.ownStoryData!.avatarUrl,
              isOwn: false, // treat as viewable, not as "add" button
              hasUnread: true,
              mediaItems: barData.ownStoryData!.mediaItems,
            ));
          }

          // Other users' stories
          items.addAll(barData.stories);

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final story = items[index];

              if (index == 0) {
                // Always the "+" add button
                return _StoryItem(
                  data: story,
                  accentColor: accentColor,
                  onTap: () => _createStory(context, ref, accentColor),
                );
              }

              if (index == 1 && barData.hasOwnStory) {
                // Own active story → open viewer (marked isOwn for viewer)
                return _StoryItem(
                  data: story,
                  accentColor: accentColor,
                  onTap: () {
                    // Build a proper own _StoryData for the viewer
                    final ownForViewer = _StoryData(
                      username: story.username,
                      userId: story.userId,
                      avatarUrl: story.avatarUrl,
                      isOwn: true,
                      hasUnread: true,
                      mediaItems: story.mediaItems,
                    );
                    _openViewer(context, ref, accentColor, ownForViewer, barData);
                  },
                );
              }

              // Other users → open viewer
              return _StoryItem(
                data: story,
                accentColor: accentColor,
                onTap: () => _openViewer(context, ref, accentColor, story, barData),
              );
            },
          );
        },
        loading: () {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StoryItem(
                  data: addButton,
                  accentColor: accentColor,
                  onTap: () => _createStory(context, ref, accentColor),
                );
              }
              return _StoryShimmer();
            },
          );
        },
        error: (_, __) {
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _StoryItem(
                data: addButton,
                accentColor: accentColor,
                onTap: () => _createStory(context, ref, accentColor),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    WidgetRef ref,
    Color accentColor,
    _StoryData tappedStory,
    StoryBarData barData,
  ) {
    // Build list of StoryGroups for the viewer
    final groups = <StoryGroup>[];

    // If tapped on own story, add own first
    if (tappedStory.isOwn && barData.ownStoryData != null) {
      final own = barData.ownStoryData!;
      groups.add(StoryGroup(
        userId: own.userId ?? '',
        username: own.username,
        avatarUrl: own.avatarUrl,
        isOwn: true,
        stories: own.mediaItems
            .map((m) => StoryItem(
                  id: m.id,
                  mediaUrl: m.mediaUrl,
                  caption: m.caption,
                  createdAt: m.createdAt,
                ))
            .toList(),
      ));
    }

    // Add all other users' stories
    for (final s in barData.stories) {
      if (s.mediaItems.isEmpty) continue;
      groups.add(StoryGroup(
        userId: s.userId ?? '',
        username: s.username,
        avatarUrl: s.avatarUrl,
        isOwn: false,
        stories: s.mediaItems
            .map((m) => StoryItem(
                  id: m.id,
                  mediaUrl: m.mediaUrl,
                  caption: m.caption,
                  createdAt: m.createdAt,
                ))
            .toList(),
      ));
    }

    if (groups.isEmpty) return;

    // Find the index of the tapped user
    int initialIndex = 0;
    if (!tappedStory.isOwn && tappedStory.userId != null) {
      initialIndex = groups.indexWhere((g) => g.userId == tappedStory.userId);
      if (initialIndex == -1) initialIndex = 0;
    }

    StoryViewer.show(
      context,
      groups: groups,
      initialGroupIndex: initialIndex,
      accentColor: accentColor,
    );
  }

  Future<void> _createStory(BuildContext context, WidgetRef ref, Color accentColor) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Show media type picker: Foto, Video, Kamera
    final mediaChoice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Story erstellen',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 16),
              _StoryMediaOption(
                icon: Icons.photo_library_rounded,
                label: 'Foto aus Galerie',
                color: accentColor,
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'photo'),
              ),
              _StoryMediaOption(
                icon: Icons.videocam_rounded,
                label: 'Video aus Galerie',
                color: const Color(0xFFE040FB),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
              _StoryMediaOption(
                icon: Icons.camera_alt_rounded,
                label: 'Kamera',
                color: const Color(0xFF00E676),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (mediaChoice == null || !context.mounted) return;

    final picker = ImagePicker();
    List<XFile> files = [];

    switch (mediaChoice) {
      case 'photo':
        final picked = await picker.pickMultiImage(imageQuality: 85, limit: 10);
        files = picked;
        break;
      case 'video':
        final video = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 30),
        );
        if (video != null) files = [video];
        break;
      case 'camera':
        final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (photo != null) files = [photo];
        break;
    }

    if (files.isEmpty || !context.mounted) return;

    // Ask for optional caption
    String? caption;
    final captionController = TextEditingController();
    final brightness = Theme.of(context).brightness;
    caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: brightness == Brightness.dark ? const Color(0xFF222222) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Story-Text',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w700, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        content: TextField(
          controller: captionController,
          autofocus: true,
          maxLength: 200,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'Text hinzuf\u00fcgen (optional)',
            hintStyle: GoogleFonts.inter(
                fontSize: 15, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF9E9E9E)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text('\u00dcberspringen',
                style: GoogleFonts.inter(color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF9E9E9E))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, captionController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: accentColor),
            child: Text('Weiter',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    // Don't dispose captionController here — Flutter still rebuilds the
    // Overlay/Dialog tree after Navigator.pop(). Disposing now causes
    // "TextEditingController used after being disposed" red screen.
    // The controller is GC'd automatically when the dialog is gone.

    if (!context.mounted) return;
    // null = dialog dismissed entirely
    if (caption == null) return;
    if (caption.isEmpty) caption = null;

    final count = files.length;
    final label = count == 1 ? 'Story wird hochgeladen\u2026' : '$count Stories werden hochgeladen\u2026';

    // Show uploading indicator
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
      backgroundColor: accentColor,
      duration: const Duration(seconds: 30),
    ));

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Nicht eingeloggt');

      int uploaded = 0;

      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;

        final ext = file.name.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
        final path = 'stories/$userId/${DateTime.now().millisecondsSinceEpoch}_$uploaded.$ext';

        await supabase.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final mediaUrl = supabase.storage.from('posts').getPublicUrl(path);

        await supabase.from('stories').insert({
          'user_id': userId,
          'media_url': mediaUrl,
          'media_type': isVideo ? 'video' : 'image',
          if (caption != null) 'caption': caption,
        });

        uploaded++;
      }

      if (!context.mounted) return;
      ref.invalidate(storyUsersProvider);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final successMsg = uploaded == 1
          ? 'Story ver\u00f6ffentlicht! \u2705'
          : '$uploaded Stories ver\u00f6ffentlicht! \u2705';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMsg),
        backgroundColor: accentColor,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

class _StoryMediaItem {
  const _StoryMediaItem({
    required this.id,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
  });

  final int id;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
}

class _StoryData {
  const _StoryData({
    required this.username,
    this.userId,
    this.avatarUrl,
    this.isOwn = false,
    this.hasUnread = false,
    this.mediaItems = const [],
  });

  final String username;
  final String? userId;
  final String? avatarUrl;
  final bool isOwn;
  final bool hasUnread;
  final List<_StoryMediaItem> mediaItems;
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({
    required this.data,
    required this.accentColor,
    this.onTap,
  });

  final _StoryData data;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: data.hasUnread && !data.isOwn
                    ? SweepGradient(
                        colors: [
                          accentColor,
                          const Color(0xFFE040FB),
                          const Color(0xFFFF6B35),
                          accentColor,
                        ],
                        stops: const [0.0, 0.33, 0.66, 1.0],
                      )
                    : data.isOwn
                        ? LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          )
                        : LinearGradient(
                            // Seen: subtle grey ring
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.06),
                            ],
                          ),
              ),
              child: Builder(builder: (ctx) {
                final isDk = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDk ? Colors.black : Colors.white,
                ),
                child: data.isOwn ? _buildOwnAvatar() : _buildUserAvatar(),
              );
              }),
            ),
            const SizedBox(height: 6),
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Text(
                data.username,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight:
                      data.hasUnread ? FontWeight.w600 : FontWeight.w400,
                  color: isDark
                      ? Colors.white.withValues(alpha: data.hasUnread ? 0.9 : 0.5)
                      : (data.hasUnread ? const Color(0xFF202124) : const Color(0xFF5F6368)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnAvatar() {
    if (data.avatarUrl != null && data.avatarUrl!.isNotEmpty) {
      return Stack(
        children: [
          ClipOval(
            child: Image.network(
              data.avatarUrl!,
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              errorBuilder: (_, __, ___) => _buildPlaceholderCircle(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 12),
            ),
          ),
        ],
      );
    }

    return _buildPlaceholderCircle(
      child: Icon(
        Icons.add_rounded,
        color: Colors.white.withValues(alpha: 0.6),
        size: 24,
      ),
    );
  }

  Widget _buildUserAvatar() {
    if (data.avatarUrl != null && data.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          data.avatarUrl!,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          errorBuilder: (_, __, ___) => _buildPlaceholderCircle(
            child: Text(
              data.username.isNotEmpty
                  ? data.username[0].toUpperCase()
                  : '?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      );
    }

    return _buildPlaceholderCircle(
      child: Text(
        data.username.isNotEmpty ? data.username[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCircle({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2A2A2A),
      ),
      child: Center(child: child),
    );
  }
}

class _StoryMediaOption extends StatelessWidget {
  const _StoryMediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDark = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFBDC1C6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 44,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}
