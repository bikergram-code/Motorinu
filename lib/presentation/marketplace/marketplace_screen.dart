import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../core/marketplace_categories.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/marketplace/marketplace_notifier.dart';
import '../../theme/app_theme.dart';
import '../widgets/immersive_scroll_wrapper.dart';
import 'widgets/create_listing_sheet.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  final String? userId; // null = own marketplace
  const MarketplaceScreen({super.key, this.userId});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  int _selectedCategoryIndex = 0;
  bool _fabVisible = true;
  bool _showMineOnly = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  static final _categories = [
    (name: 'Alle', icon: Icons.grid_view_rounded, filter: null as String?),
    ...MarketplaceCategories.primaryNames.map((name) =>
        (name: name, icon: MarketplaceCategories.iconFor(name), filter: name as String?)),
    ...MarketplaceCategories.secondaryNames.map((name) =>
        (name: name, icon: MarketplaceCategories.iconFor(name), filter: name as String?)),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(marketplaceNotifierProvider.notifier).loadListings();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(marketplaceNotifierProvider.notifier).loadListings(
        search: query.isEmpty ? '' : query,
      );
    });
  }

  void _showListingOptions(BuildContext context, MarketplaceListing listing, Color accentColor) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: accentColor),
              title: Text('Bearbeiten',
                  style: GoogleFonts.inter(color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                CreateListingSheet.show(context, listing: listing);
              },
            ),
            ListTile(
              leading: Icon(Icons.archive_outlined, color: Colors.orange.shade700),
              title: Text('Archivieren',
                  style: GoogleFonts.inter(color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(marketplaceNotifierProvider.notifier).archiveListing(listing.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('„${listing.title}" archiviert'), duration: const Duration(seconds: 2)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text('L\u00f6schen',
                  style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(listing);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(MarketplaceListing listing) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Inserat l\u00f6schen?',
            style: GoogleFonts.inter(color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.w700)),
        content: Text('M\u00f6chtest du "${listing.title}" wirklich l\u00f6schen?',
            style: GoogleFonts.inter(color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(marketplaceNotifierProvider.notifier).deleteListing(listing.id);
            },
            child: Text('L\u00f6schen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context, Color accentColor, Brightness brightness, Color? cardColor) {
    final isDark = brightness == Brightness.dark;
    final bg = cardColor ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Sortierung', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 16),
            for (final opt in [('Neueste', 'newest'), ('Günstigste', 'cheapest'), ('Teuerste', 'expensive')])
              ListTile(
                title: Text(opt.$1, style: TextStyle(color: textColor)),
                leading: Icon(
                  opt.$2 == 'newest' ? Icons.access_time_rounded
                      : opt.$2 == 'cheapest' ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: accentColor,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(marketplaceNotifierProvider.notifier).loadListings(sortBy: opt.$2);
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _showPriceSheet(BuildContext context, Color accentColor, Brightness brightness, Color? cardColor) {
    final isDark = brightness == Brightness.dark;
    final bg = cardColor ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    final mpState = ref.read(marketplaceNotifierProvider);
    if (mpState.priceMin != null) minCtrl.text = mpState.priceMin!.toInt().toString();
    if (mpState.priceMax != null) maxCtrl.text = mpState.priceMax!.toInt().toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Preisbereich', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Min €',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Max €',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(marketplaceNotifierProvider.notifier).loadListings(
                  priceMin: null, priceMax: null,
                );
              },
              style: OutlinedButton.styleFrom(side: BorderSide(color: textColor.withValues(alpha: 0.3))),
              child: Text('Zurücksetzen', style: TextStyle(color: textColor)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(marketplaceNotifierProvider.notifier).loadListings(
                  priceMin: double.tryParse(minCtrl.text),
                  priceMax: double.tryParse(maxCtrl.text),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Anwenden', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final mpState = ref.watch(marketplaceNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Marktplatz is community-independent (shows all listings)

    // Re-register Speed-Dial items every build (ensures they persist after tab switches)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/market') {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.sell_rounded,
            label: 'Neues Inserat',
            color: Colors.teal,
            onTap: () { if (!mounted) return; CreateListingSheet.show(context); },
          ),
        ]);
      });
    }

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 38),
        child: AnimatedScale(
          scale: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            backgroundColor: accentColor,
            onPressed: () => CreateListingSheet.show(context),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ),
      body: ImmersiveScrollWrapper(child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            if (_fabVisible) setState(() => _fabVisible = false);
          } else if (notification is ScrollEndNotification) {
            if (!_fabVisible) setState(() => _fabVisible = true);
          }
          return false;
        },
        child: CustomScrollView(
        slivers: [
          // Spacer for global top bar (icons are now in MainShell)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 50),
          ),

          // Screen title with back button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_rounded, size: 22,
                      color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Text('Marktplatz', style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                  )),
                  const Spacer(),
                  ActionChip(
                    label: Text(
                      'Meine',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showMineOnly ? Colors.white : (brightness == Brightness.dark ? Colors.white70 : const Color(0xFF6C757D)),
                      ),
                    ),
                    avatar: Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: _showMineOnly ? Colors.white : accentColor,
                    ),
                    backgroundColor: _showMineOnly ? accentColor : (community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white)),
                    side: BorderSide(color: _showMineOnly ? accentColor : (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1))),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      setState(() => _showMineOnly = !_showMineOnly);
                      if (_showMineOnly) {
                        ref.read(marketplaceNotifierProvider.notifier).loadListings(
                          userId: currentUserId,
                        );
                      } else {
                        // Zurück zu allen — userId explizit leeren
                        ref.read(marketplaceNotifierProvider.notifier).loadListings(
                          userId: '',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Suche nach Teilen, Zubeh\u00f6r...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF6C757D)),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D), size: 22),
                  filled: true,
                  fillColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Categories
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = i == _selectedCategoryIndex;
                  return FilterChip(
                    label: Text(cat.name),
                    avatar: Icon(cat.icon, size: 16),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategoryIndex = i);
                      ref
                          .read(marketplaceNotifierProvider.notifier)
                          .loadListings(category: cat.filter ?? '', userId: _showMineOnly ? currentUserId : null);
                    },
                    backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                    selectedColor: accentColor.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? accentColor
                            : brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.6)),
                    side: BorderSide(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.3)
                            : brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.12)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ),

          // Filter row: Sort + Price + Shipping
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                // Sort
                _FilterButton(
                  label: mpState.sortBy == 'cheapest' ? 'Günstigste'
                       : mpState.sortBy == 'expensive' ? 'Teuerste'
                       : 'Neueste',
                  icon: Icons.sort_rounded,
                  isActive: mpState.sortBy != 'newest',
                  accentColor: accentColor,
                  brightness: brightness,
                  cardColor: community?.cardFor(brightness),
                  onTap: () => _showSortSheet(context, accentColor, brightness, community?.cardFor(brightness)),
                ),
                const SizedBox(width: 8),
                // Price
                _FilterButton(
                  label: mpState.priceMin != null || mpState.priceMax != null
                      ? '${mpState.priceMin?.toInt() ?? 0}–${mpState.priceMax?.toInt() ?? '∞'} €'
                      : 'Preis',
                  icon: Icons.euro_rounded,
                  isActive: mpState.priceMin != null || mpState.priceMax != null,
                  accentColor: accentColor,
                  brightness: brightness,
                  cardColor: community?.cardFor(brightness),
                  onTap: () => _showPriceSheet(context, accentColor, brightness, community?.cardFor(brightness)),
                ),
                const SizedBox(width: 8),
                // Shipping
                _FilterButton(
                  label: 'Versand',
                  icon: Icons.local_shipping_rounded,
                  isActive: mpState.shippingFilter != null,
                  accentColor: accentColor,
                  brightness: brightness,
                  cardColor: community?.cardFor(brightness),
                  onTap: () {
                    final notifier = ref.read(marketplaceNotifierProvider.notifier);
                    if (mpState.shippingFilter != null) {
                      // Clear filter — need to reset state then reload
                      notifier.loadListings(shippingFilter: '');
                    } else {
                      notifier.loadListings(shippingFilter: 'shipping');
                    }
                  },
                ),
              ]),
            ),
          ),

          if (mpState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (mpState.listings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: Icon(Icons.storefront_outlined,
                          size: 36,
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    const SizedBox(height: 20),
                    Text('Noch keine Inserate',
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
                    const SizedBox(height: 8),
                    Text('Tippe auf + um ein Inserat zu erstellen',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D))),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final listing = mpState.listings[index];
                  final isMine = listing.userId == currentUserId;
                  final card = GestureDetector(
                    onTap: () => context.push('/listing/${listing.id}'),
                    onLongPress: isMine
                        ? () => _showListingOptions(context, listing, accentColor)
                        : null,
                    child: _ListingCard(
                      listing: listing,
                      accentColor: accentColor,
                      cardColor: community?.cardFor(brightness),
                      isMine: isMine,
                      onOptions: isMine
                          ? () => _showListingOptions(context, listing, accentColor)
                          : null,
                      onMessage: isMine ? null : () async {
                        final repo = MessageRepository();
                        final convId = await repo.getOrCreateConversation(listing.userId);
                        if (context.mounted) context.push('/messages/$convId');
                      },
                    ),
                  );
                  if (!isMine) return card;
                  return Dismissible(
                    key: ValueKey('listing_${listing.id}'),
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.archive_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text('Archivieren', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Löschen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Swipe right → Archive
                        ref.read(marketplaceNotifierProvider.notifier).archiveListing(listing.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('„${listing.title}" archiviert'), duration: const Duration(seconds: 2)),
                          );
                        }
                        return true;
                      } else {
                        // Swipe left → Delete (with confirmation)
                        _confirmDelete(listing);
                        return false;
                      }
                    },
                    child: card,
                  );
                },
                childCount: mpState.listings.length,
              ),
            ),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      )),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.accentColor,
    this.isMine = false,
    this.onOptions,
    this.cardColor,
    this.onMessage,
  });

  final MarketplaceListing listing;
  final Color accentColor;
  final bool isMine;
  final VoidCallback? onOptions;
  final Color? cardColor;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (listing.images.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(listing.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: Icon(Icons.image_outlined,
                                  size: 40,
                                  color: Colors.white.withValues(alpha: 0.15)),
                            )),
                  ),
                ),
                // Top-left badges: VERKAUFT or NEU
                if (listing.isSold)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('VERKAUFT', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  )
                else if (listing.createdAt != null &&
                    DateTime.now().difference(listing.createdAt!).inHours < 48)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('NEU', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                // Top-right: VB badge
                if (listing.isNegotiable)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('VB', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                // Bottom-left: Dein Inserat badge (on image)
                if (isMine)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Dein Inserat', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),

          // Title row with options for own listings
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(listing.title,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
              ),
              if (isMine && onOptions != null)
                GestureDetector(
                  onTap: onOptions,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.more_vert_rounded,
                        color: Colors.white.withValues(alpha: 0.4), size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (listing.price != null)
            Text(
                '${listing.price!.toStringAsFixed(2)} ${listing.currency}',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accentColor)),
          // Attribute-Kurzinfo (z.B. "Ducati · Monster 821 · 2020 · 12 tkm")
          if (listing.attributeSummary != null) ...[
            const SizedBox(height: 6),
            Text(listing.attributeSummary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accentColor.withValues(alpha: 0.8))),
          ],
          if (listing.description != null) ...[
            const SizedBox(height: 6),
            Text(listing.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
          ],
          const SizedBox(height: 8),
          // Chips row: Condition + Versand + Seller
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (listing.condition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(listing.conditionLabel,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF6C757D))),
                ),
              if (listing.shippingType != 'pickup')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 11, color: Colors.blue.shade300),
                      const SizedBox(width: 4),
                      Text('Versand', style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.blue.shade300)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Seller + message row
          Row(
            children: [
              const Spacer(),
              if (listing.sellerUsername != null)
                GestureDetector(
                  onTap: () => GoRouter.of(context).push('/profile/${listing.userId}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14,
                          color: brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.35)
                              : const Color(0xFF9E9E9E)),
                      const SizedBox(width: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(listing.sellerUsername!,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : const Color(0xFF6C757D))),
                      ),
                    ],
                  ),
                ),
              if (!isMine && !listing.isSold)
                GestureDetector(
                  onTap: () => GoRouter.of(context).push('/messages'),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: accentColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.accentColor,
    required this.brightness,
    required this.onTap,
    this.cardColor,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color accentColor;
  final Brightness brightness;
  final VoidCallback onTap;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.12)
              : (cardColor ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.4)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? accentColor : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? accentColor : (isDark ? Colors.white54 : Colors.black54),
          )),
        ]),
      ),
    );
  }
}
