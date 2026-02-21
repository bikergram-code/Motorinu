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
    this.error,
  });

  final List<MarketplaceListing> listings;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? selectedCategory;
  final String? error;

  MarketplaceState copyWith({
    List<MarketplaceListing>? listings,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? selectedCategory,
    String? error,
  }) {
    return MarketplaceState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      selectedCategory: selectedCategory ?? this.selectedCategory,
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

  Future<void> loadListings({String? category}) async {
    state = MarketplaceState(
      isLoading: true,
      selectedCategory: category,
    );
    try {
      final listings = await _repo.getListings(
        page: 1,
        category: category,
        community: _community,
      );
      state = MarketplaceState(
        listings: listings,
        hasMore: listings.length >= 20,
        selectedCategory: category,
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
        community: _community,
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
    String? condition,
    String? community,
    List<String>? images,
    String? locationText,
  }) async {
    final listing = await _repo.createListing(
      title: title,
      description: description,
      price: price,
      category: category,
      condition: condition,
      community: community,
      images: images,
      locationText: locationText,
    );
    state = state.copyWith(listings: [listing, ...state.listings]);
  }

  Future<void> updateListing(int id, {
    String? title,
    String? description,
    double? price,
    String? category,
    String? condition,
    List<String>? images,
    String? locationText,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (condition != null) updates['condition'] = condition;
    if (images != null) updates['images'] = images;
    if (locationText != null) updates['location_text'] = locationText;

    if (updates.isEmpty) return;

    final updated = await _repo.updateListing(id, updates);
    state = state.copyWith(
      listings: state.listings
          .map((l) => l.id == id ? updated : l)
          .toList(),
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
