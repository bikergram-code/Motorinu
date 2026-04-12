import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/direct_message.dart';
import '../../data/repositories/message_repository.dart';
import '../core/providers.dart';
import 'unread_messages_notifier.dart';

/// Max messages kept in memory per chat to prevent unbounded growth.
const _kMaxMessages = 200;

List<DirectMessage> _trimMessages(List<DirectMessage> msgs) =>
    msgs.length > _kMaxMessages ? msgs.sublist(msgs.length - _kMaxMessages) : msgs;

/// State for a single chat conversation.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.otherUsername,
    this.otherAvatarUrl,
    this.otherUserId,
    this.replyTo,
    this.isOtherTyping = false,
    this.error,
    this.isGroupChat = false,
    this.groupName,
    this.groupId,
  });

  final List<DirectMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? otherUsername;
  final String? otherAvatarUrl;
  final String? otherUserId;
  final DirectMessage? replyTo;
  final bool isOtherTyping;
  final String? error;
  final bool isGroupChat;
  final String? groupName;
  final int? groupId;

  ChatState copyWith({
    List<DirectMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? otherUsername,
    String? otherAvatarUrl,
    String? otherUserId,
    DirectMessage? replyTo,
    bool clearReplyTo = false,
    bool? isOtherTyping,
    String? error,
    bool? isGroupChat,
    String? groupName,
    int? groupId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      otherUsername: otherUsername ?? this.otherUsername,
      otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
      otherUserId: otherUserId ?? this.otherUserId,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      isOtherTyping: isOtherTyping ?? this.isOtherTyping,
      error: error,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      groupName: groupName ?? this.groupName,
      groupId: groupId ?? this.groupId,
    );
  }
}

/// Chat provider family for Riverpod 3.x.
final chatNotifierProvider =
    NotifierProvider.family<ChatNotifier, ChatState, int>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  ChatNotifier(this._conversationId);

  final int _conversationId;
  late MessageRepository _repo;
  RealtimeChannel? _channel;
  bool _isCurrentlyTyping = false;

  @override
  ChatState build() {
    _repo = ref.watch(messageRepositoryProvider);

    ref.onDispose(() {
      _channel?.unsubscribe();
      // Reset typing on dispose
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          Supabase.instance.client
              .from('conversation_participants')
              .update({'is_typing': false})
              .eq('conversation_id', _conversationId)
              .eq('user_id', uid)
              .then((_) {})
              .catchError((_) {});
        }
      }
    });

    // Delay async work until after build() has returned and state is
    // initialised. Without this, _loadChat() tries to read/write
    // `state` before it exists → "Tried to read the state of an
    // uninitialized provider".
    Future.microtask(() => _loadChat(_conversationId));

    return const ChatState(isLoading: true);
  }

  /// Sender profile cache for group chats.
  final Map<String, Map<String, String?>> _senderCache = {};

  Future<void> _loadChat(int conversationId) async {
    try {
      // Check if this is a group conversation
      bool isGroupChat = false;
      String? groupName;
      int? groupId;
      try {
        final conv = await Supabase.instance.client
            .from('conversations')
            .select('group_id')
            .eq('id', conversationId)
            .maybeSingle();
        if (conv != null && conv['group_id'] != null) {
          isGroupChat = true;
          groupId = (conv['group_id'] as num).toInt();
          final groupData = await Supabase.instance.client
              .from('groups')
              .select('name')
              .eq('id', groupId)
              .maybeSingle();
          groupName = groupData?['name'] as String?;
        }
      } catch (e) {
        debugPrint('[ChatNotifier] Group check error: $e');
      }

      final otherUser = isGroupChat
          ? null
          : await _repo.getOtherParticipant(conversationId);

      final data = await _repo.getMessages(conversationId);

      // For group chats, enrich messages with sender info
      List<DirectMessage> messages;
      if (isGroupChat) {
        messages = await _enrichGroupMessages(data);
      } else {
        messages = data.map((row) => _parseMessage(row)).toList();
      }

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        isGroupChat: isGroupChat,
        groupName: groupName,
        groupId: groupId,
        otherUsername: isGroupChat
            ? groupName
            : (otherUser?['display_name'] as String? ??
                otherUser?['username'] as String? ??
                'Unbekannt'),
        otherAvatarUrl: isGroupChat ? null : otherUser?['avatar_url'] as String?,
        otherUserId: isGroupChat ? null : otherUser?['id'] as String?,
      );

      await _repo.markAsRead(conversationId);
      ref.read(unreadMessagesProvider.notifier).refresh();

      _subscribeToMessages(conversationId);
    } catch (e) {
      debugPrint('Error loading chat: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<DirectMessage>> _enrichGroupMessages(
      List<dynamic> data) async {
    final messages = <DirectMessage>[];
    for (final row in data) {
      final msg = _parseMessage(row as Map<String, dynamic>);
      final sender = await _getSenderInfo(msg.senderId);
      messages.add(msg.copyWith(
        senderName: sender['display_name'] ?? sender['username'],
        senderAvatar: sender['avatar_url'],
      ));
    }
    return messages;
  }

  Future<Map<String, String?>> _getSenderInfo(String userId) async {
    if (_senderCache.containsKey(userId)) return _senderCache[userId]!;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final info = <String, String?>{
        'username': profile?['username'] as String?,
        'display_name': profile?['display_name'] as String?,
        'avatar_url': profile?['avatar_url'] as String?,
      };
      _senderCache[userId] = info;
      return info;
    } catch (_) {
      return {'username': null, 'display_name': null, 'avatar_url': null};
    }
  }

  void _subscribeToMessages(int conversationId) {
    _channel?.unsubscribe();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[Chat] Subscribing to realtime for conv=$conversationId');
    _channel = _repo.subscribeToMessages(conversationId, (newRecord) async {
      debugPrint('[Chat] RT INSERT conv=$conversationId type=${newRecord['message_type']} id=${newRecord['id']} bodyLen=${(newRecord['body'] as String?)?.length ?? 0}');
      var message = _parseMessage(newRecord);

      // Enrich with sender info for group chats
      if (state.isGroupChat) {
        final sender = await _getSenderInfo(message.senderId);
        message = message.copyWith(
          senderName: sender['display_name'] ?? sender['username'],
          senderAvatar: sender['avatar_url'],
        );
      }

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        // New message from other user → they stopped typing
        final clearTyping = message.senderId != currentUserId && state.isOtherTyping;
        state = state.copyWith(
          messages: _trimMessages([...state.messages, message]),
          isOtherTyping: clearTyping ? false : null,
        );
      }

      // Only mark as read if user is actually viewing this chat
      if (message.senderId != currentUserId && state.isLoading == false && state.messages.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _repo.markAsRead(conversationId);
          ref.read(unreadMessagesProvider.notifier).refresh();
        });
      }
    }, onUpdate: (updatedRecord) {
      final updated = _parseMessage(updatedRecord);
      final msgs = state.messages.map((m) {
        if (m.id == updated.id) return updated.copyWith(senderName: m.senderName, senderAvatar: m.senderAvatar);
        return m;
      }).toList();
      state = state.copyWith(messages: msgs);
    }, onDelete: (oldRecord) {
      final deletedId = oldRecord['id'];
      if (deletedId == null) return;
      final id = deletedId is int ? deletedId : int.tryParse('$deletedId');
      if (id == null) return;
      final msgs = List<DirectMessage>.from(state.messages);
      msgs.removeWhere((m) => m.id == id);
      state = state.copyWith(messages: msgs);
    }, onTyping: (record) {
      final typingUserId = record['user_id']?.toString();
      if (typingUserId == null || typingUserId == currentUserId) return;
      final isTyping = record['is_typing'] == true;
      debugPrint('[Chat] Typing DB change: user=$typingUserId, typing=$isTyping');
      if (state.isOtherTyping != isTyping) {
        state = state.copyWith(isOtherTyping: isTyping);
      }
    });
  }

  /// Re-subscribe and re-fetch messages — call on app resume to recover
  /// from dropped Realtime connections (Samsung Battery-Manager etc.).
  Future<void> reconnect() async {
    debugPrint('[Chat] reconnect() conv=$_conversationId');
    try {
      final data = await _repo.getMessages(_conversationId);
      List<DirectMessage> messages;
      if (state.isGroupChat) {
        messages = await _enrichGroupMessages(data);
      } else {
        messages = data.map((row) => _parseMessage(row)).toList();
      }
      state = state.copyWith(messages: messages);
      await _repo.markAsRead(_conversationId);
      ref.read(unreadMessagesProvider.notifier).refresh();
    } catch (e) {
      debugPrint('[Chat] reconnect refetch error: $e');
    }
    _subscribeToMessages(_conversationId);
  }

  /// Notify that the current user is typing (DB-based).
  void setTyping(bool isTyping) {
    if (_isCurrentlyTyping == isTyping) return;
    _isCurrentlyTyping = isTyping;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    debugPrint('[Chat] setTyping($isTyping) for conv=$_conversationId (DB)');
    Supabase.instance.client
        .from('conversation_participants')
        .update({'is_typing': isTyping, 'typing_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', _conversationId)
        .eq('user_id', currentUserId)
        .then((_) => debugPrint('[Chat] Typing DB update OK'))
        .catchError((e) => debugPrint('[Chat] Typing DB update error: $e'));
  }

  // ── Reply-to ──

  void setReplyTo(DirectMessage message) {
    state = state.copyWith(replyTo: message);
  }

  void clearReplyTo() {
    state = state.copyWith(clearReplyTo: true);
  }

  // ── Delete message ──

  Future<void> deleteMessage(int messageId) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    debugPrint('[Chat] deleteMessage($messageId) uid=$uid');
    if (uid == null) return;
    try {
      final result = await sb.from('messages')
          .delete()
          .eq('id', messageId)
          .eq('user_id', uid)
          .select();
      debugPrint('[Chat] deleteMessage result: $result');
      // Remove from local state
      final msgs = List<DirectMessage>.from(state.messages);
      msgs.removeWhere((m) => m.id == messageId);
      state = state.copyWith(messages: msgs);
    } catch (e) {
      debugPrint('[Chat] Delete error: $e');
    }
  }

  // ── Send methods ──

  Future<void> sendMessage(String body) async {
    if (body.trim().isEmpty) return;

    state = state.copyWith(isSending: true);

    try {
      final data = await _repo.sendMessage(
        _conversationId,
        body,
        replyToId: state.replyTo?.id,
        messageType: 'text',
      );
      final message = _parseMessage(data);

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = state.copyWith(
          messages: _trimMessages([...state.messages, message]),
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }

      // Push notification handled by DB trigger → push-v2 Edge Function
    } catch (e) {
      debugPrint('Error sending message: $e');
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> sendImageMessage(XFile image, {String? caption}) async {
    state = state.copyWith(isSending: true);

    try {
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();

      // Upload to Supabase Storage
      final imageUrl =
          await _repo.uploadMessageImage(_conversationId, bytes, ext);

      // Send message with image
      final data = await _repo.sendMessage(
        _conversationId,
        caption ?? '',
        imageUrl: imageUrl,
        replyToId: state.replyTo?.id,
        messageType: 'image',
      );
      final message = _parseMessage(data);

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = state.copyWith(
          messages: _trimMessages([...state.messages, message]),
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }

      // Push notification handled by DB trigger → push-v2 Edge Function
    } catch (e) {
      debugPrint('Error sending image: $e');
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> sendAudioMessage(
      String filePath, int durationMs) async {
    state = state.copyWith(isSending: true);

    try {
      final audioUrl =
          await _repo.uploadMessageAudio(_conversationId, filePath);

      final data = await _repo.sendMessage(
        _conversationId,
        '',
        audioUrl: audioUrl,
        audioDurationMs: durationMs,
        replyToId: state.replyTo?.id,
        messageType: 'audio',
      );
      final message = _parseMessage(data);

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = state.copyWith(
          messages: _trimMessages([...state.messages, message]),
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }
    } catch (e) {
      debugPrint('Error sending audio: $e');
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> sendLocationMessage(
    double lat,
    double lng,
    String name,
  ) async {
    state = state.copyWith(isSending: true);

    try {
      final data = await _repo.sendMessage(
        _conversationId,
        name,
        locationLat: lat,
        locationLng: lng,
        locationName: name,
        replyToId: state.replyTo?.id,
        messageType: 'location',
      );
      final message = _parseMessage(data);

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = state.copyWith(
          messages: _trimMessages([...state.messages, message]),
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }
    } catch (e) {
      debugPrint('Error sending location: $e');
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  /// Find a message by ID (for reply-to display).
  DirectMessage? findMessageById(int id) {
    try {
      return state.messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  DirectMessage _parseMessage(Map<String, dynamic> row) {
    return DirectMessage(
      id: row['id'] is int
          ? row['id'] as int
          : int.parse(row['id'].toString()),
      conversationId: row['conversation_id'] is int
          ? row['conversation_id'] as int
          : int.parse(row['conversation_id'].toString()),
      senderId: row['user_id']?.toString() ?? '',
      body: row['body'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      audioUrl: row['audio_url'] as String?,
      audioDurationMs: row['audio_duration_ms'] as int?,
      locationLat: row['location_lat'] != null
          ? double.tryParse(row['location_lat'].toString())
          : null,
      locationLng: row['location_lng'] != null
          ? double.tryParse(row['location_lng'].toString())
          : null,
      locationName: row['location_name'] as String?,
      replyToId: row['reply_to_id'] as int?,
      messageType: row['message_type'] as String? ?? 'text',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      editedAt: row['edited_at'] != null
          ? DateTime.tryParse(row['edited_at'].toString())
          : null,
    );
  }

  // ── Edit message ──

  Future<void> editMessage(int messageId, String newBody) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null || newBody.trim().isEmpty) return;
    try {
      await sb.from('messages')
          .update({
            'body': newBody.trim(),
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('user_id', uid);
      // Update local state
      final msgs = state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(body: newBody.trim(), editedAt: DateTime.now());
        }
        return m;
      }).toList();
      state = state.copyWith(messages: msgs);
    } catch (e) {
      debugPrint('[Chat] Edit error: $e');
    }
  }
}
