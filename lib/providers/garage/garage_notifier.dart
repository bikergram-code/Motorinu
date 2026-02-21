import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vehicle_repository.dart';
import '../core/providers.dart';

class GarageState {
  const GarageState({
    this.vehicles = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Vehicle> vehicles;
  final bool isLoading;
  final String? error;

  GarageState copyWith({
    List<Vehicle>? vehicles,
    bool? isLoading,
    String? error,
  }) {
    return GarageState(
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GarageNotifier extends Notifier<GarageState> {
  late VehicleRepository _repo;
  String? _community;

  @override
  GarageState build() {
    _repo = ref.watch(vehicleRepositoryProvider);
    _community = ref.watch(communityProvider)?.name;
    return const GarageState();
  }

  Future<void> loadVehicles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vehicles = await _repo.getMyVehicles(community: _community);
      state = GarageState(vehicles: vehicles);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addVehicle({
    required String brand,
    required String model,
    int? year,
    int? displacementCc,
    int? horsepower,
    String? category,
    String? imageUrl,
    String? community,
  }) async {
    final vehicle = await _repo.addVehicle(
      brand: brand,
      model: model,
      year: year,
      displacementCc: displacementCc,
      horsepower: horsepower,
      category: category,
      imageUrl: imageUrl,
      community: community,
    );
    state = state.copyWith(vehicles: [vehicle, ...state.vehicles]);
  }

  Future<void> updateVehicle(int vehicleId, {
    String? brand,
    String? model,
    int? year,
    int? displacementCc,
    int? horsepower,
    String? category,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (brand != null) updates['brand'] = brand;
    if (model != null) updates['model'] = model;
    if (year != null) updates['year'] = year;
    if (displacementCc != null) updates['displacement_cc'] = displacementCc;
    if (horsepower != null) updates['horsepower'] = horsepower;
    if (category != null) updates['category'] = category;
    if (imageUrl != null) updates['image_url'] = imageUrl;

    if (updates.isEmpty) return;

    final updated = await _repo.updateVehicle(vehicleId, updates);
    state = state.copyWith(
      vehicles: state.vehicles
          .map((v) => v.id == vehicleId ? updated : v)
          .toList(),
    );
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await _repo.deleteVehicle(vehicleId);
    state = state.copyWith(
      vehicles: state.vehicles.where((v) => v.id != vehicleId).toList(),
    );
  }
}

final garageNotifierProvider =
    NotifierProvider<GarageNotifier, GarageState>(GarageNotifier.new);
