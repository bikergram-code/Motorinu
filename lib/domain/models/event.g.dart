// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BikerEvent _$BikerEventFromJson(Map<String, dynamic> json) => _BikerEvent(
  id: (json['id'] as num).toInt(),
  userId: json['userId'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  imageUrl: json['imageUrl'] as String?,
  location: json['location'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
  participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
  isFeatured: json['isFeatured'] as bool? ?? false,
  category: json['category'] as String? ?? 'meetup',
  community: json['community'] as String? ?? 'bikergram',
  creatorName: json['creatorName'] as String?,
  creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
  myStatus: json['myStatus'] as String?,
  ticketUrl: json['ticketUrl'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BikerEventToJson(_BikerEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'location': instance.location,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'startsAt': instance.startsAt.toIso8601String(),
      'endsAt': instance.endsAt?.toIso8601String(),
      'maxParticipants': instance.maxParticipants,
      'participantCount': instance.participantCount,
      'isFeatured': instance.isFeatured,
      'category': instance.category,
      'community': instance.community,
      'creatorName': instance.creatorName,
      'creatorAvatarUrl': instance.creatorAvatarUrl,
      'myStatus': instance.myStatus,
      'ticketUrl': instance.ticketUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
