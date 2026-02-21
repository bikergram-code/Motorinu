import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/notification_repository.dart';
import '../core/providers.dart';
import 'incoming_notification_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String type; // 'like', 'comment', 'follow', 'mention', 'xp', 'system'
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationNotifier extends Notifier<NotificationsState> {
  late NotificationRepository _repo;
  String? _community;
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  /// IDs we've already shown a toast for (avoid repeat toasts on poll).
  final Set<int> _toastedIds = {};

  @override
  NotificationsState build() {
    _repo = ref.watch(notificationRepositoryProvider);
    // Watch community — invalidates this notifier when community changes
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _channel?.unsubscribe();
      _pollTimer?.cancel();
    });

    Future.microtask(() {
      _loadNotifications();
      _subscribe();
      _startPolling();
    });

    return const NotificationsState(isLoading: true);
  }

  Future<void> _loadNotifications() async {
    final wasLoading = state.isLoading;
    if (!wasLoading) {
      // Don't set isLoading for background refreshes (avoids UI flicker)
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final data = await _repo.getNotifications(community: _community);

      final notifications = data.map((row) {
        final id = row['id'] as int;
        _toastedIds.add(id); // Mark existing ones as already seen
        return AppNotification(
          id: id,
          type: row['type'] as String? ?? 'system',
          title: row['title'] as String? ?? '',
          body: row['body'] as String?,
          data: row['data'] is Map<String, dynamic>
              ? row['data'] as Map<String, dynamic>
              : const {},
          isRead: row['is_read'] as bool? ?? false,
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null,
        );
      }).toList();

      final unread = notifications.where((n) => !n.isRead).length;
      debugPrint('[Notif] Loaded ${notifications.length} notifications ($unread unread)');

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[Notif] Error loading: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    debugPrint('[Notif] Subscribing to realtime ...');
    _channel = _repo.subscribeToNotifications((newNotif) {
      debugPrint('[Notif] Realtime: ${newNotif['type']} — ${newNotif['title']}');
      _handleNewNotification(newNotif);
    });
  }

  /// Poll every 10s for new notifications (fallback if Realtime doesn't fire).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final data = await _repo.getNotifications(limit: 10, community: _community);
        bool hasNew = false;
        for (final row in data) {
          final id = row['id'] as int;
          final isRead = row['is_read'] as bool? ?? false;
          if (!isRead && !_toastedIds.contains(id)) {
            debugPrint('[Notif] Poll found new: id=$id ${row['title']}');
            _handleNewNotification(row);
            hasNew = true;
          }
        }
        // Also refresh the full list if we found new ones (updates badge)
        if (hasNew) {
          await _loadNotifications();
        }
      } catch (e) {
        debugPrint('[Notif] Poll error: $e');
      }
    });
  }

  void _handleNewNotification(Map<String, dynamic> newNotif) {
    final id = newNotif['id'] as int? ?? 0;

    // Strict community filter — only show notifications for the active community
    // Realtime might not include all columns if REPLICA IDENTITY is not FULL,
    // so we also verify via DB query if community is missing from payload.
    final notifCommunity = newNotif['community'] as String?;
    if (_community != null) {
      if (notifCommunity != null && notifCommunity != _community) {
        debugPrint('[Notif] Realtime: community=$notifCommunity ≠ $_community → SKIP');
        return;
      }
      if (notifCommunity == null) {
        // Community not in payload — verify from DB asynchronously
        debugPrint('[Notif] Realtime: community missing in payload, verifying from DB...');
        _verifyAndShowNotification(id, newNotif);
        return;
      }
    }

    _showNotification(id, newNotif);
  }

  /// Verify community from DB before showing notification.
  Future<void> _verifyAndShowNotification(int id, Map<String, dynamic> newNotif) async {
    try {
      final row = await Supabase.instance.client
          .from('notifications')
          .select('community')
          .eq('id', id)
          .maybeSingle();

      final dbCommunity = row?['community'] as String?;
      if (_community != null && dbCommunity != null && dbCommunity != _community) {
        debugPrint('[Notif] DB verify: community=$dbCommunity ≠ $_community → SKIP');
        return;
      }
      _showNotification(id, newNotif);
    } catch (e) {
      debugPrint('[Notif] DB verify error: $e — showing anyway');
      _showNotification(id, newNotif);
    }
  }

  void _showNotification(int id, Map<String, dynamic> newNotif) {
    // Avoid duplicate toasts
    if (_toastedIds.contains(id)) return;
    _toastedIds.add(id);

    final notif = AppNotification(
      id: id,
      type: newNotif['type'] as String? ?? 'system',
      title: newNotif['title'] as String? ?? '',
      body: newNotif['body'] as String?,
      data: newNotif['data'] is Map<String, dynamic>
          ? newNotif['data'] as Map<String, dynamic>
          : const {},
      isRead: false,
      createdAt: newNotif['created_at'] != null
          ? DateTime.tryParse(newNotif['created_at'] as String)
          : DateTime.now(),
    );

    // Add to top of list (only if not already there)
    final exists = state.notifications.any((n) => n.id == id);
    if (!exists) {
      state = state.copyWith(
        notifications: [notif, ...state.notifications],
      );
    }

    // Emit to toast bus
    IncomingNotificationBus.instance.emit(newNotif);
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(int notificationId) async {
    try {
      await _repo.markAsRead(notificationId);
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) return n.copyWith(isRead: true);
          return n;
        }).toList(),
      );
    } catch (e) {
      debugPrint('[Notif] Error marking as read: $e');
    }
  }

  /// Mark ALL notifications as read.
  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead(community: _community);
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList(),
      );
    } catch (e) {
      debugPrint('[Notif] Error marking all as read: $e');
    }
  }

  /// Refresh notifications from Supabase.
  Future<void> refresh() => _loadNotifications();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, NotificationsState>(
        NotificationNotifier.new);
