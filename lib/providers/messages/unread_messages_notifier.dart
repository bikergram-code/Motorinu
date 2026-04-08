import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/message_repository.dart';
import '../core/providers.dart';
import 'incoming_message_provider.dart';

/// Tracks app lifecycle for notification decisions
class _AppLifecycle {
  static final instance = _AppLifecycle._();
  _AppLifecycle._();
  bool isBackground = false;
}

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

  /// Check if the current user is a participant AND the conversation
  /// belongs to the current community before showing.
  Future<void> _checkConversationCommunity(
      int convId, Map<String, dynamic> newMessage) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 1. Check if user is actually a participant of this conversation
      final participant = await Supabase.instance.client
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', convId)
          .eq('user_id', currentUserId)
          .maybeSingle();
      if (participant == null) {
        debugPrint('[UnreadMsg] Not a participant of conv $convId → SKIP');
        return;
      }

      // 2. Check community
      final conv = await Supabase.instance.client
          .from('conversations')
          .select('community')
          .eq('id', convId)
          .maybeSingle();
      final convCommunity = conv?['community'] as String?;
      // Tolerant: NULL-community (alte Conversations) zählt als Match
      if (convCommunity != null && convCommunity != _community) {
        debugPrint(
            '[UnreadMsg] Message in conv $convId community=$convCommunity ≠ $_community → SKIP');
        return;
      }
      // Community matches (or is null) — increment and show toast
      debugPrint('[UnreadMsg] Participant + Community OK → increment');
      _incrementAndEmit(newMessage);
    } catch (e) {
      debugPrint('[UnreadMsg] Participation/community check error: $e');
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
    _showLocalNotification(newMessage);
  }

  /// Show a local notification for the new message — creates app icon badge
  Future<void> _showLocalNotification(Map<String, dynamic> msg) async {
    try {
      final senderId = msg['user_id']?.toString();
      if (senderId == null) return;

      // Fetch sender name
      String senderName = 'Neue Nachricht';
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', senderId)
            .maybeSingle();
        senderName = profile?['username'] as String? ?? 'Jemand';
      } catch (_) {}

      final content = msg['content']?.toString() ?? '';
      final displayContent = content.length > 100
          ? '${content.substring(0, 100)}...'
          : content;

      final convId = msg['conversation_id'];
      final groupKey = convId != null
          ? 'com.bikergram.conv_$convId'
          : 'com.bikergram.messages';

      final flnp = FlutterLocalNotificationsPlugin();

      // Individual message notification (grouped by conversation)
      final androidDetails = AndroidNotificationDetails(
        'messages',
        'Nachrichten',
        channelDescription: 'Neue Nachrichten',
        importance: Importance.high,
        priority: Priority.high,
        number: state, // Badge count = total unread
        showWhen: true,
        groupKey: groupKey,
      );
      final details = NotificationDetails(android: androidDetails);

      await flnp.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID per message
        senderName,
        displayContent.isEmpty ? 'Neue Nachricht' : displayContent,
        details,
      );

      // Summary notification for grouping (Android auto-groups when > 1)
      final summaryDetails = AndroidNotificationDetails(
        'messages',
        'Nachrichten',
        channelDescription: 'Neue Nachrichten',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: true,
        styleInformation: InboxStyleInformation(
          ['$senderName: ${displayContent.isEmpty ? 'Neue Nachricht' : displayContent}'],
          contentTitle: '$state neue Nachrichten',
          summaryText: '$state ungelesen',
        ),
      );
      await flnp.show(
        convId?.hashCode ?? 0, // same ID per conversation = updates summary
        '$state neue Nachrichten',
        '',
        NotificationDetails(android: summaryDetails),
      );
      debugPrint('[UnreadMsg] Local notification shown for $senderName');
    } catch (e) {
      debugPrint('[UnreadMsg] Notification error: $e');
    }
  }

  /// Poll every 15s as fallback if Realtime doesn't fire.
  /// Protects against race conditions: if a realtime increment happened
  /// less than 5 seconds ago, we skip the poll to avoid resetting the badge.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
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

      // Filter by community (include NULL-community for legacy conversations)
      final convs = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .inFilter('id', allConvIds)
          .or('community.eq.$_community,community.is.null');

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
