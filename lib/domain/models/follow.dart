import 'package:freezed_annotation/freezed_annotation.dart';

part 'follow.freezed.dart';
part 'follow.g.dart';

@freezed
abstract class FollowRelation with _$FollowRelation {
  const factory FollowRelation({
    required int id,
    required int followerId,
    required int followingId,
    DateTime? createdAt,
  }) = _FollowRelation;

  factory FollowRelation.fromJson(Map<String, dynamic> json) =>
      _$FollowRelationFromJson(json);
}

@freezed
abstract class UserSummary with _$UserSummary {
  const factory UserSummary({
    required int id,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isFollowing,
    @Default(false) bool isFollowedByMe,
  }) = _UserSummary;

  factory UserSummary.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryFromJson(json);
}
