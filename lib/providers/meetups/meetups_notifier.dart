import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/meetup.dart';
import '../../data/repositories/meetups_repository.dart';
import '../core/providers.dart';

// ═══════════════════════════════════════════════════
//  MEETUPS STATE
// ═══════════════════════════════════════════════════

class MeetupsState {
  const MeetupsState({
    this.meetups = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Meetup> meetups;
  final bool isLoading;
  final String? error;

  MeetupsState copyWith({
    List<Meetup>? meetups,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MeetupsState(
      meetups: meetups ?? this.meetups,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ═══════════════════════════════════════════════════
//  MEETUPS REPOSITORY PROVIDER
// ═══════════════════════════════════════════════════

final meetupsRepositoryProvider = Provider<MeetupsRepository>((ref) {
  return MeetupsRepository();
});

// ═══════════════════════════════════════════════════
//  MEETUPS NOTIFIER
// ═══════════════════════════════════════════════════

final meetupsNotifierProvider =
    NotifierProvider<MeetupsNotifier, MeetupsState>(MeetupsNotifier.new);

class MeetupsNotifier extends Notifier<MeetupsState> {
  late MeetupsRepository _repo;
  String? _community;
  RealtimeChannel? _realtimeChannel;

  @override
  MeetupsState build() {
    _repo = ref.watch(meetupsRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
    });

    // Auto-load when community changes
    Future.microtask(() => loadMeetups());

    return const MeetupsState();
  }

  Future<void> loadMeetups() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meetups = await _repo.getUpcomingMeetups(
        community: _community ?? 'bikergram',
      );
      state = MeetupsState(meetups: meetups);
      _subscribeToChanges();
    } catch (e) {
      debugPrint('[MeetupsNotifier] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async => loadMeetups();

  void _subscribeToChanges() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('meetups-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetups',
          callback: (payload) {
            debugPrint('[MeetupsNotifier] Realtime change: ${payload.eventType}');
            // Silent refresh
            Future.microtask(() async {
              try {
                final meetups = await _repo.getUpcomingMeetups(
                  community: _community ?? 'bikergram',
                );
                state = MeetupsState(meetups: meetups);
              } catch (_) {}
            });
          },
        )
        .subscribe();
  }
}
