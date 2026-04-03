import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/marketplace/marketplace_notifier.dart';
import '../../domain/commission_calculator.dart';
import '../../theme/app_theme.dart';
import 'widgets/create_listing_sheet.dart';

class MarketplaceDetailScreen extends ConsumerStatefulWidget {
  final int listingId;
  final MarketplaceListing? listing; // Optional: pass directly to avoid re-fetch

  const MarketplaceDetailScreen({super.key, required this.listingId, this.listing});

  @override
  ConsumerState<MarketplaceDetailScreen> createState() => _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends ConsumerState<MarketplaceDetailScreen> {
  MarketplaceListing? _listing;
  bool _isLoading = true;
  int _currentImageIndex = 0;
  final _pageController = PageController();

  bool get _isOwn {
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated && _listing != null) {
      return authState.user.id == _listing!.userId;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) {
      _listing = widget.listing;
      _isLoading = false;
    } else {
      _loadListing();
    }
  }

  Future<void> _loadListing() async {
    final repo = MarketplaceRepository();
    final listing = await repo.getListingById(widget.listingId);
    if (mounted) setState(() { _listing = listing; _isLoading = false; });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_listing == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
        ),
        body: const Center(child: Text('Inserat nicht gefunden')),
      );
    }

    final listing = _listing!;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white54 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero Image ──
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Share
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: listing.images.isNotEmpty
                  ? Stack(children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: listing.images.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (_, i) => Image.network(
                          listing.images[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                            child: Icon(Icons.image_not_supported_outlined, color: mutedColor, size: 48),
                          ),
                        ),
                      ),
                      // VERKAUFT Banner
                      if (listing.isSold)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('VERKAUFT', style: GoogleFonts.inter(
                                    fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
                                    letterSpacing: 2,
                                  )),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Page dots
                      if (listing.images.length > 1)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(listing.images.length, (i) => Container(
                              width: i == _currentImageIndex ? 10 : 7,
                              height: i == _currentImageIndex ? 10 : 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentImageIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                              ),
                            )),
                          ),
                        ),
                    ])
                  : Container(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                      child: Icon(Icons.storefront_outlined, color: mutedColor, size: 64),
                    ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title
                Text(listing.title, style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.w800, color: textColor,
                )),
                const SizedBox(height: 8),

                // Price + VB badge
                if (listing.price != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${listing.price!.toStringAsFixed(0)} ${listing.currency}',
                        style: GoogleFonts.inter(
                          fontSize: 28, fontWeight: FontWeight.w900, color: accentColor,
                        ),
                      ),
                      if (listing.isNegotiable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('VB', style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade700,
                          )),
                        ),
                      ],
                    ],
                  )
                else
                  Text('Preis auf Anfrage', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: mutedColor, fontStyle: FontStyle.italic,
                  )),
                const SizedBox(height: 16),

                // Info chips
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (listing.condition != null)
                    _chip(listing.conditionLabel, Icons.star_rounded, accentColor, isDark),
                  if (listing.category != null)
                    _chip(listing.category!, Icons.category_rounded, accentColor, isDark),
                  if (listing.locationText != null)
                    _chip(listing.locationText!, Icons.location_on_rounded, accentColor, isDark),
                  _chip(listing.shippingLabel, Icons.local_shipping_rounded, Colors.blue, isDark),
                  if (listing.isSold)
                    _chip('Verkauft', Icons.check_circle, Colors.green, isDark),
                  if (listing.createdAt != null)
                    _chip(_formatDate(listing.createdAt!), Icons.schedule_rounded, accentColor, isDark),
                ]),
                const SizedBox(height: 20),

                // Description
                if (listing.description != null && listing.description!.isNotEmpty) ...[
                  Text('Beschreibung', style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: textColor,
                  )),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                    ),
                    child: Text(listing.description!, style: TextStyle(
                      color: textColor, fontSize: 15, height: 1.5,
                    )),
                  ),
                  const SizedBox(height: 20),
                ],

                // Seller info
                Text('Verkäufer', style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: textColor,
                )),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/profile/${listing.userId}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: accentColor.withValues(alpha: 0.2),
                        backgroundImage: listing.sellerAvatar != null
                            ? NetworkImage(listing.sellerAvatar!)
                            : null,
                        child: listing.sellerAvatar == null
                            ? Text(
                                (listing.sellerUsername ?? '?')[0].toUpperCase(),
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.sellerUsername ?? 'Unbekannt',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Text('Profil anzeigen', style: TextStyle(color: accentColor, fontSize: 13)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: mutedColor),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                if (!_isOwn) ...[
                  // Sofort kaufen (only if price set and not sold)
                  if (listing.price != null && !listing.isSold) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _directBuy(listing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.shopping_cart_rounded, size: 22),
                        label: Text('Sofort kaufen · ${listing.price!.toStringAsFixed(0)} €',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Message seller
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: listing.isSold ? null : () => _messageSeller(listing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accentColor.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('Nachricht senden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Make offer
                  if (listing.price != null && !listing.isSold)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _makeOffer(listing),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.local_offer_rounded, size: 20, color: accentColor),
                        label: Text('Angebot machen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accentColor)),
                      ),
                    ),
                ] else ...[
                  // ── Owner Settings Section ──
                  Text('Inserat-Einstellungen', style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: textColor,
                  )),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                    ),
                    child: Column(children: [
                      // Als verkauft markieren — mit Provision
                      _settingsRow(
                        icon: Icons.check_circle_rounded,
                        label: 'Als verkauft markieren',
                        color: Colors.green,
                        textColor: textColor,
                        trailing: Switch.adaptive(
                          value: listing.isSold,
                          activeColor: Colors.green,
                          onChanged: (v) async {
                            if (v) {
                              // Show commission confirmation before marking as sold
                              final confirmed = await _showCommissionDialog(listing.price);
                              if (confirmed != true) return;
                            }
                            final repo = MarketplaceRepository();
                            final updated = await repo.updateListing(listing.id, {'is_sold': v});
                            if (v) {
                              // Record transaction for bookkeeping
                              _recordTransaction(listing.id, listing.price, listing.userId);
                            }
                            setState(() => _listing = updated);
                          },
                        ),
                      ),
                      // Commission info (only when not sold)
                      if (!listing.isSold && listing.price != null && listing.price! > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(52, 0, 16, 8),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: mutedColor.withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Text(
                                'Verkaufsgebühr: ${CommissionCalculator.formatFee(listing.price)}',
                                style: GoogleFonts.inter(fontSize: 11, color: mutedColor.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      Divider(color: mutedColor.withValues(alpha: 0.15)),
                      // Inserat pausieren
                      _settingsRow(
                        icon: Icons.pause_circle_rounded,
                        label: 'Inserat pausieren',
                        color: Colors.orange,
                        textColor: textColor,
                        trailing: Switch.adaptive(
                          value: !listing.isActive,
                          activeColor: Colors.orange,
                          onChanged: (v) async {
                            final repo = MarketplaceRepository();
                            final updated = await repo.updateListing(listing.id, {'is_active': !v});
                            setState(() => _listing = updated);
                          },
                        ),
                      ),
                      Divider(color: mutedColor.withValues(alpha: 0.15)),
                      // Versandart
                      _settingsRow(
                        icon: Icons.local_shipping_rounded,
                        label: 'Versandart',
                        color: Colors.blue,
                        textColor: textColor,
                        trailing: DropdownButton<String>(
                          value: listing.shippingType,
                          underline: const SizedBox.shrink(),
                          dropdownColor: cardBg,
                          style: TextStyle(color: textColor, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'pickup', child: Text('Abholung')),
                            DropdownMenuItem(value: 'shipping', child: Text('Versand')),
                            DropdownMenuItem(value: 'both', child: Text('Beides')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            final repo = MarketplaceRepository();
                            final updated = await repo.updateListing(listing.id, {'shipping_type': v});
                            setState(() => _listing = updated);
                          },
                        ),
                      ),
                      Divider(color: mutedColor.withValues(alpha: 0.15)),
                      // VB
                      _settingsRow(
                        icon: Icons.handshake_rounded,
                        label: 'VB (Verhandlungsbasis)',
                        color: Colors.amber.shade700,
                        textColor: textColor,
                        trailing: Switch.adaptive(
                          value: listing.isNegotiable,
                          activeColor: Colors.amber.shade700,
                          onChanged: (v) async {
                            final repo = MarketplaceRepository();
                            final updated = await repo.updateListing(listing.id, {'is_negotiable': v});
                            setState(() => _listing = updated);
                          },
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Edit + Delete buttons
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () {
                        CreateListingSheet.show(context, listing: listing);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.edit_rounded, size: 18, color: accentColor),
                      label: Text('Bearbeiten', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _deleteListing(listing),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                      label: const Text('Löschen', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    )),
                  ]),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Heute';
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return 'Vor ${diff.inDays} Tagen';
    return '${date.day}.${date.month}.${date.year}';
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
        trailing,
      ]),
    );
  }

  /// Show commission dialog before marking as sold.
  Future<bool?> _showCommissionDialog(double? price) {
    final fee = CommissionCalculator.calculate(price);
    final receives = CommissionCalculator.sellerReceives(price);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Verkauf bestätigen', style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: textColor, fontSize: 18,
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (price != null && price > 0) ...[
              _feeRow('Verkaufspreis', '${price.toStringAsFixed(2)} €', textColor),
              const SizedBox(height: 8),
              _feeRow('Verkaufsgebühr', '- ${fee.toStringAsFixed(2)} €', Colors.orange),
              Divider(color: mutedColor.withValues(alpha: 0.2)),
              _feeRow('Du erhältst', '${receives.toStringAsFixed(2)} €', Colors.green, bold: true),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: mutedColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CommissionCalculator.feeModelDescription,
                      style: GoogleFonts.inter(fontSize: 11, color: mutedColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: mutedColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Verkauft ✓', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, Color valueColor, {bool bold = false}) {
    final brightness = Theme.of(context).brightness;
    final textColor = brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 14, color: textColor.withValues(alpha: 0.7),
        )),
        Text(value, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor,
        )),
      ],
    );
  }

  /// Record a transaction for bookkeeping (fire-and-forget).
  void _recordTransaction(int listingId, double? price, String sellerId) {
    final fee = CommissionCalculator.calculate(price);
    if (fee <= 0) return;

    final community = ref.read(communityProvider)?.name ?? 'bikergram';
    Supabase.instance.client.from('transactions').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'sale_price': price,
      'commission': fee,
      'community': community,
      'status': 'pending', // pending until actual payment collected
    }).then((_) => debugPrint('[Commission] Transaction recorded: ${fee}€'))
      .catchError((e) => debugPrint('[Commission] Failed to record: $e'));
  }

  Future<void> _directBuy(MarketplaceListing listing) async {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final fee = CommissionCalculator.calculate(listing.price);
    final sellerReceives = CommissionCalculator.sellerReceives(listing.price);
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.white54 : Colors.black54;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sofort kaufen?', style: TextStyle(color: textColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_rounded, size: 48, color: Colors.green.shade600),
          const SizedBox(height: 16),
          Text(listing.title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${listing.price!.toStringAsFixed(0)} €',
            style: TextStyle(color: Colors.green.shade600, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          // Commission breakdown for seller info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Verkaufspreis', style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
                  Text('${listing.price!.toStringAsFixed(2)} €', style: GoogleFonts.inter(fontSize: 13, color: textColor)),
                ]),
                if (fee > 0) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Verkaufsgebühr', style: GoogleFonts.inter(fontSize: 13, color: Colors.orange)),
                    Text('- ${fee.toStringAsFixed(2)} €', style: GoogleFonts.inter(fontSize: 13, color: Colors.orange)),
                  ]),
                  Divider(height: 16, color: mutedColor.withValues(alpha: 0.3)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Verkäufer erhält', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green)),
                    Text('${sellerReceives.toStringAsFixed(2)} €', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Der Artikel wird als verkauft markiert.\nAbwicklung im Chat.',
            style: TextStyle(color: mutedColor, fontSize: 12),
            textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Zurück', style: TextStyle(color: mutedColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kaufen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 1. Mark as sold
        final repo = MarketplaceRepository();
        final updated = await repo.markAsSold(listing.id);
        setState(() => _listing = updated);

        // 1b. Record transaction for bookkeeping
        _recordTransaction(listing.id, listing.price, listing.userId);

        // 2. Create/open conversation
        final msgRepo = MessageRepository();
        final convId = await msgRepo.getOrCreateConversation(listing.userId);

        // 3. Send direct_buy message
        final buyJson = jsonEncode({
          'type': 'direct_buy',
          'vehicle_id': listing.id,
          'vehicle_name': listing.title,
          'price': listing.price,
          'listing_type': 'marketplace',
        });
        await msgRepo.sendMessage(convId, buyJson, messageType: 'vehicle_offer');

        // 4. Navigate to chat
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade600,
              content: Text('🛒 Kauf bestätigt! Kläre die Abwicklung im Chat.'),
            ),
          );
          context.push('/messages/$convId');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  Future<void> _messageSeller(MarketplaceListing listing) async {
    try {
      final repo = MessageRepository();
      final convId = await repo.getOrCreateConversation(listing.userId);
      if (mounted) context.push('/messages/$convId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _makeOffer(MarketplaceListing listing) async {
    final controller = TextEditingController();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Angebot machen', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Inseratspreis: ${listing.price!.toStringAsFixed(0)} ${listing.currency}',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Dein Angebot (€)',
              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Zurück', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) Navigator.pop(ctx, price);
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Senden', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final repo = MessageRepository();
        final convId = await repo.getOrCreateConversation(listing.userId);
        final offerJson = jsonEncode({
          'type': 'offer',
          'vehicle_id': listing.id,
          'vehicle_name': listing.title,
          'price': result,
          'listing_type': 'marketplace',
        });
        await repo.sendMessage(convId, offerJson, messageType: 'vehicle_offer');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Angebot über ${result.toStringAsFixed(0)} € gesendet!')),
          );
          context.push('/messages/$convId');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteListing(MarketplaceListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserat löschen?'),
        content: const Text('Dieses Inserat wird dauerhaft gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zurück')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(marketplaceNotifierProvider.notifier).deleteListing(listing.id);
      if (mounted) context.pop();
    }
  }
}
