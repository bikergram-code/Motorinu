// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FollowRelation _$FollowRelationFromJson(Map<String, dynamic> json) =>
    _FollowRelation(
      id: (json['id'] as num).toInt(),
      followerId: (json['followerId'] as num).toInt(),
      followingId: (json['followingId'] as num).toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$FollowRelationToJson(_FollowRelation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'followerId': instance.followerId,
      'followingId': instance.followingId,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_UserSummary _$UserSummaryFromJson(Map<String, dynamic> json) => _UserSummary(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  displayName: json['displayName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  isFollowing: json['isFollowing'] as bool? ?? false,
  isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
);

Map<String, dynamic> _$UserSummaryToJson(_UserSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'isFollowing': instance.isFollowing,
      'isFollowedByMe': instance.isFollowedByMe,
    };
