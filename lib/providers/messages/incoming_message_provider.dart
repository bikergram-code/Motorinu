import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a single incoming message event for the in-app toast.
class IncomingMessage {
  const IncomingMessage({
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.body,
    required this.conversationId,
    required this.timestamp,
  });

  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String body;
  final int conversationId;
  final DateTime timestamp;
}

/// Global event bus for incoming message toasts.
/// Fed by UnreadMessagesNotifier when a new message arrives —
/// no separate Realtime channel needed.
class IncomingMessageBus {
  IncomingMessageBus._();
  static final instance = IncomingMessageBus._();

  final _controller = StreamController<IncomingMessage>.broadcast();

  Stream<IncomingMessage> get stream => _controller.stream;

  /// Called from UnreadMessagesNotifier callback.
  Future<void> emit(Map<String, dynamic> newMessage) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final senderId = newMessage['user_id']?.toString();

    if (senderId == null || senderId == currentUserId) return;

    final body = newMessage['body']?.toString() ?? '';
    final conversationId = newMessage['conversation_id'] as int? ?? 0;
    final messageType = newMessage['message_type']?.toString() ?? 'text';

    // Determine preview text based on message type
    String previewText;
    if (messageType == 'vehicle_offer') {
      // Parse offer JSON for human-readable preview
      try {
        final data = json.decode(body) as Map<String, dynamic>;
        final type = data['type'] as String? ?? 'offer';
        final vehicleName = data['vehicle_name'] as String? ?? '';
        final amount = (data['price'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0;
        previewText = switch (type) {
          'like' => '\u2764\ufe0f $vehicleName gefällt mir',
          'offer' => '\ud83d\udcb0 Angebot: ${amount.toStringAsFixed(0)} \u20ac für $vehicleName',
          'counter' => '\ud83d\udd04 Gegenangebot: ${amount.toStringAsFixed(0)} \u20ac für $vehicleName',
          'accepted' => '\u2705 Angebot angenommen! $vehicleName',
          'declined' => '\u274c Angebot abgelehnt: $vehicleName',
          _ => '\ud83d\udcb0 Angebot für $vehicleName',
        };
      } catch (_) {
        previewText = 'Fahrzeug-Angebot';
      }
    } else if (messageType == 'image' || newMessage['image_url'] != null) {
      previewText = body.isNotEmpty ? body : '\ud83d\udcf7 Bild';
    } else if (messageType == 'audio' || newMessage['audio_url'] != null) {
      previewText = '\ud83c\udfa4 Sprachnachricht';
    } else if (messageType == 'location' ||
        newMessage['location_lat'] != null) {
      previewText =
          '\ud83d\udccd ${newMessage['location_name']?.toString() ?? 'Standort'}';
    } else {
      previewText = body;
    }

    // Fetch sender profile
    String senderName = 'Unbekannt';
    String? senderAvatarUrl;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();

      if (profile != null) {
        senderName = (profile['display_name'] as String?) ??
            (profile['username'] as String?) ??
            'Unbekannt';
        senderAvatarUrl = profile['avatar_url'] as String?;
      }
    } catch (e) {
      debugPrint('[MessageBus] Error fetching sender profile: $e');
    }

    debugPrint('[MessageBus] Toast: $senderName → $previewText');

    final msg = IncomingMessage(
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      body: previewText,
      conversationId: conversationId,
      timestamp: DateTime.now(),
    );

    _controller.add(msg);

    // Auto-unarchive in background (fire-and-forget, don't block message delivery)
    if (conversationId > 0) {
      _autoUnarchive(conversationId);
    }

    // Also push to Android notification system (for Android Auto messaging)
    _showAndroidNotification(msg);
  }

  /// Fire-and-forget: unarchive conversation if archived.
  void _autoUnarchive(int conversationId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final participant = await Supabase.instance.client
          .from('conversation_participants')
          .select('archived_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();
      if (participant != null && participant['archived_at'] != null) {
        await Supabase.instance.client
            .from('conversation_participants')
            .update({'archived_at': null})
            .eq('conversation_id', conversationId)
            .eq('user_id', userId);
        debugPrint('[MessageBus] Auto-unarchived conversation $conversationId');
      }
    } catch (e) {
      debugPrint('[MessageBus] Auto-unarchive error: $e');
    }
  }

  /// MethodChannel to push MessagingStyle notifications to Android.
  /// Android Auto picks these up automatically for read-aloud + voice reply.
  static const _channel = MethodChannel('com.bikergram.app/android_auto');

  void _showAndroidNotification(IncomingMessage msg) {
    try {
      _channel.invokeMethod('showMessageNotification', {
        'conversationId': msg.conversationId,
        'senderId': msg.senderId,
        'senderName': msg.senderName,
        'senderAvatarUrl': msg.senderAvatarUrl,
        'messageBody': msg.body,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[MessageBus] Android notification error: $e');
    }
  }

  /// Cancel notification for a conversation (call when user opens the chat).
  void cancelNotification(int conversationId) {
    try {
      _channel.invokeMethod('cancelMessageNotification', conversationId);
    } catch (e) {
      debugPrint('[MessageBus] Cancel notification error: $e');
    }
  }
}

/// StreamProvider that exposes the latest incoming message for the UI.
final incomingMessageProvider = StreamProvider<IncomingMessage>((ref) {
  return IncomingMessageBus.instance.stream;
});
