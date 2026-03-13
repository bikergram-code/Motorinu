import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../providers/garage/garage_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/add_vehicle_sheet.dart';

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(garageNotifierProvider.notifier).loadVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final garageState = ref.watch(garageNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final isBiker = community == Community.bikergram;

    // Re-register Speed-Dial items every build (ensures they persist after tab switches)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/garage') {
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
      body: CustomScrollView(
        slivers: [
          // Spacer for global top bar (icons are now in MainShell)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 52),
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
                    cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                    onEdit: () async {
                      await AddVehicleSheet.show(context, ref, vehicle: v);
                    },
                    onDelete: () async {
                      await ref
                          .read(garageNotifierProvider.notifier)
                          .deleteVehicle(v.id);
                    },
                  );
                },
                childCount: garageState.vehicles.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.accentColor,
    required this.isBiker,
    required this.onEdit,
    required this.onDelete,
    this.cardColor,
  });

  final Vehicle vehicle;
  final Color accentColor;
  final bool isBiker;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
                  ? Image.network(
                      vehicle.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56, height: 56,
                        color: accentColor.withValues(alpha: 0.1),
                        child: Icon(
                          isBiker ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                          color: accentColor,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      width: 56, height: 56,
                      color: accentColor.withValues(alpha: 0.1),
                      child: Icon(
                        isBiker ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (vehicle.year != null) '${vehicle.year}',
                      if (vehicle.displacementCc != null) '${vehicle.displacementCc} ccm',
                      if (vehicle.horsepower != null) '${vehicle.horsepower} PS',
                      if (vehicle.category != null) vehicle.category,
                    ].join(' \u00b7 '),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined,
                  color: Colors.white.withValues(alpha: 0.3), size: 20),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 20),
            ),
          ],
        ),
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
