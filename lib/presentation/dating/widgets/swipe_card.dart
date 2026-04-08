import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/community.dart';
import '../../../domain/xp_calculator.dart';

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.candidate,
    required this.community,
    this.myLat,
    this.myLng,
  });

  final Map<String, dynamic> candidate;
  final Community community;
  final double? myLat;
  final double? myLng;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  int _currentPhoto = 0;

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    final candidate = widget.candidate;
    final accentColor = community.accentColor;
    final name = candidate['display_name'] ?? candidate['bikername'] ?? candidate['username'] ?? '?';
    final birthYear = candidate['birth_year'] as int?;
    final age = birthYear != null ? DateTime.now().year - birthYear : null;
    final bio = candidate['bio'] as String?;
    // Multi-vehicle support (dating_vehicles array), fallback to legacy single fields
    final datingVehicles = candidate['dating_vehicles'] as List? ?? [];
    final vehicleBrand = candidate['vehicle_brand'] as String?;
    final vehicleModel = candidate['vehicle_model'] as String?;
    final vehicleHp = candidate['vehicle_hp'] as int?;
    final totalFeedLikes = (candidate['total_feed_likes'] as int?) ?? 0;
    final xp = (candidate['xp_total'] as int?) ?? 0;
    final level = XpCalculator.levelFromXp(xp);
    final levelName = XpCalculator.levelName(level);
    final isPremium = candidate['is_premium'] == true;

    // Collect all photos: dating_photos first, fallback to avatar
    final photos = <String>[];
    final datingPhotos = candidate['dating_photos'];
    if (datingPhotos is List && datingPhotos.isNotEmpty) {
      photos.addAll(List<String>.from(datingPhotos));
    } else {
      final avatarUrl = community == Community.cargram
          ? (candidate['avatar_url_cargram'] ?? candidate['avatar_url'])
          : candidate['avatar_url'];
      if (avatarUrl != null && (avatarUrl as String).isNotEmpty) {
        photos.add(avatarUrl);
      }
    }

    // Distance
    final theirLat = candidate['home_lat'] as double?;
    final theirLng = candidate['home_lng'] as double?;
    final distance = _calcDistance(widget.myLat, widget.myLng, theirLat, theirLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: community.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photos (tap left/right to navigate) ──
            if (photos.isNotEmpty)
              GestureDetector(
                onTapUp: (details) {
                  if (photos.length <= 1) return;
                  final width = context.size?.width ?? 300;
                  if (details.localPosition.dx < width * 0.35) {
                    // Tap left → previous
                    if (_currentPhoto > 0) {
                      setState(() => _currentPhoto--);
                    }
                  } else if (details.localPosition.dx > width * 0.65) {
                    // Tap right → next
                    if (_currentPhoto < photos.length - 1) {
                      setState(() => _currentPhoto++);
                    }
                  }
                },
                child: CachedNetworkImage(
                  key: ValueKey(photos[_currentPhoto.clamp(0, photos.length - 1)]),
                  imageUrl: photos[_currentPhoto.clamp(0, photos.length - 1)],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: community.cardColor,
                    child: Center(
                      child: Icon(Icons.person_rounded, size: 80, color: accentColor.withValues(alpha: 0.3)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _buildFallbackAvatar(name, accentColor),
                ),
              )
            else
              _buildFallbackAvatar(name, accentColor),

            // ── Photo indicators (top dots) ──
            if (photos.length > 1)
              Positioned(
                top: 8, left: 16, right: 16,
                child: Row(
                  children: List.generate(photos.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: i < photos.length - 1 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i == _currentPhoto
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // ── Gradient overlay ──
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),

            // ── Info section ──
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + Age
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (age != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$age',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (isPremium) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.workspace_premium_rounded, size: 20, color: Colors.amber),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Vehicle(s) + Distance row
                  if (datingVehicles.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...datingVehicles.take(3).map((v) {
                          final vBrand = v['brand'] ?? '';
                          final vModel = v['model'] ?? '';
                          final vHp = v['horsepower'] as int?;
                          final vCommunity = v['community'] as String?;
                          final isBike = vCommunity == 'bikergram';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isBike ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                                  size: 14,
                                  color: isBike ? Colors.orange : Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$vBrand $vModel${vHp != null ? ' · ${vHp}PS' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (datingVehicles.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${datingVehicles.length - 3}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ] else if (vehicleBrand != null) ...[
                    // Legacy single vehicle fallback
                    Row(
                      children: [
                        Icon(
                          community == Community.bikergram
                              ? Icons.two_wheeler_rounded
                              : Icons.directions_car_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            [
                              vehicleBrand,
                              vehicleModel,
                              if (vehicleHp != null) '${vehicleHp}PS',
                            ].where((s) => s != null).join(' '),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (distance != null)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 2),
                        Text(
                          distance,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 6),

                  // Level badge + Feed likes badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lvl $level · $levelName',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (totalFeedLikes > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite_rounded, size: 12, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                '$totalFeedLikes',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Bio
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, Color accentColor) {
    return Container(
      color: accentColor.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 80,
            fontWeight: FontWeight.w800,
            color: accentColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// Haversine distance, rounded to nearest 5 km for privacy.
  static String? _calcDistance(double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;

    const earthRadius = 6371.0; // km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final km = earthRadius * c;

    if (km < 5) return 'In deiner Nähe';
    final rounded = (km / 5).round() * 5;
    return '~$rounded km';
  }

  static double _toRad(double deg) => deg * pi / 180;
}
