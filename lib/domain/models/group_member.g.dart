// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupMember _$GroupMemberFromJson(Map<String, dynamic> json) => _GroupMember(
  userId: json['userId'] as String,
  role: json['role'] as String? ?? 'member',
  username: json['username'] as String?,
  displayName: json['displayName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  joinedAt: json['joinedAt'] == null
      ? null
      : DateTime.parse(json['joinedAt'] as String),
);

Map<String, dynamic> _$GroupMemberToJson(_GroupMember instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'role': instance.role,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'joinedAt': instance.joinedAt?.toIso8601String(),
    };
