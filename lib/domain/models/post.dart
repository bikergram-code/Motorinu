import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    /// Supabase uses bigint auto-increment for posts
    required int id,
    /// Supabase user UUID
    required String userId,
    required String username,
    String? displayName,
    String? avatarUrl,
    String? body,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    @Default([]) List<String> attachmentUrls,
    String? community,
    /// Media type: image, video, carousel, text
    @Default('image') String mediaType,
    double? aspectRatio,
    int? durationSeconds,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(0) int viewCount,
    @Default(0) int repostCount,
    @Default(0) int saveCount,
    @Default(false) bool likedByMe,
    /// Reaction type if user reacted ('fire', 'love', etc.) — null = regular like
    String? myReaction,
    @Default(false) bool savedByMe,
    @Default(false) bool isMine,
    @Default(false) bool isPromoted,
    int? promotionId,
    /// Visibility: 'public', 'followers', 'private'
    @Default('public') String visibility,
    /// Topic IDs attached to this post (≤3)
    @Default([]) List<int> topicIds,
    DateTime? createdAt,
    DateTime? editedAt,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  /// Parse a post from Supabase response (with joined profile).
  factory Post.fromSupabase(Map<String, dynamic> json, {String? currentUserId}) {
    // Supabase join: posts with profiles
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userId = json['user_id'] ?? '';

    // Determine media type: from DB column or inferred from URLs
    String mediaType = json['media_type'] as String? ?? 'image';
    if (mediaType == 'image') {
      // Backward compat: infer from existing columns
      if (json['video_url'] != null && (json['video_url'] as String).isNotEmpty) {
        mediaType = 'video';
      } else if ((json['image_url'] == null || (json['image_url'] as String).isEmpty) &&
                 (json['video_url'] == null || (json['video_url'] as String).isEmpty)) {
        mediaType = 'text';
      }
    }

    // Parse topic IDs from joined post_topics if available
    final topicIds = <int>[];
    final rawTopics = json['post_topics'];
    if (rawTopics is List) {
      for (final t in rawTopics) {
        if (t is Map && t['topic_id'] != null) {
          final id = t['topic_id'];
          topicIds.add(id is int ? id : int.tryParse('$id') ?? 0);
        }
      }
    }

    return Post(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      userId: '$userId',
      username: profile?['username'] ?? json['username'] ?? '',
      displayName: profile?['display_name'] ?? json['display_name'],
      avatarUrl: profile?['avatar_url'] ?? json['avatar_url'],
      body: json['body'] ?? json['caption'],
      imageUrl: json['image_url'] ?? json['imageUrl'],
      videoUrl: json['video_url'] ?? json['videoUrl'],
      thumbnailUrl: json['thumbnail_url'] as String?,
      attachmentUrls: _toStringList(json['attachment_urls'] ?? json['attachmentUrls']),
      community: json['community'],
      mediaType: mediaType,
      aspectRatio: _toDouble(json['aspect_ratio']),
      durationSeconds: json['duration_seconds'] as int?,
      likeCount: _toInt(json['like_count'] ?? json['likeCount']),
      commentCount: _toInt(json['comment_count'] ?? json['commentCount']),
      viewCount: _toInt(json['view_count'] ?? json['viewCount']),
      repostCount: _toInt(json['repost_count'] ?? json['repostCount']),
      saveCount: _toInt(json['save_count'] ?? json['saveCount']),
      likedByMe: _toBool(json['liked_by_me']),
      savedByMe: _toBool(json['saved_by_me']),
      isMine: currentUserId != null && '$userId' == currentUserId,
      isPromoted: _toBool(json['is_promoted']),
      visibility: json['visibility'] as String? ?? 'public',
      topicIds: topicIds,
      createdAt: _tryParseDate(json['created_at']),
      editedAt: _tryParseDate(json['updated_at'] ?? json['edited_at']),
    );
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse('$v');
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return false;
}

List<String> _toStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => '$e').toList();
  return [];
}

DateTime? _tryParseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v');
}
