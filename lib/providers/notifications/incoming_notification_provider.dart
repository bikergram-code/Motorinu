import 'dart:async';
import 'dart:convert';

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
        'vehicle_offer' => '💰',
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
    var body = newNotif['body']?.toString();

    // Parse vehicle_offer JSON body into human-readable text
    if (type == 'vehicle_offer' && body != null && body.startsWith('{')) {
      try {
        final data = json.decode(body) as Map<String, dynamic>;
        final offerType = data['type'] as String? ?? 'offer';
        final vehicleName = data['vehicle_name'] as String? ?? '';
        final amount = (data['price'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0;
        body = switch (offerType) {
          'like' => '\u2764\ufe0f $vehicleName gefällt mir',
          'offer' => '\ud83d\udcb0 Angebot: ${amount.toStringAsFixed(0)} \u20ac für $vehicleName',
          'counter' => '\ud83d\udd04 Gegenangebot: ${amount.toStringAsFixed(0)} \u20ac für $vehicleName',
          'accepted' => '\u2705 Angebot angenommen! $vehicleName',
          'declined' => '\u274c Angebot abgelehnt: $vehicleName',
          'direct_buy' => '\ud83d\uded2 Direktkauf: $vehicleName',
          _ => '\ud83d\udcb0 Angebot für $vehicleName',
        };
      } catch (_) {
        body = 'Fahrzeug-Angebot';
      }
    }

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
