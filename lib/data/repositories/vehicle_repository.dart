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
  final String? description;
  final String? imageUrl;
  final List<String> images;
  final bool isPrimary;
  final bool forSale;
  final double? price;
  final int? mileage;
  final String? fuel;
  final String? transmission;
  final String? color;
  final String? tuevDate; // "MM/YYYY" format
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
    this.description,
    this.imageUrl,
    this.images = const [],
    this.isPrimary = false,
    this.forSale = false,
    this.price,
    this.mileage,
    this.fuel,
    this.transmission,
    this.color,
    this.tuevDate,
    this.createdAt,
  });

  /// All available image URLs (images array + legacy imageUrl fallback)
  List<String> get allImages {
    if (images.isNotEmpty) return images;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return [];
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final imagesList = rawImages is List
        ? rawImages.map((e) => '$e').where((s) => s.isNotEmpty).toList()
        : <String>[];
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
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      images: imagesList,
      isPrimary: json['is_primary'] == true,
      forSale: json['for_sale'] == true,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      mileage: json['mileage'] as int?,
      fuel: json['fuel'] as String?,
      transmission: json['transmission'] as String?,
      color: json['color'] as String?,
      tuevDate: json['tuev_date'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }
}

class VehicleOffer {
  final int id;
  final int vehicleId;
  final String senderId;
  final String ownerId;
  final double amount;
  final String? message;
  final String status; // pending, accepted, declined, countered
  final int? parentOfferId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Joined vehicle info (optional)
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleImageUrl;

  const VehicleOffer({
    required this.id,
    required this.vehicleId,
    required this.senderId,
    required this.ownerId,
    required this.amount,
    this.message,
    this.status = 'pending',
    this.parentOfferId,
    required this.createdAt,
    this.updatedAt,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleImageUrl,
  });

  factory VehicleOffer.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicles'] as Map<String, dynamic>?;
    return VehicleOffer(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      senderId: '${json['sender_id']}',
      ownerId: '${json['owner_id']}',
      amount: (json['amount'] as num).toDouble(),
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      parentOfferId: json['parent_offer_id'] as int?,
      createdAt: DateTime.parse('${json['created_at']}'),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse('${json['updated_at']}') : null,
      vehicleBrand: vehicle?['brand'] as String?,
      vehicleModel: vehicle?['model'] as String?,
      vehicleImageUrl: vehicle?['image_url'] as String?,
    );
  }

  String get statusLabel => switch (status) {
    'pending' => 'Ausstehend',
    'accepted' => 'Angenommen',
    'declined' => 'Abgelehnt',
    'countered' => 'Gegenangebot',
    _ => status,
  };

  bool get isPending => status == 'pending';
}

class VehicleRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Vehicle>> getMyVehicles({String? community, String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return [];

    var query = _supabase
        .from('vehicles')
        .select()
        .eq('user_id', uid);

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
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    // Use first image as image_url for backward compat
    final effectiveImageUrl = imageUrl ?? (images != null && images.isNotEmpty ? images.first : null);

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
          if (effectiveImageUrl != null) 'image_url': effectiveImageUrl,
          if (images != null) 'images': images,
          if (community != null) 'community': community,
          if (description != null) 'description': description,
          if (mileage != null) 'mileage': mileage,
          if (fuel != null) 'fuel': fuel,
          if (transmission != null) 'transmission': transmission,
          if (color != null) 'color': color,
          if (tuevDate != null) 'tuev_date': tuevDate,
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

  // ─── Vehicle Likes ─────────────────────────────────────────────────

  /// Check if current user liked a vehicle.
  Future<bool> hasLiked(int vehicleId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    final data = await _supabase
        .from('vehicle_likes')
        .select('id')
        .eq('vehicle_id', vehicleId)
        .eq('user_id', uid)
        .maybeSingle();
    return data != null;
  }

  /// Get like count for a vehicle.
  Future<int> getLikeCount(int vehicleId) async {
    final data = await _supabase
        .from('vehicle_likes')
        .select('id')
        .eq('vehicle_id', vehicleId);
    return (data as List).length;
  }

  /// Like a vehicle.
  Future<void> likeVehicle(int vehicleId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _supabase.from('vehicle_likes').upsert({
      'vehicle_id': vehicleId,
      'user_id': uid,
    }, onConflict: 'vehicle_id,user_id');
  }

  /// Unlike a vehicle.
  Future<void> unlikeVehicle(int vehicleId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _supabase
        .from('vehicle_likes')
        .delete()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', uid);
  }

  // ─── Vehicle Offers (Kleinanzeigen-style) ─────────────────────────

  /// Send an offer for a vehicle.
  Future<VehicleOffer> sendOffer({
    required int vehicleId,
    required String ownerId,
    required double amount,
    String? message,
    int? parentOfferId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Nicht eingeloggt');
    final data = await _supabase
        .from('vehicle_offers')
        .insert({
          'vehicle_id': vehicleId,
          'sender_id': uid,
          'owner_id': ownerId,
          'amount': amount,
          if (message != null) 'message': message,
          'status': 'pending',
          if (parentOfferId != null) 'parent_offer_id': parentOfferId,
        })
        .select()
        .single();
    return VehicleOffer.fromJson(data);
  }

  /// Get all offers for a specific vehicle (owner view).
  Future<List<VehicleOffer>> getOffersForVehicle(int vehicleId) async {
    final data = await _supabase
        .from('vehicle_offers')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => VehicleOffer.fromJson(j)).toList();
  }

  /// Get all offers the current user has received (as vehicle owner).
  Future<List<VehicleOffer>> getReceivedOffers() async {
    final uid = _currentUserId;
    if (uid == null) return [];
    final data = await _supabase
        .from('vehicle_offers')
        .select('*, vehicles(brand, model, image_url)')
        .eq('owner_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((j) => VehicleOffer.fromJson(j)).toList();
  }

  /// Get all offers the current user has sent.
  Future<List<VehicleOffer>> getSentOffers() async {
    final uid = _currentUserId;
    if (uid == null) return [];
    final data = await _supabase
        .from('vehicle_offers')
        .select('*, vehicles(brand, model, image_url)')
        .eq('sender_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((j) => VehicleOffer.fromJson(j)).toList();
  }

  /// Accept an offer.
  Future<void> acceptOffer(int offerId) async {
    await _supabase
        .from('vehicle_offers')
        .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', offerId);
  }

  /// Decline an offer.
  Future<void> declineOffer(int offerId) async {
    await _supabase
        .from('vehicle_offers')
        .update({'status': 'declined', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', offerId);
  }

  /// Counter an offer (marks old as 'countered', creates new offer in opposite direction).
  Future<VehicleOffer> counterOffer({
    required int originalOfferId,
    required int vehicleId,
    required String recipientId,
    required double amount,
    String? message,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Nicht eingeloggt');

    // Mark original as countered
    await _supabase
        .from('vehicle_offers')
        .update({'status': 'countered', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', originalOfferId);

    // Create counter-offer
    final data = await _supabase
        .from('vehicle_offers')
        .insert({
          'vehicle_id': vehicleId,
          'sender_id': uid,
          'owner_id': recipientId,
          'amount': amount,
          if (message != null) 'message': message,
          'status': 'pending',
          'parent_offer_id': originalOfferId,
        })
        .select()
        .single();
    return VehicleOffer.fromJson(data);
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
