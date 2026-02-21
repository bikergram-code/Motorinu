// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Achievement _$AchievementFromJson(Map<String, dynamic> json) => _Achievement(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  iconUrl: json['iconUrl'] as String?,
  xpReward: (json['xpReward'] as num?)?.toInt() ?? 0,
  criteria: json['criteria'] as Map<String, dynamic>?,
  isUnlocked: json['isUnlocked'] as bool? ?? false,
  unlockedAt: json['unlockedAt'] == null
      ? null
      : DateTime.parse(json['unlockedAt'] as String),
  progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$AchievementToJson(_Achievement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'description': instance.description,
      'iconUrl': instance.iconUrl,
      'xpReward': instance.xpReward,
      'criteria': instance.criteria,
      'isUnlocked': instance.isUnlocked,
      'unlockedAt': instance.unlockedAt?.toIso8601String(),
      'progress': instance.progress,
    };

_XpTransaction _$XpTransactionFromJson(Map<String, dynamic> json) =>
    _XpTransaction(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      source: json['source'] as String,
      sourceId: (json['sourceId'] as num?)?.toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$XpTransactionToJson(_XpTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'amount': instance.amount,
      'source': instance.source,
      'sourceId': instance.sourceId,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_XpSummary _$XpSummaryFromJson(Map<String, dynamic> json) => _XpSummary(
  totalXp: (json['totalXp'] as num?)?.toInt() ?? 0,
  currentLevel: (json['currentLevel'] as num?)?.toInt() ?? 1,
  xpForCurrentLevel: (json['xpForCurrentLevel'] as num?)?.toInt() ?? 0,
  xpForNextLevel: (json['xpForNextLevel'] as num?)?.toInt() ?? 100,
  progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
  levelName: json['levelName'] as String?,
);

Map<String, dynamic> _$XpSummaryToJson(_XpSummary instance) =>
    <String, dynamic>{
      'totalXp': instance.totalXp,
      'currentLevel': instance.currentLevel,
      'xpForCurrentLevel': instance.xpForCurrentLevel,
      'xpForNextLevel': instance.xpForNextLevel,
      'progress': instance.progress,
      'levelName': instance.levelName,
    };
