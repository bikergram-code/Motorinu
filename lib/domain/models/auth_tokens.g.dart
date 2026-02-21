// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthTokenPair _$AuthTokenPairFromJson(Map<String, dynamic> json) =>
    _AuthTokenPair(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessExpiresAt: json['accessExpiresAt'] == null
          ? null
          : DateTime.parse(json['accessExpiresAt'] as String),
      refreshExpiresAt: json['refreshExpiresAt'] == null
          ? null
          : DateTime.parse(json['refreshExpiresAt'] as String),
    );

Map<String, dynamic> _$AuthTokenPairToJson(_AuthTokenPair instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'accessExpiresAt': instance.accessExpiresAt?.toIso8601String(),
      'refreshExpiresAt': instance.refreshExpiresAt?.toIso8601String(),
    };
