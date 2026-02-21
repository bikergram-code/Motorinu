import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'biker_rewards.dart';
import 'comic_speech_bubble.dart';

class BikeCountStepWidget extends StatelessWidget {
  final int? bikeCount;
  final String userName;
  final int? initialBikeCount;
  final ValueChanged<int>? onBikeCountChanged;
  final ValueChanged<int>? onChanged;

  const BikeCountStepWidget({
    super.key,
    required int? bikeCount,
    this.onBikeCountChanged,
    this.onChanged,
    this.userName = '',
  })  : bikeCount = bikeCount,
        initialBikeCount = bikeCount;

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/9bike_how_many_bikes.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = (bikeCount ?? initialBikeCount ?? 0).clamp(0, 60);
    final tierLabel = BikerRewards.bikeTierLabel(v);
    final tierIcon = BikerRewards.bikeTierIcon(tierLabel);

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
                      ? '''Okay ${userName.trim()} – wie viele Bikes besitzt du? 🏍️'''
                      : '''Wie viele Bikes besitzt du?
Eins oder gleich mehrere? 🏍️''',
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
                        'Bild fehlt: 9bike_how_many_bikes.png',
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
                              'Anzahl Bikes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
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
                              '$v',
                              style: theme.textTheme.titleLarge?.copyWith(
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
                          max: 60,
                          divisions: 60,
                          value: v.toDouble(),
                          label: '$v',
                          onChanged: (val) {
                          final vv = val.round();
                          onBikeCountChanged?.call(vv);
                          onChanged?.call(vv);
                          BikerRewards.maybeBikeTierReward(context, bikeCount: vv);
                        },
                        ),
                      ),

                      SizedBox(height: 0.8.h),

                      Text(
                        'Auch Roller oder Projekte zählen 😉',
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
