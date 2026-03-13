import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/xp_calculator.dart';
import '../../../services/live_location_service.dart';

/// Bubble die erscheint wenn man einen Live-User auf der Karte antippt.
/// Zeigt Profilbild, Name, Level/XP, PLZ, Bike, Speed, Follower, Likes.
class LiveUserBubble extends StatelessWidget {
  final LiveUserPosition user;
  final Color accentColor;
  final VoidCallback onDismiss;

  const LiveUserBubble({
    super.key,
    required this.user,
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xF0222222) : const Color(0xF5FFFFFF);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;

    final level = XpCalculator.levelFromXp(user.xpTotal);
    final levelN = XpCalculator.levelName(level);
    final levelC = XpCalculator.levelColor(level);

    return Positioned(
      left: 0, right: 0,
      top: MediaQuery.of(context).size.height * 0.25,
      child: Center(child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Profilbild
              CircleAvatar(
                radius: 36,
                backgroundColor: levelC.withValues(alpha: 0.2),
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? Icon(Icons.person_rounded, size: 36, color: levelC)
                    : null,
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                user.displayName,
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Level + XP
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: levelC.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lvl $level · $levelN',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: levelC),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${user.xpTotal} XP',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: mutedColor),
                ),
              ]),
              const SizedBox(height: 10),
              // Stats row: Follower, Likes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bubbleStat(Icons.people_rounded, '${user.followerCount}', 'Follower', mutedColor),
                  Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 12), color: mutedColor.withValues(alpha: 0.2)),
                  _bubbleStat(Icons.favorite_rounded, '${user.totalLikes}', 'Likes', Colors.redAccent),
                ],
              ),
              const SizedBox(height: 8),
              // Info row: PLZ + Bike + Speed
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (user.postalCode != null && user.postalCode!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 3),
                      Text('PLZ ${user.postalCode}', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                  if (user.bikeName != null && user.bikeName!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.two_wheeler_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 3),
                      Text(user.bikeName!, style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                  if (user.speed > 1)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.speed_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 3),
                      Text('${user.speed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                    ]),
                ],
              ),
              const SizedBox(height: 14),
              // Profil öffnen Button
              GestureDetector(
                onTap: () {
                  onDismiss();
                  context.push('/profile/${user.userId}');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Profil öffnen',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ]),
          ),
        ),
      )),
    );
  }

  Widget _bubbleStat(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
