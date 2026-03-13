import 'package:freezed_annotation/freezed_annotation.dart';

part 'direct_message.freezed.dart';
part 'direct_message.g.dart';

@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required int id,
    required String otherUserId,
    String? otherUsername,
    String? otherAvatarUrl,
    String? lastMessageBody,
    DateTime? lastMessageAt,
    @Default(0) int unreadCount,
    DateTime? createdAt,
    // Group chat fields
    @Default(false) bool isGroupChat,
    int? groupId,
    String? groupName,
    String? groupAvatarUrl,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

@freezed
abstract class DirectMessage with _$DirectMessage {
  const factory DirectMessage({
    required int id,
    required int conversationId,
    required String senderId,
    required String body,
    String? imageUrl,
    String? audioUrl,
    int? audioDurationMs,
    double? locationLat,
    double? locationLng,
    String? locationName,
    int? replyToId,
    @Default('text') String messageType, // text, image, audio, location
    @Default(false) bool isRead,
    DateTime? createdAt,
    // Group chat enrichment
    String? senderName,
    String? senderAvatar,
  }) = _DirectMessage;

  factory DirectMessage.fromJson(Map<String, dynamic> json) =>
      _$DirectMessageFromJson(json);
}
