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

  Future<void> loadVehicles({String? userId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vehicles = await _repo.getMyVehicles(community: _community, userId: userId);
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
    String? description,
    String? imageUrl,
    List<String>? images,
    String? community,
    int? mileage,
    String? fuel,
    String? transmission,
    String? color,
    String? tuevDate,
  }) async {
    final vehicle = await _repo.addVehicle(
      brand: brand,
      model: model,
      year: year,
      displacementCc: displacementCc,
      horsepower: horsepower,
      category: category,
      description: description,
      imageUrl: imageUrl,
      images: images,
      community: community,
      mileage: mileage,
      fuel: fuel,
      transmission: transmission,
      color: color,
      tuevDate: tuevDate,
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
    String? description,
    String? imageUrl,
    List<String>? images,
    int? mileage,
    String? fuel,
    String? transmission,
    String? color,
    String? tuevDate,
    bool clearMileage = false,
    bool clearFuel = false,
    bool clearTransmission = false,
    bool clearColor = false,
    bool clearTuev = false,
  }) async {
    final updates = <String, dynamic>{};
    if (brand != null) updates['brand'] = brand;
    if (model != null) updates['model'] = model;
    if (year != null) updates['year'] = year;
    if (displacementCc != null) updates['displacement_cc'] = displacementCc;
    if (horsepower != null) updates['horsepower'] = horsepower;
    if (category != null) updates['category'] = category;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (images != null) updates['images'] = images;
    if (mileage != null) updates['mileage'] = mileage;
    if (fuel != null) updates['fuel'] = fuel;
    if (transmission != null) updates['transmission'] = transmission;
    if (color != null) updates['color'] = color;
    if (tuevDate != null) updates['tuev_date'] = tuevDate;
    // Allow explicit clearing of optional fields
    if (clearMileage) updates['mileage'] = null;
    if (clearFuel) updates['fuel'] = null;
    if (clearTransmission) updates['transmission'] = null;
    if (clearColor) updates['color'] = null;
    if (clearTuev) updates['tuev_date'] = null;

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
