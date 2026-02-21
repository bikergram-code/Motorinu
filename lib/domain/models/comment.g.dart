// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  postId: (json['postId'] as num).toInt(),
  body: json['body'] as String,
  username: json['username'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  parentId: (json['parentId'] as num?)?.toInt(),
  replies:
      (json['replies'] as List<dynamic>?)
          ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'postId': instance.postId,
  'body': instance.body,
  'username': instance.username,
  'avatarUrl': instance.avatarUrl,
  'parentId': instance.parentId,
  'replies': instance.replies,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
