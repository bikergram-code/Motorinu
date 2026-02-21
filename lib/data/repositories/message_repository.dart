import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Load all conversations for the current user with other participant info
  /// and last message. Optionally filtered by [community].
  Future<List<Map<String, dynamic>>> getConversations({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    debugPrint('[MsgRepo] getConversations(community: $community)');

    // Get all conversation IDs for the current user, optionally filtered by community
    final participations = await _supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', userId);

    if (participations.isEmpty) return [];

    final conversationIds = participations
        .map<int>((p) => p['conversation_id'] as int)
        .toList();

    debugPrint('[MsgRepo] Found ${conversationIds.length} conversations total');

    // For each conversation, get the other participant and last message
    final List<Map<String, dynamic>> results = [];

    for (final convId in conversationIds) {
      try {
        // Get conversation details (including community)
        final conv = await _supabase
            .from('conversations')
            .select()
            .eq('id', convId)
            .maybeSingle();

        // Strict community filter: only show conversations matching this community
        if (community != null && conv != null) {
          final convCommunity = conv['community'] as String?;
          if (convCommunity != community) {
            debugPrint('[MsgRepo] Conv $convId community=$convCommunity ≠ $community → SKIP');
            continue;
          }
        }

        // Get the other participant
        final otherParticipant = await _supabase
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', convId)
            .neq('user_id', userId)
            .maybeSingle();

        if (otherParticipant == null) continue;

        final otherUserId = otherParticipant['user_id'] as String;

        // Get other user's profile
        final otherProfile = await _supabase
            .from('profiles')
            .select('username, display_name, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();

        // Get last message
        final lastMessage = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // Count unread messages
        final unreadData = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .neq('user_id', userId)
            .eq('is_read', false);

        results.add({
          'id': convId,
          'other_user_id': otherUserId,
          'other_username': otherProfile?['display_name'] ??
              otherProfile?['username'] ??
              'Unbekannt',
          'other_avatar_url': otherProfile?['avatar_url'],
          'last_message_body': lastMessage?['body'],
          'last_message_at': lastMessage?['created_at'],
          'unread_count': unreadData.length,
          'created_at': lastMessage?['created_at'],
        });
      } catch (e) {
        debugPrint('Error loading conversation $convId: $e');
      }
    }

    // Sort by last message time (newest first)
    results.sort((a, b) {
      final aTime = a['last_message_at'] as String?;
      final bTime = b['last_message_at'] as String?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return results;
  }

  /// Get or create a 1-on-1 conversation with another user.
  /// Uses a Supabase RPC function (SECURITY DEFINER) to avoid RLS race conditions.
  /// [community] is passed so conversations are separated per community.
  /// Returns the conversation ID.
  Future<int> getOrCreateConversation(String otherUserId, {String? community}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    // IMPORTANT: Never send null — always default to 'bikergram'
    final effectiveCommunity = community ?? 'bikergram';
    debugPrint('[MsgRepo] getOrCreateConversation(other=$otherUserId, community=$effectiveCommunity)');

    final params = <String, dynamic>{
      'other_user_id': otherUserId,
      'p_community': effectiveCommunity,
    };

    final result = await _supabase.rpc(
      'get_or_create_conversation',
      params: params,
    );

    debugPrint('[MsgRepo] getOrCreateConversation → result=$result');

    // RPC returns the conversation ID directly (bigint → int)
    if (result is int) return result;
    return int.parse(result.toString());
  }

  /// Load messages for a conversation, ordered oldest first.
  Future<List<Map<String, dynamic>>> getMessages(int conversationId) async {
    final data = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return data;
  }

  /// Send a new message in a conversation.
  Future<Map<String, dynamic>> sendMessage(
    int conversationId,
    String body, {
    String? imageUrl,
    String? audioUrl,
    int? audioDurationMs,
    double? locationLat,
    double? locationLng,
    String? locationName,
    int? replyToId,
    String messageType = 'text',
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final insertData = <String, dynamic>{
      'conversation_id': conversationId,
      'user_id': userId,
      'body': body.trim(),
      'is_read': false,
      'message_type': messageType,
    };
    if (imageUrl != null) insertData['image_url'] = imageUrl;
    if (audioUrl != null) insertData['audio_url'] = audioUrl;
    if (audioDurationMs != null) {
      insertData['audio_duration_ms'] = audioDurationMs;
    }
    if (locationLat != null) insertData['location_lat'] = locationLat;
    if (locationLng != null) insertData['location_lng'] = locationLng;
    if (locationName != null) insertData['location_name'] = locationName;
    if (replyToId != null) insertData['reply_to_id'] = replyToId;

    final message = await _supabase
        .from('messages')
        .insert(insertData)
        .select()
        .single();

    // Update conversation timestamp
    await _supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return message;
  }

  /// Upload an image for a message and return the public URL.
  Future<String> uploadMessageImage(
    int conversationId,
    Uint8List bytes,
    String extension,
  ) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'messages/$userId/${timestamp}_msg.$extension';

    await _supabase.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );

    return _supabase.storage.from('posts').getPublicUrl(path);
  }

  /// Upload an audio file for a voice message and return the public URL.
  Future<String> uploadMessageAudio(
    int conversationId,
    String filePath,
  ) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = filePath.split('.').last;
    final storagePath = 'messages/$userId/${timestamp}_voice.$ext';

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await _supabase.storage.from('posts').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'audio/$ext',
            upsert: true,
          ),
        );

    return _supabase.storage.from('posts').getPublicUrl(storagePath);
  }

  /// Mark all messages in a conversation as read (messages from the other user).
  Future<void> markAsRead(int conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('user_id', userId)
        .eq('is_read', false);
  }

  /// Subscribe to new messages in a conversation (realtime).
  RealtimeChannel subscribeToMessages(
    int conversationId,
    void Function(Map<String, dynamic> message) onMessage,
  ) {
    return _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Get total unread message count across all conversations.
  /// Optionally filtered by [community].
  ///
  /// Uses an efficient approach: fetch community-matching conversation IDs
  /// in one query, then count unread messages in one query using `.in_()`.
  Future<int> getTotalUnreadCount({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      // 1. Get all conversation IDs the user participates in
      final participations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      if (participations.isEmpty) return 0;

      final allConvIds = participations
          .map<int>((p) => p['conversation_id'] as int)
          .toList();

      // 2. Filter by community in ONE query (instead of N queries)
      List<int> filteredConvIds;
      if (community != null && allConvIds.isNotEmpty) {
        final convs = await _supabase
            .from('conversations')
            .select('id')
            .inFilter('id', allConvIds)
            .eq('community', community);
        filteredConvIds = convs.map<int>((c) => c['id'] as int).toList();
      } else {
        filteredConvIds = allConvIds;
      }

      if (filteredConvIds.isEmpty) return 0;

      // 3. Count unread messages in ONE query (instead of N queries)
      final unread = await _supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', filteredConvIds)
          .neq('user_id', userId)
          .eq('is_read', false);

      debugPrint('[MsgRepo] getTotalUnreadCount(community=$community) = ${unread.length}');
      return unread.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Subscribe to ALL new messages across all conversations (for badge).
  RealtimeChannel subscribeToAllMessages(
    void Function(Map<String, dynamic> message) onMessage,
  ) {
    return _supabase
        .channel('messages:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Get other user info for a conversation.
  Future<Map<String, dynamic>?> getOtherParticipant(
      int conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final participant = await _supabase
        .from('conversation_participants')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .neq('user_id', userId)
        .maybeSingle();

    if (participant == null) return null;

    final profile = await _supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', participant['user_id'])
        .maybeSingle();

    return profile;
  }
}
