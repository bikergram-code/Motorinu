// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Story _$StoryFromJson(Map<String, dynamic> json) => _Story(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  mediaUrl: json['mediaUrl'] as String,
  mediaType: json['mediaType'] as String? ?? 'image',
  caption: json['caption'] as String?,
  username: json['username'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$StoryToJson(_Story instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mediaUrl': instance.mediaUrl,
  'mediaType': instance.mediaType,
  'caption': instance.caption,
  'username': instance.username,
  'avatarUrl': instance.avatarUrl,
  'viewCount': instance.viewCount,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
};
