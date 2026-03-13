// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: (json['id'] as num).toInt(),
  userId: json['userId'] as String,
  username: json['username'] as String,
  displayName: json['displayName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  body: json['body'] as String?,
  imageUrl: json['imageUrl'] as String?,
  videoUrl: json['videoUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  attachmentUrls:
      (json['attachmentUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  community: json['community'] as String?,
  mediaType: json['mediaType'] as String? ?? 'image',
  aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
  durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
  saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
  likedByMe: json['likedByMe'] as bool? ?? false,
  myReaction: json['myReaction'] as String?,
  savedByMe: json['savedByMe'] as bool? ?? false,
  isMine: json['isMine'] as bool? ?? false,
  isPromoted: json['isPromoted'] as bool? ?? false,
  promotionId: (json['promotionId'] as num?)?.toInt(),
  visibility: json['visibility'] as String? ?? 'public',
  topicIds:
      (json['topicIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  editedAt: json['editedAt'] == null
      ? null
      : DateTime.parse(json['editedAt'] as String),
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'displayName': instance.displayName,
  'avatarUrl': instance.avatarUrl,
  'body': instance.body,
  'imageUrl': instance.imageUrl,
  'videoUrl': instance.videoUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'attachmentUrls': instance.attachmentUrls,
  'community': instance.community,
  'mediaType': instance.mediaType,
  'aspectRatio': instance.aspectRatio,
  'durationSeconds': instance.durationSeconds,
  'likeCount': instance.likeCount,
  'commentCount': instance.commentCount,
  'viewCount': instance.viewCount,
  'repostCount': instance.repostCount,
  'saveCount': instance.saveCount,
  'likedByMe': instance.likedByMe,
  'myReaction': instance.myReaction,
  'savedByMe': instance.savedByMe,
  'isMine': instance.isMine,
  'isPromoted': instance.isPromoted,
  'promotionId': instance.promotionId,
  'visibility': instance.visibility,
  'topicIds': instance.topicIds,
  'createdAt': instance.createdAt?.toIso8601String(),
  'editedAt': instance.editedAt?.toIso8601String(),
};
