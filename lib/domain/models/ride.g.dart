// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Ride _$RideFromJson(Map<String, dynamic> json) => _Ride(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  motorcycleId: (json['motorcycleId'] as num?)?.toInt(),
  startedAt: DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
  durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
  avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
  maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
  xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
  isLiveGo: json['isLiveGo'] as bool? ?? false,
  points:
      (json['points'] as List<dynamic>?)
          ?.map((e) => RidePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$RideToJson(_Ride instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'motorcycleId': instance.motorcycleId,
  'startedAt': instance.startedAt.toIso8601String(),
  'endedAt': instance.endedAt?.toIso8601String(),
  'distanceKm': instance.distanceKm,
  'durationSeconds': instance.durationSeconds,
  'avgSpeedKmh': instance.avgSpeedKmh,
  'maxSpeedKmh': instance.maxSpeedKmh,
  'xpEarned': instance.xpEarned,
  'isLiveGo': instance.isLiveGo,
  'points': instance.points,
  'createdAt': instance.createdAt?.toIso8601String(),
};

_RidePoint _$RidePointFromJson(Map<String, dynamic> json) => _RidePoint(
  id: (json['id'] as num).toInt(),
  rideId: (json['rideId'] as num).toInt(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  altitude: (json['altitude'] as num?)?.toDouble(),
  speed: (json['speed'] as num?)?.toDouble(),
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$RidePointToJson(_RidePoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rideId': instance.rideId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'altitude': instance.altitude,
      'speed': instance.speed,
      'timestamp': instance.timestamp.toIso8601String(),
    };
