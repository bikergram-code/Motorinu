import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../providers/garage/garage_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/add_vehicle_sheet.dart';

class GarageScreen extends ConsumerStatefulWidget {
  final String? userId; // null = own garage
  const GarageScreen({super.key, this.userId});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(garageNotifierProvider.notifier).loadVehicles(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);

    // Reload garage when community switches
    ref.listen(communityProvider, (prev, next) {
      if (prev != next) {
        ref.read(garageNotifierProvider.notifier).loadVehicles(userId: widget.userId);
      }
    });
    final brightness = Theme.of(context).brightness;
    final garageState = ref.watch(garageNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isBiker = community == Community.bikergram;

    final isOwnGarage = widget.userId == null;

    // Re-register Speed-Dial items every build (ensures they persist after tab switches)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/garage' && isOwnGarage) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.add_rounded,
            label: 'Fahrzeug hinzufügen',
            color: Colors.green,
            onTap: () async {
              if (!mounted) return;
              await AddVehicleSheet.show(context, ref);
              if (!mounted) return;
              ref.read(garageNotifierProvider.notifier).loadVehicles();
            },
          ),
        ]);
      });
    }

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      floatingActionButton: isOwnGarage ? Padding(
        padding: const EdgeInsets.only(bottom: 38),
        child: AnimatedScale(
          scale: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            backgroundColor: accentColor,
            onPressed: () async {
              await AddVehicleSheet.show(context, ref);
              if (!mounted) return;
              ref.read(garageNotifierProvider.notifier).loadVehicles();
            },
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ) : null,
      body: NotificationListener<ScrollNotification>(
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
                  Text('Meine Garage', style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                  )),
                ],
              ),
            ),
          ),

          // Stats strip
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${garageState.vehicles.length}',
                    label: isBiker ? 'Bikes' : 'Autos',
                    icon: isBiker
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_rounded,
                    color: accentColor,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.06)),
                  _StatItem(
                    value: '${garageState.vehicles.fold(0, (sum, v) => sum + (v.horsepower ?? 0))} PS',
                    label: 'Gesamtleistung',
                    icon: Icons.speed_rounded,
                    color: accentColor,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.06)),
                  _StatItem(
                    value: '${garageState.vehicles.fold(0, (sum, v) => sum + (v.displacementCc ?? 0))}',
                    label: 'ccm gesamt',
                    icon: Icons.engineering_rounded,
                    color: accentColor,
                  ),
                ],
              ),
            ),
          ),

          if (garageState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (garageState.error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(garageState.error!,
                        style: GoogleFonts.inter(
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(garageNotifierProvider.notifier)
                          .loadVehicles(),
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
            )
          else if (garageState.vehicles.isEmpty)
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
                      child: Icon(
                        isBiker
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_rounded,
                        size: 36,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isBiker
                          ? 'F\u00fcge dein erstes Bike hinzu'
                          : 'F\u00fcge dein erstes Auto hinzu',
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)),
                    ),
                    const SizedBox(height: 8),
                    Text('Verwalte Umbauten, Kosten & Specs',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await AddVehicleSheet.show(context, ref);
                        ref
                            .read(garageNotifierProvider.notifier)
                            .loadVehicles();
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                          isBiker ? 'Bike hinzuf\u00fcgen' : 'Auto hinzuf\u00fcgen',
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
                  final v = garageState.vehicles[index];
                  return _VehicleCard(
                    vehicle: v,
                    accentColor: accentColor,
                    isBiker: isBiker,
                    isOwn: isOwnGarage,
                    cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                    onEdit: isOwnGarage ? () async {
                      await AddVehicleSheet.show(context, ref, vehicle: v);
                    } : null,
                    onDelete: isOwnGarage ? () async {
                      await ref
                          .read(garageNotifierProvider.notifier)
                          .deleteVehicle(v.id);
                    } : null,
                  );
                },
                childCount: garageState.vehicles.length,
              ),
            ),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      ),
    );
  }
}

class _VehicleCard extends ConsumerStatefulWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.accentColor,
    required this.isBiker,
    this.onEdit,
    this.onDelete,
    this.cardColor,
    this.isOwn = true,
  });

  final Vehicle vehicle;
  final Color accentColor;
  final bool isBiker;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color? cardColor;
  final bool isOwn;

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  int _likeCount = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    final repo = ref.read(vehicleRepositoryProvider);
    final count = await repo.getLikeCount(widget.vehicle.id);
    final liked = await repo.hasLiked(widget.vehicle.id);
    if (mounted) setState(() { _likeCount = count; _isLiked = liked; });
  }

  void _shareVehicle(BuildContext context, Vehicle v, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final subCol = isDark ? Colors.white54 : const Color(0xFF6C757D);
        final text = '${v.brand} ${v.model}'
            '${v.year != null ? ' (${v.year})' : ''}'
            '${v.horsepower != null ? ' – ${v.horsepower} PS' : ''}';
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('Fahrzeug teilen',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textCol)),
                ),
                const Divider(height: 1),
                ListTile(dense: true, leading: Icon(Icons.dynamic_feed_rounded, color: accent, size: 22),
                  title: Text('Im Feed posten', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToFeed(v); }),
                ListTile(dense: true, leading: Icon(Icons.auto_awesome_rounded, color: Colors.purple, size: 22),
                  title: Text('Als Story teilen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToStory(v); }),
                ListTile(dense: true, leading: Icon(Icons.storefront_rounded, color: Colors.green, size: 22),
                  title: Text('Im Marktplatz einstellen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToMarketplace(v); }),
                const Divider(height: 1),
                ListTile(dense: true, leading: Icon(Icons.share_rounded, color: accent, size: 22),
                  title: Text('Extern teilen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  subtitle: Text('Messenger, Social Media, ...', style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                  onTap: () { Navigator.pop(ctx); Share.share('Schau dir mein Fahrzeug an: $text \ud83c\udfcd\ufe0f'); }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareToFeed(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final text = '${v.brand} ${v.model}'
        '${v.year != null ? ' (${v.year})' : ''}'
        '${v.horsepower != null ? ' \u2013 ${v.horsepower} PS' : ''}';

    try {
      await supabase.from('posts').insert({
        'user_id': userId,
        'body': '\ud83c\udfcd\ufe0f $text',
        if (v.imageUrl != null) 'image_url': v.imageUrl,
        'community': 'bikergram',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Im Feed gepostet!')),
        );
      }
    } catch (e) {
      debugPrint('[Share] Feed post failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _shareToStory(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || v.imageUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kein Bild vorhanden f\u00fcr Story')),
        );
      }
      return;
    }

    try {
      await supabase.from('stories').insert({
        'user_id': userId,
        'media_url': v.imageUrl,
        'media_type': 'image',
        'caption': '${v.brand} ${v.model}',
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story erstellt!')),
        );
      }
    } catch (e) {
      debugPrint('[Share] Story failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _shareToMarketplace(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.from('marketplace_listings').insert({
        'user_id': userId,
        'title': '${v.brand} ${v.model}',
        'description': '${v.brand} ${v.model}'
            '${v.year != null ? ', Bj. ${v.year}' : ''}'
            '${v.horsepower != null ? ', ${v.horsepower} PS' : ''}',
        if (v.imageUrl != null) 'images': [v.imageUrl],
        'category': 'Motorrad',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Im Marktplatz eingestellt!')),
        );
      }
    } catch (e) {
      debugPrint('[Share] Marketplace failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _openDetail() {
    // rootNavigator: damit die Route ÜBER die MainShell geht (kein TopBar-Overlap)
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VehicleDetailPage(
          vehicle: widget.vehicle,
          accentColor: widget.accentColor,
          isBiker: widget.isBiker,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ),
    ).then((_) => _loadLikes()); // Refresh likes when coming back
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final v = widget.vehicle;
    final accent = widget.accentColor;

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: v.imageUrl != null && v.imageUrl!.isNotEmpty
                      ? Image.network(
                          v.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(accent),
                        )
                      : _placeholder(accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v.brand} ${v.model}',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (v.year != null) '${v.year}',
                          if (v.displacementCc != null) '${v.displacementCc} ccm',
                          if (v.horsepower != null) '${v.horsepower} PS',
                          if (v.mileage != null)
                            v.mileage! >= 1000
                                ? '${(v.mileage! / 1000).toStringAsFixed(v.mileage! % 1000 == 0 ? 0 : 1)} tkm'
                                : '${v.mileage} km',
                          if (v.fuel != null) v.fuel,
                          if (v.category != null) v.category,
                        ].join(' \u00b7 '),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bottom row: Like/Angebot (fremde) oder Share (eigene)
            Row(
              children: [
                // Like button (nur bei fremden Bikes interaktiv, bei eigenen read-only)
                if (!widget.isOwn)
                  GestureDetector(
                    onTap: () async {
                      final repo = ref.read(vehicleRepositoryProvider);
                      if (_isLiked) {
                        await repo.unlikeVehicle(v.id);
                        setState(() { _isLiked = false; _likeCount = (_likeCount - 1).clamp(0, 999999); });
                      } else {
                        await repo.likeVehicle(v.id);
                        setState(() { _isLiked = true; _likeCount++; });
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: _isLiked ? Colors.red : Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 4),
                        Text('$_likeCount',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
                            color: _isLiked ? Colors.red : Colors.white.withValues(alpha: 0.35))),
                      ],
                    ),
                  )
                else if (_likeCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, size: 14,
                        color: Colors.red.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text('$_likeCount',
                        style: GoogleFonts.inter(fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35))),
                    ],
                  ),
                const SizedBox(width: 16),
                // Angebot (nur fremde)
                if (!widget.isOwn) ...[
                  GestureDetector(
                    onTap: _openDetail,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_rounded, size: 16,
                          color: accent.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text('Angebot', style: GoogleFonts.inter(fontSize: 12,
                          color: accent.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                // Share button (immer)
                GestureDetector(
                  onTap: () => _shareVehicle(context, v, accent),
                  child: Icon(Icons.share_rounded, size: 16,
                    color: Colors.white.withValues(alpha: 0.4)),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 20,
                  color: Colors.white.withValues(alpha: 0.2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color accent) {
    return Container(
      width: 56, height: 56,
      color: accent.withValues(alpha: 0.1),
      child: Icon(
        widget.isBiker ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
        color: accent,
        size: 28,
      ),
    );
  }
}

// ─── Vehicle Detail Page (Like + Angebot) ─────────────────────────

class VehicleDetailPage extends ConsumerStatefulWidget {
  const VehicleDetailPage({
    super.key,
    required this.vehicle,
    required this.accentColor,
    required this.isBiker,
    this.onEdit,
    this.onDelete,
  });

  final Vehicle vehicle;
  final Color accentColor;
  final bool isBiker;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  ConsumerState<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends ConsumerState<VehicleDetailPage> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _likeLoading = false;
  List<VehicleOffer> _offers = [];

  bool get _isOwn {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid != null && uid == widget.vehicle.userId;
  }

  @override
  void initState() {
    super.initState();
    _loadLikeState();
    if (_isOwn) _loadOffers();
  }

  void _shareVehicle(BuildContext context, Vehicle v, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final subCol = isDark ? Colors.white54 : const Color(0xFF6C757D);
        final text = '${v.brand} ${v.model}'
            '${v.year != null ? ' (${v.year})' : ''}'
            '${v.horsepower != null ? ' \u2013 ${v.horsepower} PS' : ''}';
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('Fahrzeug teilen', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textCol)),
                ),
                const Divider(height: 1),
                ListTile(dense: true, leading: Icon(Icons.dynamic_feed_rounded, color: accent, size: 22),
                  title: Text('Im Feed posten', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToFeed(v); }),
                ListTile(dense: true, leading: Icon(Icons.auto_awesome_rounded, color: Colors.purple, size: 22),
                  title: Text('Als Story teilen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToStory(v); }),
                ListTile(dense: true, leading: Icon(Icons.storefront_rounded, color: Colors.green, size: 22),
                  title: Text('Im Marktplatz einstellen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  onTap: () { Navigator.pop(ctx); _shareToMarketplace(v); }),
                const Divider(height: 1),
                ListTile(dense: true, leading: Icon(Icons.share_rounded, color: accent, size: 22),
                  title: Text('Extern teilen', style: GoogleFonts.inter(fontSize: 14, color: textCol)),
                  subtitle: Text('Messenger, Social Media, ...', style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                  onTap: () { Navigator.pop(ctx); Share.share('Schau dir mein Fahrzeug an: $text \ud83c\udfcd\ufe0f'); }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareToFeed(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final text = '${v.brand} ${v.model}${v.year != null ? ' (${v.year})' : ''}${v.horsepower != null ? ' \u2013 ${v.horsepower} PS' : ''}';
    try {
      await supabase.from('posts').insert({'user_id': userId, 'body': '\ud83c\udfcd\ufe0f $text', if (v.imageUrl != null) 'image_url': v.imageUrl, 'community': 'bikergram'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Im Feed gepostet!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  void _shareToStory(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || v.imageUrl == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kein Bild vorhanden f\u00fcr Story')));
      return;
    }
    try {
      await supabase.from('stories').insert({'user_id': userId, 'media_url': v.imageUrl, 'media_type': 'image', 'caption': '${v.brand} ${v.model}'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story erstellt!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  void _shareToMarketplace(Vehicle v) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase.from('marketplace_listings').insert({'user_id': userId, 'title': '${v.brand} ${v.model}', 'description': '${v.brand} ${v.model}${v.year != null ? ', Bj. ${v.year}' : ''}${v.horsepower != null ? ', ${v.horsepower} PS' : ''}', if (v.imageUrl != null) 'images': [v.imageUrl], 'category': 'Motorrad'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Im Marktplatz eingestellt!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  /// Send a notification (Glocke) + direct message with offer card to the user.
  Future<void> _notify({
    required String targetUserId,
    required String title,
    String? body,
    Map<String, dynamic>? data,
    String offerType = 'offer', // offer, accepted, declined, counter, like
  }) async {
    final community = ref.read(communityProvider)?.name;
    debugPrint('[VehicleDetail] _notify → target=$targetUserId type=$offerType');

    // 1. Conversation holen (für Link in der Glocke + Chat-Nachricht)
    int? convId;
    try {
      final msgRepo = ref.read(messageRepositoryProvider);
      convId = await msgRepo.getOrCreateConversation(
        targetUserId,
        community: community,
      );

      // Chat-Nachricht nur für Angebote (nicht für Likes)
      if (offerType != 'like') {
        final jsonBody = '{'
            '"type":"$offerType",'
            '"vehicle_id":${widget.vehicle.id},'
            '"vehicle_name":"${widget.vehicle.brand} ${widget.vehicle.model}",'
            '"owner_id":"${widget.vehicle.userId}",'
            '"amount":${data?['offer_amount'] ?? 0},'
            '"offer_id":${data?['offer_id'] ?? 0},'
            '"title":"$title",'
            '"body":"${body ?? ''}"'
            '}';
        await msgRepo.sendMessage(convId, jsonBody, messageType: 'vehicle_offer');
        debugPrint('[VehicleDetail] Offer message sent to conv $convId');
      }
    } catch (e) {
      debugPrint('[VehicleDetail] Chat message failed: $e');
    }

    // 2. Glocke (notification) mit Link zur Conversation
    try {
      final notifRepo = ref.read(notificationRepositoryProvider);
      await notifRepo.createNotification(
        targetUserId: targetUserId,
        type: 'vehicle_offer',
        title: title,
        body: body,
        data: {
          'vehicle_id': widget.vehicle.id,
          'vehicle_name': '${widget.vehicle.brand} ${widget.vehicle.model}',
          'offer_type': offerType,
          'sender_id': Supabase.instance.client.auth.currentUser?.id ?? '',
          if (convId != null) 'conversation_id': convId,
          ...?data,
        },
        community: community,
      );
    } catch (e) {
      debugPrint('[VehicleDetail] Notification failed: $e');
    }
  }

  Future<void> _loadLikeState() async {
    final repo = ref.read(vehicleRepositoryProvider);
    final liked = await repo.hasLiked(widget.vehicle.id);
    final count = await repo.getLikeCount(widget.vehicle.id);
    if (mounted) setState(() { _isLiked = liked; _likeCount = count; });
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    setState(() => _likeLoading = true);
    final repo = ref.read(vehicleRepositoryProvider);
    try {
      if (_isLiked) {
        await repo.unlikeVehicle(widget.vehicle.id);
        setState(() { _isLiked = false; _likeCount = (_likeCount - 1).clamp(0, 999999); });
      } else {
        await repo.likeVehicle(widget.vehicle.id);
        setState(() { _isLiked = true; _likeCount++; });
        // Notify owner about the like
        if (!_isOwn) {
          _notify(
            targetUserId: widget.vehicle.userId,
            title: 'Dein ${widget.vehicle.brand} ${widget.vehicle.model} gefällt jemandem!',
            body: 'Jemand hat dein Fahrzeug geliked.',
            data: {'type': 'vehicle_like', 'offer_amount': 0},
            offerType: 'like',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _loadOffers() async {
    final repo = ref.read(vehicleRepositoryProvider);
    final offers = await repo.getOffersForVehicle(widget.vehicle.id);
    if (mounted) setState(() => _offers = offers);
  }

  void _showSendOfferSheet() {
    final amountCtrl = TextEditingController();
    final messageCtrl = TextEditingController(
      text: 'Hallo, ich interessiere mich f\u00fcr dein ${widget.vehicle.brand} ${widget.vehicle.model}.',
    );
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Angebot senden',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text('${widget.vehicle.brand} ${widget.vehicle.model}',
              style: GoogleFonts.inter(fontSize: 14, color: widget.accentColor)),
            const SizedBox(height: 20),

            // Amount
            Text('Dein Angebot (\u20ac)', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D))),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: '0,00',
                hintStyle: GoogleFonts.inter(fontSize: 22, color: Colors.white.withValues(alpha: 0.2)),
                prefixText: '\u20ac ',
                prefixStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: widget.accentColor),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message
            Text('Nachricht (optional)', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D))),
            const SizedBox(height: 6),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final amountText = amountCtrl.text.replaceAll(',', '.').trim();
                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Bitte gib einen g\u00fcltigen Betrag ein')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final repo = ref.read(vehicleRepositoryProvider);
                  final newOffer = await repo.sendOffer(
                    vehicleId: widget.vehicle.id,
                    ownerId: widget.vehicle.userId,
                    amount: amount,
                    message: messageCtrl.text.trim().isNotEmpty ? messageCtrl.text.trim() : null,
                  );
                  _notify(
                    targetUserId: widget.vehicle.userId,
                    title: 'Neues Angebot f\u00fcr dein ${widget.vehicle.brand} ${widget.vehicle.model}',
                    body: '${amount.toStringAsFixed(2)} \u20ac',
                    data: {'offer_amount': amount, 'offer_id': newOffer.id},
                    offerType: 'offer',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Angebot \u00fcber ${amount.toStringAsFixed(2)} \u20ac gesendet!'),
                        backgroundColor: widget.accentColor,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text('Angebot senden', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferActions(VehicleOffer offer) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
            const SizedBox(height: 12),
            Text('Angebot: ${offer.amount.toStringAsFixed(2)} \u20ac',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            if (offer.message != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(offer.message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13,
                    color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check_circle_rounded, color: Colors.green.shade400),
              title: Text('Annehmen', style: GoogleFonts.inter(
                color: Colors.green.shade400, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final repo = ref.read(vehicleRepositoryProvider);
                await repo.acceptOffer(offer.id);

                // Verkäufer-Profil laden für Adressdaten
                String? sellerLocation;
                try {
                  final profile = await Supabase.instance.client
                      .from('profiles')
                      .select('postal_code, display_name, username')
                      .eq('id', widget.vehicle.userId)
                      .maybeSingle();
                  if (profile != null) {
                    final plz = profile['postal_code'] as String?;
                    final name = (profile['display_name'] as String?) ??
                        (profile['username'] as String?) ?? '';
                    if (plz != null && plz.isNotEmpty) {
                      sellerLocation = '$plz ($name)';
                    }
                  }
                } catch (_) {}

                final bodyText = 'Dein Angebot von ${offer.amount.toStringAsFixed(2)} \u20ac wurde angenommen!'
                    '${sellerLocation != null ? '\n\ud83d\udccd Standort: $sellerLocation' : ''}';

                _notify(
                  targetUserId: offer.senderId,
                  title: 'Angebot angenommen!',
                  body: bodyText,
                  data: {
                    'offer_id': offer.id,
                    'offer_amount': offer.amount,
                    if (sellerLocation != null) 'seller_location': sellerLocation,
                  },
                  offerType: 'accepted',
                );
                _loadOffers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Angebot angenommen!'), backgroundColor: Colors.green.shade400),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_rounded, color: Colors.red),
              title: Text('Ablehnen', style: GoogleFonts.inter(
                color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final repo = ref.read(vehicleRepositoryProvider);
                await repo.declineOffer(offer.id);
                _notify(
                  targetUserId: offer.senderId,
                  title: 'Angebot abgelehnt',
                  body: 'Dein Angebot von ${offer.amount.toStringAsFixed(2)} \u20ac wurde abgelehnt.',
                  data: {'offer_id': offer.id, 'offer_amount': offer.amount},
                  offerType: 'declined',
                );
                _loadOffers();
              },
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: widget.accentColor),
              title: Text('Gegenangebot', style: GoogleFonts.inter(
                color: widget.accentColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _showCounterOfferSheet(offer);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCounterOfferSheet(VehicleOffer originalOffer) {
    final amountCtrl = TextEditingController(text: originalOffer.amount.toStringAsFixed(0));
    final messageCtrl = TextEditingController();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Gegenangebot',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text('Vorheriges Angebot: ${originalOffer.amount.toStringAsFixed(2)} \u20ac',
              style: GoogleFonts.inter(fontSize: 13,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
            const SizedBox(height: 20),

            Text('Dein Gegenangebot (\u20ac)', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D))),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                prefixText: '\u20ac ',
                prefixStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: widget.accentColor),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Nachricht (optional)', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D))),
            const SizedBox(height: 6),
            TextField(
              controller: messageCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'z.B. Mein letztes Angebot...',
                hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final amountText = amountCtrl.text.replaceAll(',', '.').trim();
                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Bitte gib einen g\u00fcltigen Betrag ein')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final repo = ref.read(vehicleRepositoryProvider);
                  await repo.counterOffer(
                    originalOfferId: originalOffer.id,
                    vehicleId: widget.vehicle.id,
                    recipientId: originalOffer.senderId,
                    amount: amount,
                    message: messageCtrl.text.trim().isNotEmpty ? messageCtrl.text.trim() : null,
                  );
                  _notify(
                    targetUserId: originalOffer.senderId,
                    title: 'Gegenangebot erhalten',
                    body: '${amount.toStringAsFixed(2)} \u20ac',
                    data: {'offer_amount': amount},
                    offerType: 'counter',
                  );
                  _loadOffers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gegenangebot \u00fcber ${amount.toStringAsFixed(2)} \u20ac gesendet!'),
                        backgroundColor: widget.accentColor,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text('Gegenangebot senden', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final accent = widget.accentColor;
    final vehicle = widget.vehicle;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
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
              // Like (fremde) oder Share (eigene)
              if (!_isOwn)
                IconButton(
                  onPressed: _toggleLike,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              // Share button (immer)
              IconButton(
                onPressed: () => _shareVehicle(context, vehicle, accent),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                ),
              ),
              if (_isOwn && widget.onEdit != null)
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEdit?.call();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
                  ? Image.network(
                      vehicle.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand + Model + Like count
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vehicle.brand} ${vehicle.model}',
                              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: textColor),
                            ),
                            if (vehicle.year != null)
                              Text('Baujahr ${vehicle.year}',
                                style: GoogleFonts.inter(fontSize: 15, color: mutedColor)),
                          ],
                        ),
                      ),
                      // Like counter
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isLiked ? Colors.red.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isLiked ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isLiked ? Colors.red : mutedColor,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text('$_likeCount',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: _isLiked ? Colors.red : mutedColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Specs chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (vehicle.isPrimary)
                        _specChip(Icons.star_rounded, 'Hauptfahrzeug', color: Colors.amber),
                      if (vehicle.year != null)
                        _specChip(Icons.calendar_month_rounded, 'Bj. ${vehicle.year}'),
                      if (vehicle.horsepower != null)
                        _specChip(Icons.speed_rounded, '${vehicle.horsepower} PS'),
                      if (vehicle.displacementCc != null)
                        _specChip(Icons.engineering_rounded, '${vehicle.displacementCc} ccm'),
                      if (vehicle.mileage != null)
                        _specChip(Icons.straighten_rounded,
                          vehicle.mileage! >= 1000
                              ? '${(vehicle.mileage! / 1000).toStringAsFixed(vehicle.mileage! % 1000 == 0 ? 0 : 1)} tkm'
                              : '${vehicle.mileage} km'),
                      if (vehicle.fuel != null)
                        _specChip(Icons.local_gas_station_rounded, vehicle.fuel!),
                      if (vehicle.transmission != null)
                        _specChip(Icons.settings_rounded, vehicle.transmission!),
                      if (vehicle.color != null)
                        _specChip(Icons.palette_rounded, vehicle.color!),
                      if (vehicle.tuevDate != null)
                        _specChip(Icons.verified_rounded, 'TÜV ${vehicle.tuevDate}'),
                      if (vehicle.category != null)
                        _specChip(Icons.category_rounded, vehicle.category!),
                      if (vehicle.forSale && vehicle.price != null)
                        _specChip(Icons.sell_rounded, '${vehicle.price!.toStringAsFixed(0)} \u20ac', color: Colors.green),
                      if (vehicle.forSale && vehicle.price == null)
                        _specChip(Icons.sell_rounded, 'Zu verkaufen', color: Colors.green),
                    ],
                  ),

                  // Description
                  if (vehicle.description != null && vehicle.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Beschreibung',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(vehicle.description!,
                        style: GoogleFonts.inter(fontSize: 14, height: 1.5,
                          color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1A1A1A))),
                    ),
                  ],

                  // ── Angebot senden (für fremde Fahrzeuge) ──
                  if (!_isOwn) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSendOfferSheet,
                        icon: const Icon(Icons.local_offer_rounded, size: 20),
                        label: Text('Angebot senden',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],

                  // ── Eingegangene Angebote (für eigene Fahrzeuge) ──
                  if (_isOwn && _offers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.inbox_rounded, size: 18, color: accent),
                        const SizedBox(width: 6),
                        Text('Eingegangene Angebote (${_offers.length})',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...(_offers.map((offer) => _buildOfferCard(offer, isDark, textColor, mutedColor, accent))),
                  ],

                  // ── Bearbeiten/Löschen (eigene Fahrzeuge) ──
                  if (_isOwn && (widget.onEdit != null || widget.onDelete != null)) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (widget.onEdit != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onEdit?.call();
                              },
                              icon: Icon(Icons.edit_rounded, size: 18, color: accent),
                              label: Text('Bearbeiten', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: accent)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        if (widget.onEdit != null && widget.onDelete != null)
                          const SizedBox(width: 10),
                        if (widget.onDelete != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onDelete?.call();
                              },
                              icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                              label: Text('L\u00f6schen', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(VehicleOffer offer, bool isDark, Color textColor, Color mutedColor, Color accent) {
    final statusColor = switch (offer.status) {
      'accepted' => Colors.green,
      'declined' => Colors.red,
      'countered' => Colors.orange,
      _ => accent,
    };

    return GestureDetector(
      onTap: offer.isPending ? () => _showOfferActions(offer) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${offer.amount.toStringAsFixed(2)} \u20ac',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(offer.statusLabel,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  if (offer.message != null) ...[
                    const SizedBox(height: 4),
                    Text(offer.message!,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
                  ],
                ],
              ),
            ),
            if (offer.isPending)
              Icon(Icons.chevron_right_rounded, color: mutedColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: widget.accentColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          widget.isBiker ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
          size: 80,
          color: widget.accentColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _specChip(IconData icon, String text, {Color? color}) {
    final c = color ?? widget.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D))),
      ],
    );
  }
}
