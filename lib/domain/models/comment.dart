import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required int id,
    required int userId,
    required int postId,
    required String body,
    String? username,
    String? avatarUrl,
    int? parentId,
    @Default([]) List<Comment> replies,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);
}
