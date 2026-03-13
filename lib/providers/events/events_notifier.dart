import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/event.dart';
import '../../data/repositories/events_repository.dart';
import '../core/providers.dart';

// ═══════════════════════════════════════════════════
//  EVENTS STATE
// ═══════════════════════════════════════════════════

class EventsState {
  const EventsState({
    this.events = const [],
    this.todayEvents = const [],
    this.crossPromoEvents = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
  });

  final List<BikerEvent> events;
  final List<BikerEvent> todayEvents;
  final List<BikerEvent> crossPromoEvents; // Events from the other community
  final bool isLoading;
  final String? error;
  final String? selectedCategory; // null = alle

  EventsState copyWith({
    List<BikerEvent>? events,
    List<BikerEvent>? todayEvents,
    List<BikerEvent>? crossPromoEvents,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    bool clearCategory = false,
    bool clearError = false,
  }) {
    return EventsState(
      events: events ?? this.events,
      todayEvents: todayEvents ?? this.todayEvents,
      crossPromoEvents: crossPromoEvents ?? this.crossPromoEvents,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
    );
  }
}

// ═══════════════════════════════════════════════════
//  EVENTS NOTIFIER
// ═══════════════════════════════════════════════════

final eventsNotifierProvider =
    NotifierProvider<EventsNotifier, EventsState>(EventsNotifier.new);

class EventsNotifier extends Notifier<EventsState> {
  late EventsRepository _repo;
  String? _community;
  RealtimeChannel? _realtimeChannel;

  @override
  EventsState build() {
    _repo = ref.watch(eventsRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
    });

    // Auto-load events when community changes (build() re-runs on dependency change)
    Future.microtask(() => loadEvents());

    return const EventsState();
  }

  /// Load events (today + filtered list + cross-promo from other community).
  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Load in parallel: today + upcoming + cross-promo
      final results = await Future.wait([
        _repo.getEventsForToday(community: _community),
        _repo.getUpcomingEvents(
          community: _community,
          category: state.selectedCategory,
        ),
        _repo.getCrossPromoEvents(currentCommunity: _community ?? 'bikergram'),
      ]);

      state = state.copyWith(
        todayEvents: results[0],
        events: results[1],
        crossPromoEvents: results[2],
        isLoading: false,
      );

      // Subscribe to real-time changes after first load
      _subscribeToChanges();
    } catch (e) {
      debugPrint('[EventsNotifier] Load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Fehler beim Laden der Events',
      );
    }
  }

  /// Filter by category (null = alle).
  Future<void> filterByCategory(String? category) async {
    if (category == null) {
      // "Alle" tapped → always clear the filter
      state = state.copyWith(clearCategory: true);
    } else if (category == state.selectedCategory) {
      // Same category tapped again → toggle off (back to Alle)
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }

    // Reload with new filter
    state = state.copyWith(isLoading: true);

    try {
      final events = await _repo.getUpcomingEvents(
        community: _community,
        category: state.selectedCategory,
      );

      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      debugPrint('[EventsNotifier] Filter error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle participation (join/leave) for an event.
  Future<void> toggleParticipation(int eventId) async {
    // Find the event
    BikerEvent? event;
    for (final e in state.events) {
      if (e.id == eventId) {
        event = e;
        break;
      }
    }
    // Also check today events
    event ??= state.todayEvents.firstWhere(
      (e) => e.id == eventId,
      orElse: () => event!,
    );

    if (event == null) return;

    try {
      if (event.myStatus == 'going') {
        await _repo.leaveEvent(eventId);
      } else {
        await _repo.joinEvent(eventId);
      }

      // Optimistic update: toggle status + adjust count
      _updateEventInState(eventId, (e) {
        final isNowGoing = e.myStatus != 'going';
        return e.copyWith(
          myStatus: isNowGoing ? 'going' : null,
          participantCount:
              isNowGoing ? e.participantCount + 1 : e.participantCount - 1,
        );
      });
    } catch (e) {
      debugPrint('[EventsNotifier] Toggle participation error: $e');
    }
  }

  /// Create a new event.
  Future<BikerEvent> createEvent({
    required String title,
    String? description,
    String? imageUrl,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
    String? category,
    int? maxParticipants,
    Uint8List? imageBytes,
  }) async {
    // Upload image first if provided
    String? finalImageUrl = imageUrl;
    if (imageBytes != null) {
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
      finalImageUrl = await _repo.uploadEventImage(imageBytes, userId);
    }

    final event = await _repo.createEvent(
      title: title,
      description: description,
      imageUrl: finalImageUrl,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      category: category,
      community: _community,
      maxParticipants: maxParticipants,
    );

    // Refresh to include the new event
    await _silentRefresh();

    return event;
  }

  /// Delete an event (only by creator).
  Future<void> deleteEvent(int eventId) async {
    await _repo.deleteEvent(eventId);

    // Remove from local state
    state = state.copyWith(
      events: state.events.where((e) => e.id != eventId).toList(),
      todayEvents: state.todayEvents.where((e) => e.id != eventId).toList(),
    );
  }

  /// Refresh (pull-to-refresh).
  Future<void> refresh() async {
    await loadEvents();
  }

  // ═══════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  void _subscribeToChanges() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('events_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (payload) {
            _silentRefresh();
          },
        )
        .subscribe();
  }

  Future<void> _silentRefresh() async {
    try {
      final results = await Future.wait([
        _repo.getEventsForToday(community: _community),
        _repo.getUpcomingEvents(
          community: _community,
          category: state.selectedCategory,
        ),
        _repo.getCrossPromoEvents(currentCommunity: _community ?? 'bikergram'),
      ]);

      state = state.copyWith(
        todayEvents: results[0],
        events: results[1],
        crossPromoEvents: results[2],
      );
    } catch (e) {
      debugPrint('[EventsNotifier] Silent refresh error: $e');
    }
  }

  /// Update a single event in both events and todayEvents lists.
  void _updateEventInState(
    int eventId,
    BikerEvent Function(BikerEvent) updater,
  ) {
    state = state.copyWith(
      events: state.events.map((e) {
        if (e.id == eventId) return updater(e);
        return e;
      }).toList(),
      todayEvents: state.todayEvents.map((e) {
        if (e.id == eventId) return updater(e);
        return e;
      }).toList(),
    );
  }
}
