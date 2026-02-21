// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_stream.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveStream _$LiveStreamFromJson(Map<String, dynamic> json) => _LiveStream(
  id: json['id'] as String,
  hostUserId: json['hostUserId'] as String,
  title: json['title'] as String,
  status: json['status'] as String? ?? 'preparing',
  topicId: (json['topicId'] as num?)?.toInt(),
  ivsChannelArn: json['ivsChannelArn'] as String?,
  ivsIngestEndpoint: json['ivsIngestEndpoint'] as String?,
  ivsStreamKey: json['ivsStreamKey'] as String?,
  playbackUrl: json['playbackUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
  peakViewerCount: (json['peakViewerCount'] as num?)?.toInt() ?? 0,
  totalUniqueViewers: (json['totalUniqueViewers'] as num?)?.toInt() ?? 0,
  totalChatMessages: (json['totalChatMessages'] as num?)?.toInt() ?? 0,
  community: json['community'] as String? ?? 'bikergram',
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  hostUsername: json['hostUsername'] as String?,
  hostDisplayName: json['hostDisplayName'] as String?,
  hostAvatarUrl: json['hostAvatarUrl'] as String?,
);

Map<String, dynamic> _$LiveStreamToJson(_LiveStream instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hostUserId': instance.hostUserId,
      'title': instance.title,
      'status': instance.status,
      'topicId': instance.topicId,
      'ivsChannelArn': instance.ivsChannelArn,
      'ivsIngestEndpoint': instance.ivsIngestEndpoint,
      'ivsStreamKey': instance.ivsStreamKey,
      'playbackUrl': instance.playbackUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'viewerCount': instance.viewerCount,
      'peakViewerCount': instance.peakViewerCount,
      'totalUniqueViewers': instance.totalUniqueViewers,
      'totalChatMessages': instance.totalChatMessages,
      'community': instance.community,
      'startedAt': instance.startedAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'hostUsername': instance.hostUsername,
      'hostDisplayName': instance.hostDisplayName,
      'hostAvatarUrl': instance.hostAvatarUrl,
    };

_LiveChatMessage _$LiveChatMessageFromJson(Map<String, dynamic> json) =>
    _LiveChatMessage(
      id: (json['id'] as num).toInt(),
      liveSessionId: json['liveSessionId'] as String,
      userId: json['userId'] as String,
      message: json['message'] as String,
      moderationState: json['moderationState'] as String? ?? 'visible',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$LiveChatMessageToJson(_LiveChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'liveSessionId': instance.liveSessionId,
      'userId': instance.userId,
      'message': instance.message,
      'moderationState': instance.moderationState,
      'createdAt': instance.createdAt?.toIso8601String(),
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
    };
