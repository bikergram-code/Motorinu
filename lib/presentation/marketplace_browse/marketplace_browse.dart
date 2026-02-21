import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/category_chip_widget.dart';
import './widgets/filter_modal_widget.dart';
import './widgets/product_card_widget.dart';
import './widgets/sort_bottom_sheet_widget.dart';

class MarketplaceBrowse extends StatefulWidget {
  const MarketplaceBrowse({super.key});

  @override
  State<MarketplaceBrowse> createState() => _MarketplaceBrowseState();
}

class _MarketplaceBrowseState extends State<MarketplaceBrowse> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedCategory = 'Alle';
  int _activeFilterCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Mock data for products
  final List<Map<String, dynamic>> _allProducts = [
    {
      "id": "1",
      "title": "Akrapovic Auspuffanlage",
      "price": "899.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1711561452919-131881d590a9",
      "semanticLabel":
          "Silver motorcycle exhaust system with carbon fiber tip displayed on white background",
      "sellerRating": 4.8,
      "reviewCount": 127,
      "distance": "12 km",
      "condition": "Neuwertig",
      "category": "Teile",
      "isTrustedSeller": true,
      "location": "München",
      "postedDate": "2026-01-03",
    },
    {
      "id": "2",
      "title": "Alpinestars GP Pro Lederkombi",
      "price": "1.299.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1690242724903-541d42faa233",
      "semanticLabel":
          "Black and white racing leather suit with red accents hanging on display",
      "sellerRating": 4.9,
      "reviewCount": 89,
      "distance": "8 km",
      "condition": "Gebraucht",
      "category": "Ausrüstung",
      "isTrustedSeller": false,
      "location": "Berlin",
      "postedDate": "2026-01-04",
    },
    {
      "id": "3",
      "title": "Yamaha R1 2023",
      "price": "18.500.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1734136511301-d8ffce4d1e79",
      "semanticLabel":
          "Blue and white Yamaha R1 sportbike parked on asphalt with sunset background",
      "sellerRating": 5.0,
      "reviewCount": 45,
      "distance": "25 km",
      "condition": "Neuwertig",
      "category": "Motorräder",
      "isTrustedSeller": true,
      "location": "Hamburg",
      "postedDate": "2026-01-02",
    },
    {
      "id": "4",
      "title": "Dainese Track Stiefel",
      "price": "449.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1607625770092-b8557c368fa3",
      "semanticLabel":
          "Black and red racing boots with white Dainese logo on concrete floor",
      "sellerRating": 4.7,
      "reviewCount": 156,
      "distance": "15 km",
      "condition": "Neu",
      "category": "Track-Gear",
      "isTrustedSeller": true,
      "location": "Köln",
      "postedDate": "2026-01-05",
    },
    {
      "id": "5",
      "title": "Öhlins Federbein",
      "price": "1.199.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1698170610511-f49e6c70193f",
      "semanticLabel":
          "Gold and black Öhlins rear shock absorber with adjustment knobs on white background",
      "sellerRating": 4.9,
      "reviewCount": 78,
      "distance": "18 km",
      "condition": "Neuwertig",
      "category": "Teile",
      "isTrustedSeller": false,
      "location": "Frankfurt",
      "postedDate": "2026-01-01",
    },
    {
      "id": "6",
      "title": "Shoei X-Spirit III Helm",
      "price": "699.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1663535987237-054f01256ee4",
      "semanticLabel":
          "White racing helmet with red and black graphics on display stand",
      "sellerRating": 4.8,
      "reviewCount": 203,
      "distance": "10 km",
      "condition": "Gebraucht",
      "category": "Ausrüstung",
      "isTrustedSeller": true,
      "location": "Stuttgart",
      "postedDate": "2026-01-04",
    },
    {
      "id": "7",
      "title": "Kawasaki ZX-10R 2024",
      "price": "16.900.00",
      "currency": "€",
      "image":
          "https://images.unsplash.com/photo-1686869571530-e7404a1870fb",
      "semanticLabel":
          "Green Kawasaki ZX-10R sportbike with black accents in showroom lighting",
      "sellerRating": 4.9,
      "reviewCount": 67,
      "distance": "30 km",
      "condition": "Neu",
      "category": "Motorräder",
      "isTrustedSeller": true,
      "location": "Düsseldorf",
      "postedDate": "2026-01-03",
    },
    {
      "id": "8",
      "title": "Brembo Bremsscheiben Set",
      "price": "549.00",
      "currency": "€",
      "image":
          "https://img.rocket.new/generatedImages/rocket_gen_img_1f4016f9b-1765316350783.png",
      "semanticLabel":
          "Two silver Brembo brake discs with drilled holes on black surface",
      "sellerRating": 4.7,
      "reviewCount": 134,
      "distance": "22 km",
      "condition": "Neu",
      "category": "Teile",
      "isTrustedSeller": false,
      "location": "Leipzig",
      "postedDate": "2026-01-02",
    },
  ];

  List<Map<String, dynamic>> _displayedProducts = [];

  @override
  void initState() {
    super.initState();
    _displayedProducts = List.from(_allProducts);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _displayedProducts.length < 50) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _displayedProducts.addAll(_allProducts);
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshProducts() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _displayedProducts = List.from(_allProducts);
      _isLoading = false;
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'Alle') {
        _displayedProducts = List.from(_allProducts);
      } else {
        _displayedProducts = _allProducts
            .where((product) => product['category'] == category)
            .toList();
      }
    });
  }

  void _showFilterModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterModalWidget(
        onApplyFilters: (filterCount) {
          setState(() {
            _activeFilterCount = filterCount;
          });
        },
      ),
    );
  }

  void _showSortBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SortBottomSheetWidget(
        onSortSelected: (sortOption) {
          // Apply sorting logic here
        },
      ),
    );
  }

  void _onProductTap(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/product-detail', arguments: product);
  }

  void _onSaveToWishlist(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['title']} zur Wunschliste hinzugefügt'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onShareProduct(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['title']} teilen'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onShowSimilarItems(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ähnliche Artikel zu ${product['title']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onProductLongPress(Map<String, dynamic> product) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildContextMenu(product),
    );
  }

  Widget _buildContextMenu(Map<String, dynamic> product) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 1.h),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'report',
                color: colorScheme.error,
                size: 24,
              ),
              title: Text(
                'Melden',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'visibility_off',
                color: colorScheme.onSurface,
                size: 24,
              ),
              title: Text(
                'Verkäufer ausblenden',
                style: theme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'block',
                color: colorScheme.onSurface,
                size: 24,
              ),
              title: Text('Blockieren', style: theme.textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
              },
            ),
            SizedBox(height: 1.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: CustomAppBar(
          variant: AppBarVariant.standard,
          title: 'Marktplatz',
          centerTitle: false,
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'tune',
                    color: colorScheme.onSurface,
                    size: 24,
                  ),
                  onPressed: _showFilterModal,
                  tooltip: 'Filter',
                ),
                _activeFilterCount > 0
                    ? Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _activeFilterCount.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'sort',
                color: colorScheme.onSurface,
                size: 24,
              ),
              onPressed: _showSortBottomSheet,
              tooltip: 'Sortieren',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, colorScheme),
          _buildCategoryChips(theme, colorScheme),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshProducts,
              color: colorScheme.secondary,
              child: _buildProductGrid(theme, colorScheme),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          // Navigate to sell item flow
        },
        icon: CustomIconWidget(
          iconName: 'add',
          color: colorScheme.onSecondary,
          size: 24,
        ),
        label: Text(
          'Verkaufen',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSecondary,
          ),
        ),
        backgroundColor: colorScheme.secondary,
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 3,
        onTap: (index) {
          BottomBarNavigation.navigateToIndex(context, index);
        },
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Container(
        height: 6.h,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Teile, Ausrüstung, Motorräder...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIcon: CustomIconWidget(
              iconName: 'search',
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: CustomIconWidget(
                iconName: 'mic',
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
              },
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.5.h,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme, ColorScheme colorScheme) {
    final categories = [
      {'name': 'Alle', 'icon': 'apps'},
      {'name': 'Teile', 'icon': 'build'},
      {'name': 'Ausrüstung', 'icon': 'security'},
      {'name': 'Motorräder', 'icon': 'two_wheeler'},
      {'name': 'Track-Gear', 'icon': 'speed'},
    ];

    return Container(
      height: 7.h,
      padding: EdgeInsets.symmetric(vertical: 1.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryChipWidget(
            label: category['name'] as String,
            iconName: category['icon'] as String,
            isSelected: _selectedCategory == category['name'],
            onTap: () => _onCategorySelected(category['name'] as String),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(ThemeData theme, ColorScheme colorScheme) {
    return _displayedProducts.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'inventory_2',
                  color: colorScheme.onSurfaceVariant,
                  size: 64,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Keine Produkte gefunden',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(4.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
            ),
            itemCount: _displayedProducts.length + (_isLoadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= _displayedProducts.length) {
                return _buildSkeletonCard(colorScheme);
              }

              final product = _displayedProducts[index];
              return ProductCardWidget(
                product: product,
                onTap: () => _onProductTap(product),
                onSaveToWishlist: () => _onSaveToWishlist(product),
                onShare: () => _onShareProduct(product),
                onShowSimilar: () => _onShowSimilarItems(product),
                onLongPress: () => _onProductLongPress(product),
              );
            },
          );
  }

  Widget _buildSkeletonCard(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 20.h,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(2.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 1.h),
                Container(
                  width: 20.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
