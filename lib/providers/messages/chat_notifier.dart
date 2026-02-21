import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/direct_message.dart';
import '../../data/repositories/message_repository.dart';
import '../core/providers.dart';
import 'unread_messages_notifier.dart';

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
  RealtimeChannel? _presenceChannel;

  @override
  ChatState build() {
    _repo = ref.watch(messageRepositoryProvider);

    ref.onDispose(() {
      _channel?.unsubscribe();
      _presenceChannel?.unsubscribe();
    });

    // Delay async work until after build() has returned and state is
    // initialised. Without this, _loadChat() tries to read/write
    // `state` before it exists → "Tried to read the state of an
    // uninitialized provider".
    Future.microtask(() => _loadChat(_conversationId));

    return const ChatState(isLoading: true);
  }

  Future<void> _loadChat(int conversationId) async {
    try {
      final otherUser = await _repo.getOtherParticipant(conversationId);

      final data = await _repo.getMessages(conversationId);
      final messages = data.map((row) => _parseMessage(row)).toList();

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        otherUsername: otherUser?['display_name'] as String? ??
            otherUser?['username'] as String? ??
            'Unbekannt',
        otherAvatarUrl: otherUser?['avatar_url'] as String?,
        otherUserId: otherUser?['id'] as String?,
      );

      await _repo.markAsRead(conversationId);
      ref.read(unreadMessagesProvider.notifier).refresh();

      _subscribeToMessages(conversationId);
      _subscribeToPresence(conversationId);
    } catch (e) {
      debugPrint('Error loading chat: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeToMessages(int conversationId) {
    _channel?.unsubscribe();
    _channel = _repo.subscribeToMessages(conversationId, (newRecord) {
      final message = _parseMessage(newRecord);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      final exists = state.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = state.copyWith(
          messages: [...state.messages, message],
        );
      }

      if (message.senderId != currentUserId) {
        _repo.markAsRead(conversationId);
        ref.read(unreadMessagesProvider.notifier).refresh();
      }
    });
  }

  /// Subscribe to presence for typing indicators.
  void _subscribeToPresence(int conversationId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _presenceChannel?.unsubscribe();
    _presenceChannel = Supabase.instance.client
        .channel('presence:chat:$conversationId')
        .onPresenceSync((payload) {
      bool otherTyping = false;
      try {
        final presences = _presenceChannel?.presenceState();
        if (presences is Map) {
          for (final entry in (presences as Map).entries) {
            if (entry.value is List) {
              for (final p in entry.value as List) {
                final payload =
                    (p is Map) ? p : (p as dynamic).payload as Map?;
                if (payload != null &&
                    payload['user_id'] != currentUserId &&
                    payload['typing'] == true) {
                  otherTyping = true;
                }
              }
            }
          }
        }
      } catch (_) {}
      state = state.copyWith(isOtherTyping: otherTyping);
    }).subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel?.track({
          'user_id': currentUserId,
          'typing': false,
        });
      }
    });
  }

  /// Notify that the current user is typing.
  void setTyping(bool isTyping) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _presenceChannel?.track({
      'user_id': currentUserId,
      'typing': isTyping,
    });
  }

  // ── Reply-to ──

  void setReplyTo(DirectMessage message) {
    state = state.copyWith(replyTo: message);
  }

  void clearReplyTo() {
    state = state.copyWith(clearReplyTo: true);
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
          messages: [...state.messages, message],
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }
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
          messages: [...state.messages, message],
          isSending: false,
          clearReplyTo: true,
        );
      } else {
        state = state.copyWith(isSending: false, clearReplyTo: true);
      }
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
          messages: [...state.messages, message],
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
          messages: [...state.messages, message],
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
    );
  }
}
