// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BikerGroup _$BikerGroupFromJson(Map<String, dynamic> json) => _BikerGroup(
  id: (json['id'] as num).toInt(),
  creatorId: json['creatorId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  groupType: json['groupType'] as String? ?? 'chat',
  community: json['community'] as String? ?? 'bikergram',
  isRideActive: json['isRideActive'] as bool? ?? false,
  rideColor: json['rideColor'] as String? ?? '#4CAF50',
  isPublic: json['isPublic'] as bool? ?? true,
  memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
  maxMembers: (json['maxMembers'] as num?)?.toInt(),
  creatorName: json['creatorName'] as String?,
  creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
  isMember: json['isMember'] as bool? ?? false,
  isAdmin: json['isAdmin'] as bool? ?? false,
  conversationId: (json['conversationId'] as num?)?.toInt(),
  destinationLat: (json['destinationLat'] as num?)?.toDouble(),
  destinationLng: (json['destinationLng'] as num?)?.toDouble(),
  destinationName: json['destinationName'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BikerGroupToJson(_BikerGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'creatorId': instance.creatorId,
      'name': instance.name,
      'description': instance.description,
      'avatarUrl': instance.avatarUrl,
      'groupType': instance.groupType,
      'community': instance.community,
      'isRideActive': instance.isRideActive,
      'rideColor': instance.rideColor,
      'isPublic': instance.isPublic,
      'memberCount': instance.memberCount,
      'maxMembers': instance.maxMembers,
      'creatorName': instance.creatorName,
      'creatorAvatarUrl': instance.creatorAvatarUrl,
      'isMember': instance.isMember,
      'isAdmin': instance.isAdmin,
      'conversationId': instance.conversationId,
      'destinationLat': instance.destinationLat,
      'destinationLng': instance.destinationLng,
      'destinationName': instance.destinationName,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
