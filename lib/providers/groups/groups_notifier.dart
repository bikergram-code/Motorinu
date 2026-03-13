import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/group.dart';
import '../../data/repositories/group_repository.dart';
import '../core/providers.dart';

// ═══════════════════════════════════════════════════
//  GROUPS STATE
// ═══════════════════════════════════════════════════

class GroupsState {
  const GroupsState({
    this.myGroups = const [],
    this.discoverGroups = const [],
    this.isLoading = false,
    this.error,
    this.selectedType,
  });

  final List<BikerGroup> myGroups;
  final List<BikerGroup> discoverGroups;
  final bool isLoading;
  final String? error;
  final String? selectedType; // null = alle

  GroupsState copyWith({
    List<BikerGroup>? myGroups,
    List<BikerGroup>? discoverGroups,
    bool? isLoading,
    String? error,
    String? selectedType,
    bool clearType = false,
    bool clearError = false,
  }) {
    return GroupsState(
      myGroups: myGroups ?? this.myGroups,
      discoverGroups: discoverGroups ?? this.discoverGroups,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
    );
  }
}

// ═══════════════════════════════════════════════════
//  GROUPS NOTIFIER
// ═══════════════════════════════════════════════════

final groupsNotifierProvider =
    NotifierProvider<GroupsNotifier, GroupsState>(GroupsNotifier.new);

class GroupsNotifier extends Notifier<GroupsState> {
  late GroupRepository _repo;
  String? _community;
  RealtimeChannel? _realtimeChannel;

  @override
  GroupsState build() {
    _repo = ref.watch(groupRepositoryProvider);
    _community = ref.watch(communityProvider)?.name ?? 'bikergram';

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
    });

    Future.microtask(() => loadGroups());
    return const GroupsState();
  }

  /// Load my groups + discover groups in parallel.
  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _repo.getMyGroups(community: _community),
        _repo.discoverGroups(
          community: _community,
          groupType: state.selectedType,
        ),
      ]);

      state = state.copyWith(
        myGroups: results[0],
        discoverGroups: results[1],
        isLoading: false,
      );

      _subscribeToChanges();
    } catch (e) {
      debugPrint('[GroupsNotifier] Load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Fehler beim Laden der Gruppen',
      );
    }
  }

  /// Filter discover groups by type.
  Future<void> filterByType(String? type) async {
    if (type == null) {
      state = state.copyWith(clearType: true);
    } else if (type == state.selectedType) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(selectedType: type);
    }

    state = state.copyWith(isLoading: true);

    try {
      final discover = await _repo.discoverGroups(
        community: _community,
        groupType: state.selectedType,
      );
      state = state.copyWith(discoverGroups: discover, isLoading: false);
    } catch (e) {
      debugPrint('[GroupsNotifier] Filter error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Create a new group. Returns group ID.
  Future<int> createGroup({
    required String name,
    String? description,
    String groupType = 'chat',
    bool isPublic = true,
    String rideColor = '#4CAF50',
    int? maxMembers,
  }) async {
    final groupId = await _repo.createGroup(
      name: name,
      description: description,
      groupType: groupType,
      community: _community ?? 'bikergram',
      isPublic: isPublic,
      rideColor: rideColor,
      maxMembers: maxMembers,
    );

    await _silentRefresh();
    return groupId;
  }

  /// Join a group.
  Future<void> joinGroup(int groupId) async {
    await _repo.joinGroup(groupId);
    await _silentRefresh();
  }

  /// Leave a group.
  Future<void> leaveGroup(int groupId) async {
    await _repo.leaveGroup(groupId);

    // Remove from local state immediately
    state = state.copyWith(
      myGroups: state.myGroups.where((g) => g.id != groupId).toList(),
    );

    await _silentRefresh();
  }

  /// Delete a group (creator only).
  Future<void> deleteGroup(int groupId) async {
    await _repo.deleteGroup(groupId);
    state = state.copyWith(
      myGroups: state.myGroups.where((g) => g.id != groupId).toList(),
    );
  }

  /// Start a ride for a group.
  Future<void> startRide(int groupId) async {
    await _repo.startRide(groupId);
    _updateGroupInState(groupId, (g) => g.copyWith(isRideActive: true));
  }

  /// Stop a ride.
  Future<void> stopRide(int groupId) async {
    await _repo.stopRide(groupId);
    _updateGroupInState(groupId, (g) => g.copyWith(isRideActive: false));
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    await loadGroups();
  }

  // ═══════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  void _subscribeToChanges() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('groups_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'groups',
          callback: (payload) {
            _silentRefresh();
          },
        )
        .subscribe();
  }

  Future<void> _silentRefresh() async {
    try {
      final results = await Future.wait([
        _repo.getMyGroups(community: _community),
        _repo.discoverGroups(
          community: _community,
          groupType: state.selectedType,
        ),
      ]);

      state = state.copyWith(
        myGroups: results[0],
        discoverGroups: results[1],
      );
    } catch (e) {
      debugPrint('[GroupsNotifier] Silent refresh error: $e');
    }
  }

  void _updateGroupInState(
    int groupId,
    BikerGroup Function(BikerGroup) updater,
  ) {
    state = state.copyWith(
      myGroups: state.myGroups.map((g) {
        if (g.id == groupId) return updater(g);
        return g;
      }).toList(),
      discoverGroups: state.discoverGroups.map((g) {
        if (g.id == groupId) return updater(g);
        return g;
      }).toList(),
    );
  }
}
