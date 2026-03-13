import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import '../../data/repositories/group_repository.dart';
import '../../services/live_location_service.dart';
import '../map/live_location_provider.dart';
import '../core/providers.dart';

// ═══════════════════════════════════════════════════
//  GROUP DETAIL STATE
// ═══════════════════════════════════════════════════

class GroupDetailState {
  const GroupDetailState({
    this.group,
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  final BikerGroup? group;
  final List<GroupMember> members;
  final bool isLoading;
  final String? error;

  GroupDetailState copyWith({
    BikerGroup? group,
    List<GroupMember>? members,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GroupDetailState(
      group: group ?? this.group,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ═══════════════════════════════════════════════════
//  GROUP DETAIL NOTIFIER (family by groupId)
// ═══════════════════════════════════════════════════

final groupDetailProvider = NotifierProvider.family<GroupDetailNotifier,
    GroupDetailState, int>(GroupDetailNotifier.new);

class GroupDetailNotifier extends Notifier<GroupDetailState> {
  GroupDetailNotifier(this._groupId);

  final int _groupId;
  late GroupRepository _repo;

  @override
  GroupDetailState build() {
    _repo = ref.watch(groupRepositoryProvider);
    Future.microtask(() => load());
    return const GroupDetailState(isLoading: true);
  }

  int get groupId => _groupId;

  /// Load group details + members.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _repo.getGroupById(groupId),
        _repo.getGroupMembers(groupId),
      ]);

      state = state.copyWith(
        group: results[0] as BikerGroup?,
        members: results[1] as List<GroupMember>,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[GroupDetail] Load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Fehler beim Laden der Gruppe',
      );
    }
  }

  /// Join this group.
  Future<void> join() async {
    try {
      await _repo.joinGroup(groupId);
      await load(); // reload to get updated membership
    } catch (e) {
      debugPrint('[GroupDetail] Join error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Leave this group.
  Future<void> leave() async {
    try {
      await _repo.leaveGroup(groupId);
      await load();
    } catch (e) {
      debugPrint('[GroupDetail] Leave error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Start ride (admin only).
  /// Activates group ride in DB AND starts live GPS broadcasting with group color.
  Future<void> startRide() async {
    await _repo.startRide(groupId);
    state = state.copyWith(
      group: state.group?.copyWith(isRideActive: true),
    );

    // Connect GPS to group ride — set group affiliation for presence broadcast
    final rideColor = state.group?.rideColor ?? '#4CAF50';
    final liveService = globalLiveLocationService;
    liveService.setActiveGroup(groupId, rideColor, isLeader: true);

    // If GPS already broadcasting, the group color will be applied on next heartbeat.
    // If not broadcasting, the ActiveRideBanner in the UI will prompt the user to join.
    if (liveService.isLive) {
      debugPrint('[GroupDetail] GPS already live — group ride $groupId attached');
    } else {
      debugPrint('[GroupDetail] GPS not active — user will see "Beitreten" banner');
    }
  }

  /// Stop ride.
  /// Deactivates group ride in DB AND clears group from GPS broadcast.
  Future<void> stopRide() async {
    await _repo.stopRide(groupId);
    state = state.copyWith(
      group: state.group?.copyWith(isRideActive: false),
    );

    // Disconnect GPS from group ride (keep GPS on, just remove group affiliation)
    globalLiveLocationService.setActiveGroup(null, null);
  }

  /// Refresh.
  Future<void> refresh() async {
    await load();
  }
}
