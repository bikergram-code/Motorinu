import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/marketplace/marketplace_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/create_listing_sheet.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  int _selectedCategoryIndex = 0;

  static const _categories = [
    ('Alle', Icons.grid_view_rounded, null),
    ('Teile', Icons.settings_rounded, 'Teile'),
    ('Zubeh\u00f6r', Icons.backpack_rounded, 'Zubeh\u00f6r'),
    ('Bekleidung', Icons.checkroom_rounded, 'Bekleidung'),
    ('Fahrzeuge', Icons.two_wheeler_rounded, 'Fahrzeuge'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(marketplaceNotifierProvider.notifier).loadListings();
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

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final mpState = ref.watch(marketplaceNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

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
      body: CustomScrollView(
        slivers: [
          // Spacer for global top bar (icons are now in MainShell)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 52),
          ),

          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
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
                    label: Text(cat.$1),
                    avatar: Icon(cat.$2, size: 16),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategoryIndex = i);
                      ref
                          .read(marketplaceNotifierProvider.notifier)
                          .loadListings(category: cat.$3);
                    },
                    backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                    selectedColor: accentColor.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? accentColor
                            : Colors.white.withValues(alpha: 0.6)),
                    side: BorderSide(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
                    Text('Erstelle das erste Inserat!',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => CreateListingSheet.show(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text('Inserat erstellen',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
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
                  return _ListingCard(
                    listing: listing,
                    accentColor: accentColor,
                    cardColor: community?.cardFor(brightness),
                    isMine: isMine,
                    onOptions: isMine
                        ? () => _showListingOptions(context, listing, accentColor)
                        : null,
                  );
                },
                childCount: mpState.listings.length,
              ),
            ),
        ],
      ),
      // FAB removed — create listing is now in Speed-Dial via + button
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
  });

  final MarketplaceListing listing;
  final Color accentColor;
  final bool isMine;
  final VoidCallback? onOptions;
  final Color? cardColor;

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
          if (listing.description != null) ...[
            const SizedBox(height: 8),
            Text(listing.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (listing.condition != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(listing.conditionLabel,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5))),
                ),
              if (isMine) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Dein Inserat',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor)),
                ),
              ],
              const Spacer(),
              if (listing.sellerUsername != null)
                Flexible(
                  child: Text('@${listing.sellerUsername}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
