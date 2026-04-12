import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/message_repository.dart';
import '../../domain/models/direct_message.dart';
import '../core/providers.dart';

/// State for the conversations list.
class MessagesState {
  const MessagesState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.typingConversationIds = const {},
  });

  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;
  /// Conversation IDs where someone is currently typing.
  final Set<int> typingConversationIds;

  MessagesState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
    Set<int>? typingConversationIds,
  }) {
    return MessagesState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      typingConversationIds: typingConversationIds ?? this.typingConversationIds,
    );
  }
}

class MessagesNotifier extends Notifier<MessagesState> {
  late MessageRepository _repo;
  String? _community;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _messagesChannel;
  final Map<int, Timer> _typingTimers = {};

  @override
  MessagesState build() {
    _repo = ref.watch(messageRepositoryProvider);
    // Watch community — invalidates this notifier when community changes
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    // Delay async work until after build() has returned and state is
    // initialised. Without this, loadConversations() tries to read/write
    // `state` before it exists → "Tried to read the state of an
    // uninitialized provider".
    Future.microtask(() {
      loadConversations();
      _subscribeToTypingBroadcast();
      _subscribeToNewMessages();
    });

    ref.onDispose(() {
      _typingChannel?.unsubscribe();
      _messagesChannel?.unsubscribe();
      for (final t in _typingTimers.values) { t.cancel(); }
    });

    return const MessagesState(isLoading: true);
  }

  /// Subscribe to conversation_participants changes for typing indicators.
  /// Uses Postgres Changes — no filter (listens to all updates), client-side
  /// filters by user_id.
  void _subscribeToTypingBroadcast() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _typingChannel?.unsubscribe();
    _typingChannel = Supabase.instance.client
        .channel('typing:participants')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversation_participants',
          callback: (payload) {
            final record = payload.newRecord;
            final convId = record['conversation_id'];
            final userId = record['user_id']?.toString();
            final isTyping = record['is_typing'] == true;
            if (convId == null || userId == null || userId == currentUserId) return;

            final cid = convId is int ? convId : int.tryParse('$convId');
            if (cid == null) return;

            debugPrint('[Messages] Typing DB change: conv=$cid, user=$userId, typing=$isTyping');

            final current = Set<int>.from(state.typingConversationIds);
            if (isTyping) {
              current.add(cid);
              // Auto-clear after 5 seconds (safety net)
              _typingTimers[cid]?.cancel();
              _typingTimers[cid] = Timer(const Duration(seconds: 5), () {
                final updated = Set<int>.from(state.typingConversationIds)..remove(cid);
                state = state.copyWith(typingConversationIds: updated);
              });
            } else {
              current.remove(cid);
              _typingTimers[cid]?.cancel();
            }
            state = state.copyWith(typingConversationIds: current);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[Messages] typing:participants channel status=$status, error=$error');
    });
  }

  /// Subscribe to new messages → auto-refresh conversation list preview.
  void _subscribeToNewMessages() {
    _messagesChannel?.unsubscribe();
    _messagesChannel = Supabase.instance.client
        .channel('messages:list-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            debugPrint('[Messages] New message detected → refreshing list');
            loadConversations();
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[Messages] messages:list-refresh channel status=$status');
    });
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[MsgNotifier] Loading conversations for community=$_community');
      final data = await _repo.getConversations(community: _community);

      final conversations = data.map((row) {
        return Conversation(
          id: row['id'] as int,
          otherUserId: row['other_user_id'] as String,
          otherUsername: row['other_username'] as String?,
          otherAvatarUrl: row['other_avatar_url'] as String?,
          lastMessageBody: row['last_message_body'] as String?,
          lastMessageAt: row['last_message_at'] != null
              ? DateTime.tryParse(row['last_message_at'] as String)
              : null,
          unreadCount: row['unread_count'] as int? ?? 0,
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null,
          // Group chat fields
          isGroupChat: row['is_group_chat'] == true,
          groupId: (row['group_id'] as num?)?.toInt(),
          groupName: row['group_name'] as String?,
          groupAvatarUrl: row['group_avatar_url'] as String?,
          archivedAt: row['archived_at'] != null
              ? DateTime.tryParse(row['archived_at'] as String)
              : null,
          deletedAt: row['deleted_at'] != null
              ? DateTime.tryParse(row['deleted_at'] as String)
              : null,
        );
      }).toList();

      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadConversations();

  Future<void> archiveConversation(int conversationId) async {
    try {
      await _repo.archiveConversation(conversationId);
      debugPrint('[Messages] archived $conversationId');
    } catch (e) {
      debugPrint('[Messages] archiveConversation error: $e');
    }
    await loadConversations();
  }

  Future<void> unarchiveConversation(int conversationId) async {
    try {
      await _repo.unarchiveConversation(conversationId);
      debugPrint('[Messages] unarchived $conversationId');
    } catch (e) {
      debugPrint('[Messages] unarchiveConversation error: $e');
    }
    await loadConversations();
  }

  Future<void> deleteConversation(int conversationId) async {
    try {
      await _repo.deleteConversation(conversationId);
      debugPrint('[Messages] deleted $conversationId');
    } catch (e) {
      debugPrint('[Messages] deleteConversation error: $e');
    }
    await loadConversations();
  }

  Future<void> deleteConversations(List<int> ids) async {
    for (final id in ids) {
      try {
        await _repo.deleteConversation(id);
      } catch (e) {
        debugPrint('[Messages] deleteConversation($id) error: $e');
      }
    }
    await loadConversations();
  }

  Future<void> archiveConversations(List<int> ids) async {
    for (final id in ids) {
      try {
        await _repo.archiveConversation(id);
      } catch (e) {
        debugPrint('[Messages] archiveConversation($id) error: $e');
      }
    }
    await loadConversations();
  }

  Future<void> markConversationAsRead(int conversationId) async {
    await _repo.markAsRead(conversationId);
    await loadConversations();
  }

  Future<void> markConversationAsUnread(int conversationId) async {
    await _repo.markAsUnread(conversationId);
    await loadConversations();
  }

  Future<void> restoreConversation(int conversationId) async {
    try {
      await _repo.restoreConversation(conversationId);
      debugPrint('[Messages] restored $conversationId');
    } catch (e) {
      debugPrint('[Messages] restoreConversation error: $e');
    }
    await loadConversations();
  }

  Future<void> permanentlyDeleteConversation(int conversationId) async {
    try {
      await _repo.permanentlyDeleteConversation(conversationId);
      debugPrint('[Messages] permanently deleted $conversationId');
    } catch (e) {
      debugPrint('[Messages] permanentlyDeleteConversation error: $e');
    }
    await loadConversations();
  }

  Future<void> permanentlyDeleteConversations(List<int> ids) async {
    for (final id in ids) {
      try {
        await _repo.permanentlyDeleteConversation(id);
      } catch (e) {
        debugPrint('[Messages] permanentlyDelete($id) error: $e');
      }
    }
    await loadConversations();
  }
}

final messagesNotifierProvider =
    NotifierProvider<MessagesNotifier, MessagesState>(MessagesNotifier.new);
