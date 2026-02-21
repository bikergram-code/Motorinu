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
final storyUsersProvider = FutureProvider<StoryBarData>((ref) async {
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
    final picker = ImagePicker();

    // Allow multiple image selection
    final files = await picker.pickMultiImage(imageQuality: 85, limit: 10);
    if (files.isEmpty) return;

    if (!context.mounted) return;

    final count = files.length;
    final label = count == 1 ? 'Story wird hochgeladen...' : '$count Stories werden hochgeladen...';

    // Show uploading indicator
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text(label),
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

        // Upload image to storage
        final ext = file.name.split('.').last;
        final path = 'stories/$userId/${DateTime.now().millisecondsSinceEpoch}_$uploaded.$ext';

        await supabase.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final imageUrl = supabase.storage.from('posts').getPublicUrl(path);

        // Save story to stories table (each image = one story entry)
        await supabase.from('stories').insert({
          'user_id': userId,
          'media_url': imageUrl,
          'media_type': 'image',
        });

        uploaded++;
      }

      // Refresh story bar so new stories show immediately
      ref.invalidate(storyUsersProvider);

      if (!context.mounted) return;
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
                gradient: data.hasUnread
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.6),
                        ],
                      )
                    : data.isOwn
                        ? LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: data.isOwn ? _buildOwnAvatar() : _buildUserAvatar(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.username,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight:
                    data.hasUnread ? FontWeight.w600 : FontWeight.w400,
                color: Colors.white
                    .withValues(alpha: data.hasUnread ? 0.9 : 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
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
