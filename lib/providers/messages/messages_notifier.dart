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
}

final messagesNotifierProvider =
    NotifierProvider<MessagesNotifier, MessagesState>(MessagesNotifier.new);
