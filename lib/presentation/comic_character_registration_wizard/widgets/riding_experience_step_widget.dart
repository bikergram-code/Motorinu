import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'biker_rewards.dart';
import 'comic_speech_bubble.dart';

class RidingExperienceStepWidget extends StatelessWidget {
  final double experience;
  final String userName;
  final ValueChanged<double> onExperienceChanged;

  const RidingExperienceStepWidget({
    super.key,
    required this.experience,
    required this.onExperienceChanged,
    this.userName = '',
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/7bikerin_riding.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = experience.clamp(0.0, 102.0);
    final years = v.round().clamp(0, 102);
    final tierLabel = BikerRewards.rideTierLabel(years);
    final tierIcon = BikerRewards.rideTierIcon(tierLabel);

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
                      ? '''Okay ${userName.trim()}!
Wie lange fährst du schon Moped?
Roller zählt auch mit – zieh den Regler 🏍️'''
                      : '''Wie lange fährst du schon Moped?
Roller zählt auch mit – zieh den Regler 🏍️''',
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
                        'Bild fehlt: 7bikerin_riding.png',
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Erfahrung',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.22),
                              ),
                            ),
                            child: Icon(tierIcon, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.22),
                              ),
                            ),
                            child: Text(
                              '$years Jahre • $tierLabel',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 1.6.h),

                      SliderTheme(
                        data: theme.sliderTheme.copyWith(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.25),
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withOpacity(0.15),
                        ),
                        child: Slider(
                          min: 0,
                          max: 102,
                          divisions: 102,
                          value: v,
                          label: '$years',
                          onChanged: (val) {
                            onExperienceChanged(val);
                            // Rewards/XP only here (interactive while sliding)
                            BikerRewards.maybeRideTierReward(
                              context,
                              years: val.round(),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 0.8.h),

                      Text(
                        'Das hilft uns, dir passende Tipps, Gruppen und Events zu zeigen.',
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
