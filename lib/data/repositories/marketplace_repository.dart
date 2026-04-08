import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceListing {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final double? price;
  final String currency;
  final String? category;
  final String? subcategory;
  final Map<String, dynamic> attributes; // JSONB: brand, model, year, mileage, size, etc.
  final String? condition;
  final String? community;
  final List<String> images;
  final String? locationText;
  final bool isSold;
  final bool isActive;
  final String shippingType; // 'pickup', 'shipping', 'both'
  final bool isNegotiable;   // VB (Verhandlungsbasis)
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
    this.subcategory,
    this.attributes = const {},
    this.condition,
    this.community,
    this.images = const [],
    this.locationText,
    this.isSold = false,
    this.isActive = true,
    this.shippingType = 'pickup',
    this.isNegotiable = false,
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
      subcategory: json['subcategory'] as String?,
      attributes: json['attributes'] is Map<String, dynamic>
          ? json['attributes'] as Map<String, dynamic>
          : const {},
      condition: json['condition'] as String?,
      community: json['community'] as String?,
      images: images,
      locationText: json['location_text'] as String?,
      isSold: json['is_sold'] == true,
      isActive: json['is_active'] == true,
      shippingType: json['shipping_type'] as String? ?? 'pickup',
      isNegotiable: json['is_negotiable'] == true,
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

  String get shippingLabel {
    switch (shippingType) {
      case 'shipping': return 'Versand';
      case 'both': return 'Abholung & Versand';
      default: return 'Nur Abholung';
    }
  }

  // ── Attribut-Helfer ──
  String? get brand => attributes['brand'] as String?;
  String? get model => attributes['model'] as String?;
  int? get year => attributes['year'] as int?;
  int? get mileage => attributes['mileage'] as int?;
  int? get displacement => attributes['displacement'] as int?;
  int? get power => attributes['power'] as int?;
  String? get color => attributes['color'] as String?;
  String? get fuel => attributes['fuel'] as String?;
  String? get transmission => attributes['transmission'] as String?;
  String? get size => attributes['size'] as String?;
  String? get gender => attributes['gender'] as String?;
  String? get clothingBrand => attributes['clothing_brand'] as String?;
  String? get fitsBrand => attributes['fits_brand'] as String?;
  String? get fitsModel => attributes['fits_model'] as String?;

  /// Formatierter km-Stand.
  String? get mileageFormatted {
    final km = mileage;
    if (km == null) return null;
    if (km >= 1000) {
      return '${(km / 1000).toStringAsFixed(km % 1000 == 0 ? 0 : 1)} tkm';
    }
    return '$km km';
  }

  /// Kurzinfo-Text für Listing-Karten (z.B. "BMW S 1000 RR · 2023 · 5.000 km").
  String? get attributeSummary {
    final parts = <String>[];
    if (brand != null) parts.add(brand!);
    if (model != null) parts.add(model!);
    if (year != null) parts.add('$year');
    if (mileageFormatted != null) parts.add(mileageFormatted!);
    if (size != null) parts.add('Gr. $size');
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

class MarketplaceRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<MarketplaceListing>> getListings({
    int page = 1,
    int limit = 20,
    String? category,
    String? subcategory,
    String? community,
    String? search,
    String? sortBy, // 'newest', 'cheapest', 'expensive'
    double? priceMin,
    double? priceMax,
    String? shippingType, // 'shipping', 'both' (filters for versand-capable)
    String? userId, // filter by seller
    bool includeSold = false, // true = auch verkaufte Artikel zeigen
    // Attribut-Filter (JSONB)
    String? brand,
    int? yearMin,
    int? yearMax,
    int? mileageMax,
    String? size,
  }) async {
    final offset = (page - 1) * limit;

    var query = _supabase
        .from('marketplace_listings')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('is_active', true);

    // Verkaufte Artikel nur ausblenden wenn nicht explizit angefordert
    if (!includeSold) {
      query = query.eq('is_sold', false);
    }

    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      query = query.eq('subcategory', subcategory);
    }
    if (community != null) {
      query = query.eq('community', community);
    }
    if (priceMin != null) {
      query = query.gte('price', priceMin);
    }
    if (priceMax != null) {
      query = query.lte('price', priceMax);
    }
    if (shippingType != null) {
      // Filter for listings that offer shipping
      query = query.inFilter('shipping_type', ['shipping', 'both']);
    }
    if (search != null && search.isNotEmpty) {
      // Search in title and description (case-insensitive partial match)
      query = query.or('title.ilike.%$search%,description.ilike.%$search%');
    }
    // JSONB attribute filters
    if (brand != null && brand.isNotEmpty) {
      query = query.eq('attributes->>brand', brand);
    }
    if (yearMin != null) {
      query = query.gte('attributes->>year', '$yearMin');
    }
    if (yearMax != null) {
      query = query.lte('attributes->>year', '$yearMax');
    }
    if (mileageMax != null) {
      query = query.lte('attributes->>mileage', '$mileageMax');
    }
    if (size != null && size.isNotEmpty) {
      query = query.eq('attributes->>size', size);
    }

    // Sorting
    final String orderCol;
    final bool ascending;
    switch (sortBy) {
      case 'cheapest':
        orderCol = 'price';
        ascending = true;
      case 'expensive':
        orderCol = 'price';
        ascending = false;
      default: // 'newest'
        orderCol = 'created_at';
        ascending = false;
    }

    final data = await query
        .order(orderCol, ascending: ascending)
        .range(offset, offset + limit - 1);

    return data.map<MarketplaceListing>((json) =>
        MarketplaceListing.fromJson(json)).toList();
  }

  Future<MarketplaceListing> markAsSold(int id) async {
    final listing = await updateListing(id, {'is_sold': true});

    // Award 10 XP to seller for a sale
    try {
      final userId = _currentUserId;
      if (userId != null) {
        final profile = await _supabase
            .from('profiles')
            .select('xp_total, level')
            .eq('id', userId)
            .single();
        final newXp = (profile['xp_total'] as int? ?? 0) + 10;
        final newLevel = (newXp ~/ 100) + 1;
        await _supabase.from('profiles').update({
          'xp_total': newXp,
          'level': newLevel,
        }).eq('id', userId);
      }
    } catch (_) {}

    return listing;
  }

  Future<List<MarketplaceListing>> getArchivedListings({int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final data = await _supabase
        .from('marketplace_listings')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('user_id', userId)
        .eq('is_active', false)
        .order('created_at', ascending: false)
        .limit(limit);

    return data.map<MarketplaceListing>((json) =>
        MarketplaceListing.fromJson(json)).toList();
  }

  Future<MarketplaceListing> reactivateListing(int id) async {
    return updateListing(id, {'is_active': true});
  }

  Future<int> getSoldCount(String userId) async {
    final res = await _supabase
        .from('marketplace_listings')
        .select('id')
        .eq('user_id', userId)
        .eq('is_sold', true);
    debugPrint('[Marketplace] getSoldCount($userId) raw=$res count=${(res as List).length}');
    return res.length;
  }

  Future<MarketplaceListing> createListing({
    required String title,
    String? description,
    double? price,
    String? category,
    String? subcategory,
    Map<String, dynamic>? attributes,
    String? condition,
    String? community,
    List<String>? images,
    String? locationText,
    String? shippingType,
    bool? isNegotiable,
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
          if (subcategory != null) 'subcategory': subcategory,
          if (attributes != null && attributes.isNotEmpty) 'attributes': attributes,
          if (condition != null) 'condition': condition,
          if (community != null) 'community': community,
          if (images != null) 'images': images,
          if (locationText != null) 'location_text': locationText,
          if (shippingType != null) 'shipping_type': shippingType,
          if (isNegotiable != null) 'is_negotiable': isNegotiable,
        })
        .select('*, profiles!inner(username, avatar_url)')
        .single();

    return MarketplaceListing.fromJson(data);
  }

  Future<MarketplaceListing?> getListingById(int id) async {
    final data = await _supabase
        .from('marketplace_listings')
        .select('*, profiles!inner(username, avatar_url)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
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
