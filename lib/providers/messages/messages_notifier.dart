import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/message_repository.dart';
import '../../domain/models/direct_message.dart';
import '../core/providers.dart';

/// State for the conversations list.
class MessagesState {
  const MessagesState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  MessagesState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return MessagesState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MessagesNotifier extends Notifier<MessagesState> {
  late MessageRepository _repo;
  String? _community;

  @override
  MessagesState build() {
    _repo = ref.watch(messageRepositoryProvider);
    // Watch community — invalidates this notifier when community changes
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    // Delay async work until after build() has returned and state is
    // initialised. Without this, loadConversations() tries to read/write
    // `state` before it exists → "Tried to read the state of an
    // uninitialized provider".
    Future.microtask(() => loadConversations());

    return const MessagesState(isLoading: true);
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
