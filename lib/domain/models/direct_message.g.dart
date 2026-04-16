// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: (json['id'] as num).toInt(),
      otherUserId: json['otherUserId'] as String,
      otherUsername: json['otherUsername'] as String?,
      otherAvatarUrl: json['otherAvatarUrl'] as String?,
      lastMessageBody: json['lastMessageBody'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      isGroupChat: json['isGroupChat'] as bool? ?? false,
      groupId: (json['groupId'] as num?)?.toInt(),
      groupName: json['groupName'] as String?,
      groupAvatarUrl: json['groupAvatarUrl'] as String?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'otherUserId': instance.otherUserId,
      'otherUsername': instance.otherUsername,
      'otherAvatarUrl': instance.otherAvatarUrl,
      'lastMessageBody': instance.lastMessageBody,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'createdAt': instance.createdAt?.toIso8601String(),
      'isGroupChat': instance.isGroupChat,
      'groupId': instance.groupId,
      'groupName': instance.groupName,
      'groupAvatarUrl': instance.groupAvatarUrl,
      'archivedAt': instance.archivedAt?.toIso8601String(),
      'deletedAt': instance.deletedAt?.toIso8601String(),
    };

_DirectMessage _$DirectMessageFromJson(Map<String, dynamic> json) =>
    _DirectMessage(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversationId'] as num).toInt(),
      senderId: json['senderId'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioDurationMs: (json['audioDurationMs'] as num?)?.toInt(),
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      replyToId: (json['replyToId'] as num?)?.toInt(),
      messageType: json['messageType'] as String? ?? 'text',
      isDelivered: json['isDelivered'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
    );

Map<String, dynamic> _$DirectMessageToJson(_DirectMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'senderId': instance.senderId,
      'body': instance.body,
      'imageUrl': instance.imageUrl,
      'audioUrl': instance.audioUrl,
      'audioDurationMs': instance.audioDurationMs,
      'locationLat': instance.locationLat,
      'locationLng': instance.locationLng,
      'locationName': instance.locationName,
      'replyToId': instance.replyToId,
      'messageType': instance.messageType,
      'isDelivered': instance.isDelivered,
      'isRead': instance.isRead,
      'createdAt': instance.createdAt?.toIso8601String(),
      'editedAt': instance.editedAt?.toIso8601String(),
      'senderName': instance.senderName,
      'senderAvatar': instance.senderAvatar,
    };
