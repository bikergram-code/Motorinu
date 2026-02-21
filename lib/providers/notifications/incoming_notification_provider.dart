import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single incoming notification event for the in-app toast.
class IncomingNotification {
  const IncomingNotification({
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    required this.timestamp,
  });

  final String type; // 'like', 'comment', 'follow', 'mention', 'xp', 'system'
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  /// Icon for the notification type.
  String get emoji => switch (type) {
        'like' => '❤️',
        'comment' => '💬',
        'follow' => '👤',
        'mention' => '📢',
        'xp' => '⭐',
        'system' => 'ℹ️',
        _ => '🔔',
      };
}

/// Global event bus for incoming notification toasts.
/// Fed by NotificationNotifier when a new notification arrives.
class IncomingNotificationBus {
  IncomingNotificationBus._();
  static final instance = IncomingNotificationBus._();

  final _controller = StreamController<IncomingNotification>.broadcast();

  Stream<IncomingNotification> get stream => _controller.stream;

  /// Called from NotificationNotifier callback.
  void emit(Map<String, dynamic> newNotif) {
    final type = newNotif['type']?.toString() ?? 'system';
    final title = newNotif['title']?.toString() ?? '';
    final body = newNotif['body']?.toString();

    debugPrint('[NotifBus] Toast: $type → $title');

    _controller.add(IncomingNotification(
      type: type,
      title: title,
      body: body,
      data: newNotif['data'] is Map<String, dynamic>
          ? newNotif['data'] as Map<String, dynamic>
          : const {},
      timestamp: DateTime.now(),
    ));
  }
}

/// StreamProvider that exposes the latest incoming notification for the UI.
final incomingNotificationProvider =
    StreamProvider<IncomingNotification>((ref) {
  return IncomingNotificationBus.instance.stream;
});
