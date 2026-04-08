import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/marketplace_repository.dart';
import '../core/providers.dart';

class MarketplaceState {
  const MarketplaceState({
    this.listings = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.selectedCategory,
    this.sortBy = 'newest',
    this.priceMin,
    this.priceMax,
    this.shippingFilter,
    this.searchQuery,
    this.filterUserId,
    this.error,
  });

  final List<MarketplaceListing> listings;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? selectedCategory;
  final String sortBy; // 'newest', 'cheapest', 'expensive'
  final double? priceMin;
  final double? priceMax;
  final String? shippingFilter; // null = all, 'shipping' = nur versand
  final String? searchQuery;
  final String? filterUserId; // set when "Meine" is active
  final String? error;

  MarketplaceState copyWith({
    List<MarketplaceListing>? listings,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? selectedCategory,
    String? sortBy,
    double? priceMin,
    double? priceMax,
    String? shippingFilter,
    String? searchQuery,
    String? filterUserId,
    String? error,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    bool clearShippingFilter = false,
    bool clearSearchQuery = false,
    bool clearFilterUserId = false,
  }) {
    return MarketplaceState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortBy: sortBy ?? this.sortBy,
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      shippingFilter: clearShippingFilter ? null : (shippingFilter ?? this.shippingFilter),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      filterUserId: clearFilterUserId ? null : (filterUserId ?? this.filterUserId),
      error: error,
    );
  }
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  late MarketplaceRepository _repo;
  String? _community;

  @override
  MarketplaceState build() {
    _repo = ref.watch(marketplaceRepositoryProvider);
    _community = ref.watch(communityProvider)?.name;
    return const MarketplaceState();
  }

  Future<void> loadListings({
    String? category,
    String? sortBy,
    double? priceMin,
    double? priceMax,
    String? shippingFilter,
    String? userId,
    String? search,
  }) async {
    final effectiveSort = sortBy ?? state.sortBy;
    // Empty string means "clear filter"
    final effectiveCategory = category == '' ? null : (category ?? state.selectedCategory);
    final effectiveShipping = shippingFilter == '' ? null : (shippingFilter ?? state.shippingFilter);
    final effectiveUserId = userId == '' ? null : (userId ?? state.filterUserId);
    final effectivePriceMin = priceMin;
    final effectivePriceMax = priceMax;
    final effectiveSearch = search == '' ? null : (search ?? state.searchQuery);

    state = MarketplaceState(
      isLoading: true,
      selectedCategory: effectiveCategory,
      sortBy: effectiveSort,
      priceMin: effectivePriceMin,
      priceMax: effectivePriceMax,
      shippingFilter: effectiveShipping,
      searchQuery: effectiveSearch,
      filterUserId: effectiveUserId,
    );
    try {
      final listings = await _repo.getListings(
        page: 1,
        category: effectiveCategory,
        sortBy: effectiveSort,
        priceMin: effectivePriceMin,
        priceMax: effectivePriceMax,
        shippingType: effectiveShipping,
        userId: effectiveUserId,
        search: effectiveSearch,
        includeSold: effectiveUserId != null, // eigene Inserate: auch verkaufte zeigen
      );
      state = state.copyWith(
        listings: listings,
        hasMore: listings.length >= 20,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final listings = await _repo.getListings(
        page: nextPage,
        category: state.selectedCategory,
        sortBy: state.sortBy,
        priceMin: state.priceMin,
        priceMax: state.priceMax,
        shippingType: state.shippingFilter,
        userId: state.filterUserId,
        search: state.searchQuery,
        includeSold: state.filterUserId != null,
      );
      state = state.copyWith(
        listings: [...state.listings, ...listings],
        hasMore: listings.length >= 20,
        page: nextPage,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> createListing({
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
    final listing = await _repo.createListing(
      title: title,
      description: description,
      price: price,
      category: category,
      subcategory: subcategory,
      attributes: attributes,
      condition: condition,
      community: community,
      images: images,
      locationText: locationText,
      shippingType: shippingType,
      isNegotiable: isNegotiable,
    );
    state = state.copyWith(listings: [listing, ...state.listings]);
  }

  Future<void> updateListing(int id, {
    String? title,
    String? description,
    double? price,
    String? category,
    String? subcategory,
    Map<String, dynamic>? attributes,
    String? condition,
    List<String>? images,
    String? locationText,
    String? shippingType,
    bool? isNegotiable,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (subcategory != null) updates['subcategory'] = subcategory;
    if (attributes != null) updates['attributes'] = attributes;
    if (condition != null) updates['condition'] = condition;
    if (images != null) updates['images'] = images;
    if (locationText != null) updates['location_text'] = locationText;
    if (shippingType != null) updates['shipping_type'] = shippingType;
    if (isNegotiable != null) updates['is_negotiable'] = isNegotiable;

    if (updates.isEmpty) return;

    final updated = await _repo.updateListing(id, updates);
    state = state.copyWith(
      listings: state.listings
          .map((l) => l.id == id ? updated : l)
          .toList(),
    );
  }

  Future<void> archiveListing(int id) async {
    await _repo.updateListing(id, {'is_active': false});
    state = state.copyWith(
      listings: state.listings.where((l) => l.id != id).toList(),
    );
  }

  Future<void> deleteListing(int id) async {
    await _repo.deleteListing(id);
    state = state.copyWith(
      listings: state.listings.where((l) => l.id != id).toList(),
    );
  }
}

final marketplaceNotifierProvider =
    NotifierProvider<MarketplaceNotifier, MarketplaceState>(
        MarketplaceNotifier.new);
