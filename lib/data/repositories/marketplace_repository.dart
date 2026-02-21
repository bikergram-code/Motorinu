import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceListing {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final double? price;
  final String currency;
  final String? category;
  final String? condition;
  final String? community;
  final List<String> images;
  final String? locationText;
  final bool isSold;
  final bool isActive;
  final DateTime? createdAt;
  // Joined profile data
  final String? sellerUsername;
  final String? sellerAvatar;

  const MarketplaceListing({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.price,
    this.currency = 'EUR',
    this.category,
    this.condition,
    this.community,
    this.images = const [],
    this.locationText,
    this.isSold = false,
    this.isActive = true,
    this.createdAt,
    this.sellerUsername,
    this.sellerAvatar,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final rawImages = json['images'];
    List<String> images = [];
    if (rawImages is List) {
      images = rawImages.map((e) => '$e').toList();
    }

    return MarketplaceListing(
      id: json['id'] as int,
      userId: '${json['user_id']}',
      title: json['title'] ?? '',
      description: json['description'] as String?,
      price: json['price'] != null ? double.tryParse('${json['price']}') : null,
      currency: json['currency'] ?? 'EUR',
      category: json['category'] as String?,
      condition: json['condition'] as String?,
      community: json['community'] as String?,
      images: images,
      locationText: json['location_text'] as String?,
      isSold: json['is_sold'] == true,
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
      sellerUsername: profile?['username'] as String?,
      sellerAvatar: profile?['avatar_url'] as String?,
    );
  }

  String get conditionLabel {
    switch (condition) {
      case 'new': return 'Neu';
      case 'like_new': return 'Wie neu';
      case 'good': return 'Gut';
      case 'fair': return 'Akzeptabel';
      case 'parts': return 'Ersatzteile';
      default: return condition ?? '';
    }
  }
}

class MarketplaceRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<MarketplaceListing>> getListings({
    int page = 1,
    int limit = 20,
    String? category,
    String? community,
    String? search,
  }) async {
    final offset = (page - 1) * limit;

    var query = _supabase
        .from('marketplace_listings')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('is_active', true);

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (community != null) {
      query = query.eq('community', community);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map<MarketplaceListing>((json) =>
        MarketplaceListing.fromJson(json)).toList();
  }

  Future<MarketplaceListing> createListing({
    required String title,
    String? description,
    double? price,
    String? category,
    String? condition,
    String? community,
    List<String>? images,
    String? locationText,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final data = await _supabase
        .from('marketplace_listings')
        .insert({
          'user_id': userId,
          'title': title,
          if (description != null) 'description': description,
          if (price != null) 'price': price,
          if (category != null) 'category': category,
          if (condition != null) 'condition': condition,
          if (community != null) 'community': community,
          if (images != null) 'images': images,
          if (locationText != null) 'location_text': locationText,
        })
        .select('*, profiles!inner(username, avatar_url)')
        .single();

    return MarketplaceListing.fromJson(data);
  }

  Future<void> deleteListing(int listingId) async {
    await _supabase.from('marketplace_listings').delete().eq('id', listingId);
  }

  Future<MarketplaceListing> updateListing(int id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    final data = await _supabase
        .from('marketplace_listings')
        .update(updates)
        .eq('id', id)
        .select('*, profiles!inner(username, avatar_url)')
        .single();

    return MarketplaceListing.fromJson(data);
  }
}
