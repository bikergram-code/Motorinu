import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../theme/app_theme.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    // Demo rides
    final rides = [
      _RideData(
        title: 'Sonntagstour Schwarzwald',
        date: '12. Feb 2026',
        distance: 142.3,
        duration: '2h 15min',
        avgSpeed: 63,
        xpEarned: 142,
      ),
      _RideData(
        title: 'Pendeln zur Arbeit',
        date: '11. Feb 2026',
        distance: 28.7,
        duration: '35min',
        avgSpeed: 49,
        xpEarned: 29,
      ),
      _RideData(
        title: 'Abendliche Runde',
        date: '10. Feb 2026',
        distance: 56.1,
        duration: '1h 05min',
        avgSpeed: 52,
        xpEarned: 56,
      ),
      _RideData(
        title: 'Alpenpass-Tour',
        date: '8. Feb 2026',
        distance: 234.8,
        duration: '4h 20min',
        avgSpeed: 54,
        xpEarned: 235,
      ),
      _RideData(
        title: 'Kurzstrecke Stadt',
        date: '7. Feb 2026',
        distance: 12.4,
        duration: '22min',
        avgSpeed: 34,
        xpEarned: 12,
      ),
    ];

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
        ),
        title: Text(
          'Fahrt-Verlauf',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary card
          Container(
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
              border: Border.all(
                color: accentColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  value: '474',
                  unit: 'km',
                  label: 'Gesamt',
                  color: accentColor,
                ),
                Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                _SummaryItem(
                  value: '5',
                  unit: '',
                  label: 'Fahrten',
                  color: accentColor,
                ),
                Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                _SummaryItem(
                  value: '474',
                  unit: 'XP',
                  label: 'Verdient',
                  color: accentColor,
                ),
              ],
            ),
          ),

          // Rides list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                return _RideCard(
                  data: ride,
                  accentColor: accentColor,
                  cardColor: community?.cardFor(brightness),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RideData {
  const _RideData({
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.avgSpeed,
    required this.xpEarned,
  });

  final String title;
  final String date;
  final double distance;
  final String duration;
  final int avgSpeed;
  final int xpEarned;
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.data,
    required this.accentColor,
    this.cardColor,
  });

  final _RideData data;
  final Color accentColor;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      data.date,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
                      ),
                    ),
                  ],
                ),
              ),
              // XP badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: accentColor, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '+${data.xpEarned} XP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _RideStat(
                icon: Icons.straighten_rounded,
                value: '${data.distance} km',
              ),
              const SizedBox(width: 20),
              _RideStat(
                icon: Icons.timer_outlined,
                value: data.duration,
              ),
              const SizedBox(width: 20),
              _RideStat(
                icon: Icons.speed_rounded,
                value: '${data.avgSpeed} km/h',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideStat extends StatelessWidget {
  const _RideStat({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }
}
