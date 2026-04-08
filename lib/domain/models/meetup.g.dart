// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meetup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Meetup _$MeetupFromJson(Map<String, dynamic> json) => _Meetup(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String?,
  imageUrl: json['imageUrl'] as String?,
  locationText: json['locationText'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  sourceUrl: json['sourceUrl'] as String?,
  sourceName: json['sourceName'] as String?,
  community: json['community'] as String? ?? 'bikergram',
  region: json['region'] as String?,
  isVerified: json['isVerified'] as bool? ?? false,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MeetupToJson(_Meetup instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'imageUrl': instance.imageUrl,
  'locationText': instance.locationText,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt?.toIso8601String(),
  'sourceUrl': instance.sourceUrl,
  'sourceName': instance.sourceName,
  'community': instance.community,
  'region': instance.region,
  'isVerified': instance.isVerified,
  'createdAt': instance.createdAt?.toIso8601String(),
};
