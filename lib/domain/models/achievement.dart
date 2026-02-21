import 'package:freezed_annotation/freezed_annotation.dart';

part 'achievement.freezed.dart';
part 'achievement.g.dart';

@freezed
abstract class Achievement with _$Achievement {
  const factory Achievement({
    required int id,
    required String slug,
    required String name,
    String? description,
    String? iconUrl,
    @Default(0) int xpReward,
    Map<String, dynamic>? criteria,
    @Default(false) bool isUnlocked,
    DateTime? unlockedAt,
    @Default(0.0) double progress,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
}

@freezed
abstract class XpTransaction with _$XpTransaction {
  const factory XpTransaction({
    required int id,
    required int userId,
    required int amount,
    required String source,
    int? sourceId,
    DateTime? createdAt,
  }) = _XpTransaction;

  factory XpTransaction.fromJson(Map<String, dynamic> json) =>
      _$XpTransactionFromJson(json);
}

@freezed
abstract class XpSummary with _$XpSummary {
  const factory XpSummary({
    @Default(0) int totalXp,
    @Default(1) int currentLevel,
    @Default(0) int xpForCurrentLevel,
    @Default(100) int xpForNextLevel,
    @Default(0.0) double progress,
    String? levelName,
  }) = _XpSummary;

  factory XpSummary.fromJson(Map<String, dynamic> json) =>
      _$XpSummaryFromJson(json);
}
