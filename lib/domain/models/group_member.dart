import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_member.freezed.dart';
part 'group_member.g.dart';

@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    @Default('member') String role, // admin, member
    String? username,
    String? displayName,
    String? avatarUrl,
    DateTime? joinedAt,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);

  factory GroupMember.fromSupabase(Map<String, dynamic> data) {
    final profiles = data['profiles'] as Map<String, dynamic>?;
    return GroupMember(
      userId: data['user_id'] as String,
      role: data['role'] as String? ?? 'member',
      username: profiles?['username'] as String?,
      displayName: profiles?['display_name'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
      joinedAt: data['joined_at'] != null
          ? DateTime.tryParse(data['joined_at'] as String)
          : null,
    );
  }
}
