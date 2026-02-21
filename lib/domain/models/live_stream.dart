import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_stream.freezed.dart';
part 'live_stream.g.dart';

/// A live stream session (broadcast).
@freezed
abstract class LiveStream with _$LiveStream {
  const factory LiveStream({
    required String id,
    required String hostUserId,
    required String title,
    @Default('preparing') String status, // preparing, live, ended
    int? topicId,
    String? ivsChannelArn,
    String? ivsIngestEndpoint,
    String? ivsStreamKey,
    String? playbackUrl,
    String? thumbnailUrl,
    @Default(0) int viewerCount,
    @Default(0) int peakViewerCount,
    @Default(0) int totalUniqueViewers,
    @Default(0) int totalChatMessages,
    @Default('bikergram') String community,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    // Host profile info (denormalized for display)
    String? hostUsername,
    String? hostDisplayName,
    String? hostAvatarUrl,
  }) = _LiveStream;

  factory LiveStream.fromJson(Map<String, dynamic> json) =>
      _$LiveStreamFromJson(json);

  /// Create from Supabase row with joined profiles.
  factory LiveStream.fromSupabase(Map<String, dynamic> data) {
    final profiles = data['profiles'] as Map<String, dynamic>?;
    return LiveStream(
      id: data['id'] as String,
      hostUserId: data['host_user_id'] as String,
      title: data['title'] as String? ?? 'Live',
      status: data['status'] as String? ?? 'preparing',
      topicId: data['topic_id'] as int?,
      ivsChannelArn: data['ivs_channel_arn'] as String?,
      ivsIngestEndpoint: data['ivs_ingest_endpoint'] as String?,
      ivsStreamKey: data['ivs_stream_key'] as String?,
      playbackUrl: data['playback_url'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
      viewerCount: (data['viewer_count'] as num?)?.toInt() ?? 0,
      peakViewerCount: (data['peak_viewer_count'] as num?)?.toInt() ?? 0,
      totalUniqueViewers: (data['total_unique_viewers'] as num?)?.toInt() ?? 0,
      totalChatMessages: (data['total_chat_messages'] as num?)?.toInt() ?? 0,
      community: data['community'] as String? ?? 'bikergram',
      startedAt: data['started_at'] != null
          ? DateTime.tryParse(data['started_at'] as String)
          : null,
      endedAt: data['ended_at'] != null
          ? DateTime.tryParse(data['ended_at'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      hostUsername: profiles?['username'] as String?,
      hostDisplayName: profiles?['display_name'] as String?,
      hostAvatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}

/// A single chat message in a live stream.
@freezed
abstract class LiveChatMessage with _$LiveChatMessage {
  const factory LiveChatMessage({
    required int id,
    required String liveSessionId,
    required String userId,
    required String message,
    @Default('visible') String moderationState,
    DateTime? createdAt,
    // Sender info (denormalized)
    String? username,
    String? displayName,
    String? avatarUrl,
  }) = _LiveChatMessage;

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) =>
      _$LiveChatMessageFromJson(json);

  factory LiveChatMessage.fromSupabase(Map<String, dynamic> data) {
    final profiles = data['profiles'] as Map<String, dynamic>?;
    return LiveChatMessage(
      id: (data['id'] as num).toInt(),
      liveSessionId: data['live_session_id'] as String,
      userId: data['user_id'] as String,
      message: data['message'] as String,
      moderationState: data['moderation_state'] as String? ?? 'visible',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      username: profiles?['username'] as String?,
      displayName: profiles?['display_name'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}
