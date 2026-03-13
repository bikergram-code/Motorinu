import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';

/// Compact toggle button for switching between bikergram and cargram.
/// Designed for the feed screen header. Tapping opens a dropdown-style
/// bottom sheet to pick the community.
class CommunitySwitcher extends ConsumerWidget {
  const CommunitySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? const Color(0xFFFF6B35);

    return GestureDetector(
      onTap: () => _showSwitcher(context, ref, community, brightness),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Community icon
            Icon(
              community == Community.cargram
                  ? Icons.directions_car_rounded
                  : Icons.two_wheeler_rounded,
              color: accentColor,
              size: 18,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz_rounded,
              color: accentColor.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitcher(
    BuildContext context,
    WidgetRef ref,
    Community? current,
    Brightness brightness,
  ) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Community wechseln',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                // Bikergram option
                _CommunityOption(
                  community: Community.bikergram,
                  isActive: current == Community.bikergram,
                  brightness: brightness,
                  onTap: () {
                    ref.read(communityProvider.notifier).select(Community.bikergram);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                // Cargram option
                _CommunityOption(
                  community: Community.cargram,
                  isActive: current == Community.cargram,
                  brightness: brightness,
                  onTap: () {
                    ref.read(communityProvider.notifier).select(Community.cargram);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommunityOption extends StatelessWidget {
  const _CommunityOption({
    required this.community,
    required this.isActive,
    required this.brightness,
    required this.onTap,
  });

  final Community community;
  final bool isActive;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = community.accentColor;
    final textColor = brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);
    final mutedColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF6C757D);

    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.1)
              : (brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                community == Community.cargram
                    ? Icons.directions_car_rounded
                    : Icons.two_wheeler_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isActive ? accentColor : textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    community.tagline,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark
            if (isActive)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }
}
