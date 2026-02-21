import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'biker_rewards.dart';
import 'comic_speech_bubble.dart';

class TrackExperienceStepWidget extends StatelessWidget {
  final bool? hasTrackExperience;
  final String userName;
  final bool? hasExperience;
  final ValueChanged<bool>? onTrackExperienceChanged;
  final ValueChanged<bool>? onChanged;

  const TrackExperienceStepWidget({
    super.key,
    this.hasTrackExperience,
    this.onTrackExperienceChanged,
    this.hasExperience,
    this.onChanged,
    this.userName = '',
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/8bikerin_track.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget option({
      required bool value,
      required String title,
      required String subtitle,
      required IconData icon,
    }) {
      final current = (hasTrackExperience ?? hasExperience ?? false);
      final selected = current == value;
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          onTrackExperienceChanged?.call(value);
          onChanged?.call(value);
          if (value == true) {
            BikerRewards.awardTrackTrophyOnce(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withOpacity(0.18)
                : theme.colorScheme.surface.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.55)
                  : theme.colorScheme.outline.withOpacity(0.18),
              width: selected ? 2 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 18,
                      color: theme.colorScheme.primary.withOpacity(0.18),
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.20),
                  ),
                ),
                child: Icon(icon, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _carbonAsset,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.22),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF15181E), Color(0xFF07080B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),

                ComicSpeechBubble(
                  text: (userName.trim().isNotEmpty)
                      ? '''${userName.trim()}, warst du schonmal
selbst auf der Rennstrecke? 🏁'''
                      : '''Bist du schonmal auf der
Rennstrecke selbst gefahren? 🏁''',
                  tailOnRight: true,
                  opacity: 0.95,
                ),

                SizedBox(height: 2.h),

                Container(
                  height: 30.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        color: Colors.black.withOpacity(0.35),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    _heroAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      alignment: Alignment.center,
                      color: Colors.black.withOpacity(0.2),
                      child: const Text(
                        'Bild fehlt: 8bikerin_track.png',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 2.2.h),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      option(
                        value: true,
                        title: 'Ja, schon gefahren',
                        subtitle: 'Ich habe Track-Erfahrung oder Trackdays gemacht.',
                        icon: Icons.flag,
                      ),
                      SizedBox(height: 1.2.h),
                      option(
                        value: false,
                        title: 'Noch nie',
                        subtitle: 'Ich fahre (noch) nicht auf der Rennstrecke.',
                        icon: Icons.emoji_people,
                      ),
                      SizedBox(height: 0.8.h),
                      Text(
                        'Du kannst das später jederzeit ändern.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}
