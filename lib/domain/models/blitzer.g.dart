// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blitzer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BlitzerReport _$BlitzerReportFromJson(Map<String, dynamic> json) =>
    _BlitzerReport(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      type: json['type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedLimit: (json['speedLimit'] as num?)?.toInt(),
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      reporterName: json['reporterName'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$BlitzerReportToJson(_BlitzerReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': instance.type,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'speedLimit': instance.speedLimit,
      'description': instance.description,
      'isActive': instance.isActive,
      'confirmations': instance.confirmations,
      'reporterName': instance.reporterName,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
