import 'package:freezed_annotation/freezed_annotation.dart';

part 'story.freezed.dart';
part 'story.g.dart';

@freezed
abstract class Story with _$Story {
  const factory Story({
    required int id,
    required int userId,
    required String mediaUrl,
    @Default('image') String mediaType,
    String? caption,
    String? username,
    String? avatarUrl,
    @Default(0) int viewCount,
    required DateTime expiresAt,
    DateTime? createdAt,
  }) = _Story;

  factory Story.fromJson(Map<String, dynamic> json) => _$StoryFromJson(json);
}
