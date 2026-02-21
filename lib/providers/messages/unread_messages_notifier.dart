import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/message_repository.dart';
import '../core/providers.dart';
import 'incoming_message_provider.dart';

/// Global unread message count provider.
/// Uses Supabase Realtime + polling fallback (every 15s).
/// Automatically re-evaluates when community changes.
final unreadMessagesProvider =
    NotifierProvider<UnreadMessagesNotifier, int>(UnreadMessagesNotifier.new);

class UnreadMessagesNotifier extends Notifier<int> {
  late MessageRepository _repo;
  String _community = 'bikergram';
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  /// Track when we last got a realtime increment so polling doesn't
  /// immediately override it before the DB has caught up.
  DateTime _lastRealtimeIncrement = DateTime(2000);

  @override
  int build() {
    _repo = ref.watch(messageRepositoryProvider);
    // Watch community — invalidates this notifier when community changes
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _channel?.unsubscribe();
      _pollTimer?.cancel();
    });

    Future.microtask(() {
      _loadCount();
      _subscribeToMessages();
      _startPolling();
    });

    return 0;
  }

  Future<void> _loadCount() async {
    try {
      final count = await _repo.getTotalUnreadCount(community: _community);
      debugPrint('[UnreadMsg] _loadCount → $count (was $state)');
      state = count;
    } catch (e) {
      debugPrint('[UnreadMsg] Error loading count: $e');
    }
  }

  void _subscribeToMessages() {
    _channel?.unsubscribe();
    debugPrint('[UnreadMsg] Subscribing to messages:all (community=$_community) ...');
    _channel = _repo.subscribeToAllMessages((newMessage) {
      debugPrint('[UnreadMsg] Realtime message arrived');
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final senderId = newMessage['user_id']?.toString();

      if (senderId != null && senderId != currentUserId) {
        // Check if this message belongs to the current community
        final convId = newMessage['conversation_id'];
        if (convId != null) {
          _checkConversationCommunity(
            convId is int ? convId : int.parse(convId.toString()),
            newMessage,
          );
        } else {
          // No convId — show it (edge case)
          _incrementAndEmit(newMessage);
        }
      }
    });
  }

  /// Check if a conversation belongs to the current community before showing.
  Future<void> _checkConversationCommunity(
      int convId, Map<String, dynamic> newMessage) async {
    try {
      final conv = await Supabase.instance.client
          .from('conversations')
          .select('community')
          .eq('id', convId)
          .maybeSingle();
      final convCommunity = conv?['community'] as String?;
      if (convCommunity != _community) {
        debugPrint(
            '[UnreadMsg] Message in conv $convId community=$convCommunity ≠ $_community → SKIP');
        return;
      }
      // Community matches — increment and show toast
      _incrementAndEmit(newMessage);
    } catch (e) {
      debugPrint('[UnreadMsg] Community check error: $e');
      // On error, still show it (better safe)
      _incrementAndEmit(newMessage);
    }
  }

  /// Increment the badge count and emit toast event.
  /// Also marks when this happened so polling won't override too quickly.
  void _incrementAndEmit(Map<String, dynamic> newMessage) {
    state = state + 1;
    _lastRealtimeIncrement = DateTime.now();
    debugPrint('[UnreadMsg] Incremented to $state');
    IncomingMessageBus.instance.emit(newMessage);
  }

  /// Poll every 15s as fallback if Realtime doesn't fire.
  /// Protects against race conditions: if a realtime increment happened
  /// less than 5 seconds ago, we skip the poll to avoid resetting the badge.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        // Don't poll if we just got a realtime event — the DB might
        // not have caught up yet (replication lag, etc.).
        final sinceLast =
            DateTime.now().difference(_lastRealtimeIncrement).inSeconds;
        if (sinceLast < 5) {
          debugPrint('[UnreadMsg] Poll skipped — realtime increment ${sinceLast}s ago');
          return;
        }

        final newCount = await _repo.getTotalUnreadCount(community: _community);
        if (newCount != state) {
          debugPrint('[UnreadMsg] Poll: $state → $newCount');
          if (newCount > state) {
            // New messages appeared that Realtime missed — fetch for toast
            _fetchLatestUnreadForToast();
          }
          state = newCount;
        }
      } catch (e) {
        debugPrint('[UnreadMsg] Poll error: $e');
      }
    });
  }

  /// Fetch the latest unread message to show in the toast.
  /// Only shows messages from conversations in the current community.
  Future<void> _fetchLatestUnreadForToast() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get conversations for this community in one query
      final participations = await Supabase.instance.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      if (participations.isEmpty) return;

      final allConvIds = participations
          .map<int>((p) => p['conversation_id'] as int)
          .toList();

      // Filter by community
      final convs = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .inFilter('id', allConvIds)
          .eq('community', _community);

      final communityConvIds = convs.map<int>((c) => c['id'] as int).toList();
      if (communityConvIds.isEmpty) return;

      // Find the most recent unread message across all community conversations
      final msgs = await Supabase.instance.client
          .from('messages')
          .select()
          .inFilter('conversation_id', communityConvIds)
          .neq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (msgs.isNotEmpty) {
        IncomingMessageBus.instance.emit(msgs.first);
      }
    } catch (e) {
      debugPrint('[UnreadMsg] Fetch latest error: $e');
    }
  }

  /// Force-refresh from DB. Called when leaving a chat or explicitly needed.
  Future<void> refresh() async {
    // Small delay to let markAsRead() propagate to DB
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadCount();
  }

  void decrementBy(int amount) {
    state = (state - amount).clamp(0, 999);
  }
}
