import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Vehicle {
  final int id;
  final String userId;
  final String community;
  final String brand;
  final String model;
  final int? year;
  final int? displacementCc;
  final int? horsepower;
  final String? category;
  final String? imageUrl;
  final bool isPrimary;
  final DateTime? createdAt;

  const Vehicle({
    required this.id,
    required this.userId,
    this.community = 'bikergram',
    required this.brand,
    required this.model,
    this.year,
    this.displacementCc,
    this.horsepower,
    this.category,
    this.imageUrl,
    this.isPrimary = false,
    this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      userId: '${json['user_id']}',
      community: json['community'] ?? 'bikergram',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] as int?,
      displacementCc: json['displacement_cc'] as int?,
      horsepower: json['horsepower'] as int?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      isPrimary: json['is_primary'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }
}

class VehicleRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Vehicle>> getMyVehicles({String? community}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    var query = _supabase
        .from('vehicles')
        .select()
        .eq('user_id', userId);

    if (community != null) {
      query = query.eq('community', community);
    }

    final data = await query
        .order('is_primary', ascending: false)
        .order('created_at', ascending: false);

    return data.map<Vehicle>((json) => Vehicle.fromJson(json)).toList();
  }

  Future<Vehicle> addVehicle({
    required String brand,
    required String model,
    int? year,
    int? displacementCc,
    int? horsepower,
    String? category,
    String? imageUrl,
    String? community,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final data = await _supabase
        .from('vehicles')
        .insert({
          'user_id': userId,
          'brand': brand,
          'model': model,
          if (year != null) 'year': year,
          if (displacementCc != null) 'displacement_cc': displacementCc,
          if (horsepower != null) 'horsepower': horsepower,
          if (category != null) 'category': category,
          if (imageUrl != null) 'image_url': imageUrl,
          if (community != null) 'community': community,
        })
        .select()
        .single();

    return Vehicle.fromJson(data);
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await _supabase.from('vehicles').delete().eq('id', vehicleId);
  }

  Future<Vehicle> updateVehicle(int vehicleId, Map<String, dynamic> updates) async {
    final data = await _supabase
        .from('vehicles')
        .update(updates)
        .eq('id', vehicleId)
        .select()
        .single();

    return Vehicle.fromJson(data);
  }

  /// Upload a vehicle image and return the public URL.
  Future<String> uploadVehicleImage(Uint8List bytes, String fileName) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = fileName.split('.').last.toLowerCase();
    final path = 'vehicles/$userId/${timestamp}_vehicle.$ext';

    await _supabase.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );

    final url = _supabase.storage.from('posts').getPublicUrl(path);
    debugPrint('[Garage] Uploaded vehicle image: $url');
    return url;
  }
}
