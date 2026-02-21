import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ride_repository.dart';
import '../core/providers.dart';

class RideHistoryState {
  const RideHistoryState({
    this.rides = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
    this.stats = const {},
  });

  final List<RideRecord> rides;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;
  final Map<String, dynamic> stats;

  RideHistoryState copyWith({
    List<RideRecord>? rides,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? error,
    Map<String, dynamic>? stats,
  }) {
    return RideHistoryState(
      rides: rides ?? this.rides,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
      stats: stats ?? this.stats,
    );
  }
}

class RideHistoryNotifier extends Notifier<RideHistoryState> {
  late final RideRepository _repo;

  @override
  RideHistoryState build() {
    _repo = ref.watch(rideRepositoryProvider);
    return const RideHistoryState();
  }

  Future<void> loadRides() async {
    state = const RideHistoryState(isLoading: true);
    try {
      final rides = await _repo.getRideHistory(page: 1);
      final stats = await _repo.getRideStats();
      state = RideHistoryState(
        rides: rides,
        hasMore: rides.length >= 20,
        stats: stats,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addRide(RideRecord ride) async {
    state = state.copyWith(rides: [ride, ...state.rides]);
    // Refresh stats
    try {
      final stats = await _repo.getRideStats();
      state = state.copyWith(stats: stats);
    } catch (_) {}
  }
}

final rideHistoryNotifierProvider =
    NotifierProvider<RideHistoryNotifier, RideHistoryState>(
        RideHistoryNotifier.new);
