// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveSession _$LiveSessionFromJson(Map<String, dynamic> json) => _LiveSession(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  rideId: (json['rideId'] as num?)?.toInt(),
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  speed: (json['speed'] as num?)?.toDouble(),
  heading: (json['heading'] as num?)?.toDouble(),
  isActive: json['isActive'] as bool? ?? true,
  username: json['username'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  bikeName: json['bikeName'] as String?,
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
);

Map<String, dynamic> _$LiveSessionToJson(_LiveSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'rideId': instance.rideId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'speed': instance.speed,
      'heading': instance.heading,
      'isActive': instance.isActive,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'bikeName': instance.bikeName,
      'startedAt': instance.startedAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
    };
