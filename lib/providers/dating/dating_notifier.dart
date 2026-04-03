import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/dating_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/profile_repository.dart';

// ── State ────────────────────────────────────────────────────────────────────

class DatingState {
  final List<Map<String, dynamic>> candidates;
  final bool isLoading;
  final String? error;

  /// Non-null when a match just happened — triggers the match overlay.
  final Map<String, dynamic>? lastMatch;

  const DatingState({
    this.candidates = const [],
    this.isLoading = false,
    this.error,
    this.lastMatch,
  });

  DatingState copyWith({
    List<Map<String, dynamic>>? candidates,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? lastMatch,
    bool clearMatch = false,
    bool clearError = false,
  }) {
    return DatingState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastMatch: clearMatch ? null : (lastMatch ?? this.lastMatch),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class DatingNotifier extends Notifier<DatingState> {
  late final DatingRepository _repo;

  @override
  DatingState build() {
    _repo = DatingRepository();
    return const DatingState();
  }

  Future<void> loadCandidates(String community) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await _repo.getCandidates(community: community);
      state = state.copyWith(candidates: results, isLoading: false);
    } catch (e) {
      debugPrint('[Dating] loadCandidates error: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> swipe({
    required String swipedId,
    required bool isLike,
    required String community,
    String? matchedAvatarUrl,
  }) async {
    // Remove from local list immediately for snappy UI
    final updated = state.candidates.where((c) => c['id'] != swipedId).toList();
    state = state.copyWith(candidates: updated);

    try {
      final result = await _repo.recordSwipe(
        swipedId: swipedId,
        isLike: isLike,
        community: community,
      );

      // Get my display name and ID for notifications
      String myName = 'Jemand';
      final myId = Supabase.instance.client.auth.currentUser?.id;
      try {
        if (myId != null) {
          final p = await ProfileRepository().getProfile(myId);
          myName = p['display_name'] ?? p['bikername'] ?? p['username'] ?? 'Jemand';
        }
      } catch (_) {}

      if (result['matched'] == true) {
        final matchData = Map<String, dynamic>.from(result);
        if (matchedAvatarUrl != null) {
          matchData['matched_avatar_url'] = matchedAvatarUrl;
        }
        state = state.copyWith(lastMatch: matchData);

        // 🔔 Push-Notification an den gematchten User senden
        final convId = result['conversation_id'];
        NotificationRepository().createNotification(
          targetUserId: swipedId,
          type: 'like',
          title: '💕 Es ist ein Match!',
          body: '$myName und du habt ein Match! Schreib jetzt eine Nachricht.',
          community: community,
          data: {
            'type': 'match',
            if (convId != null) 'conversation_id': convId,
            if (myId != null) 'actor_id': myId,
          },
        );
      } else if (isLike) {
        // 🔔 Benachrichtigung: User hat dich geliked (kein Match noch)
        NotificationRepository().createNotification(
          targetUserId: swipedId,
          type: 'like',
          title: '❤️ $myName hat dich geliked!',
          body: '$myName findet dich interessant. Schau mal nach!',
          community: community,
          data: {
            'type': 'dating_like',
            if (myId != null) 'actor_id': myId,
          },
        );
      }

      // Auto-load more when running low
      if (state.candidates.length < 5) {
        final more = await _repo.getCandidates(community: community);
        if (more.isNotEmpty) {
          final existingIds = state.candidates.map((c) => c['id']).toSet();
          final newOnes = more.where((c) => !existingIds.contains(c['id'])).toList();
          state = state.copyWith(
            candidates: [...state.candidates, ...newOnes],
          );
        }
      }
    } catch (e) {
      debugPrint('[Dating] swipe error: $e');
    }
  }

  void clearMatch() {
    state = state.copyWith(clearMatch: true);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final datingNotifierProvider =
    NotifierProvider<DatingNotifier, DatingState>(DatingNotifier.new);
