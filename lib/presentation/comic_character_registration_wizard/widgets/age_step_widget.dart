import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'comic_speech_bubble.dart';

/// AGE STEP (clean):
/// - NO reward popups
/// - NO slider mini-badges/seals
/// - Funny age tiers 8..110
///
/// Backward compatible API:
/// - accepts either onAgeChanged OR onChanged
/// - keeps reservedBottomPx (ignored here)
class AgeStepWidget extends StatefulWidget {
  final int? age;
  final String userName;

  /// Older API used by some wizard versions.
  final ValueChanged<int>? onAgeChanged;

  /// Newer API used by other steps.
  final ValueChanged<int>? onChanged;

  /// Some versions pass this to avoid overlaps; ignored here (no popups).
  final double reservedBottomPx;

  const AgeStepWidget({
    super.key,
    required int? age,
    this.onAgeChanged,
    this.onChanged,
    this.reservedBottomPx = 0,
    this.userName = '',
  }) : age = age;

  @override
  State<AgeStepWidget> createState() => _AgeStepWidgetState();
}

class _AgeStepWidgetState extends State<AgeStepWidget> {
  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/4bikerin_age.png';

  late int _age;

  @override
  void initState() {
    super.initState();
    _age = (widget.age ?? 18).clamp(8, 110);
  }

  @override
  void didUpdateWidget(covariant AgeStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.age != widget.age && widget.age != null) {
      _age = widget.age!.clamp(8, 110);
    }
  }

  void _emit(int v) {
    widget.onAgeChanged?.call(v);
    widget.onChanged?.call(v);
  }

  void _setAge(int v) {
    final clamped = v.clamp(8, 110);
    if (_age != clamped) {
      setState(() => _age = clamped);
    }
    _emit(clamped);
  }

  _AgeTier _tierFor(int a) {
    final x = a.clamp(8, 110);
    if (x <= 18) {
      return const _AgeTier('Jungspund', '8–18: frisch auf dem Sattel 🍼🏍️', Icons.emoji_emotions_rounded);
    }
    if (x <= 29) {
      return const _AgeTier('Erwachsener', '19–29: Gas geben, aber mit Plan 😎', Icons.directions_bike_rounded);
    }
    if (x <= 39) {
      return const _AgeTier('Touren-Profi', '30–39: Straße lesen wie ein Buch 📖', Icons.map_rounded);
    }
    if (x <= 49) {
      return const _AgeTier('Kurven-Koenig', '40–49: Kurven? Bring it on 👑', Icons.route_rounded);
    }
    if (x <= 59) {
      return const _AgeTier('Chrom-Veteran', '50–59: Erfahrung glaenzt wie Chrom ✨', Icons.auto_awesome_rounded);
    }
    if (x <= 69) {
      return const _AgeTier('Oldschool Biker', '60–69: cool, bevor es cool war 🧓', Icons.album_rounded);
    }
    if (x <= 79) {
      return const _AgeTier('Legenden-Modus', '70–79: Legende on tour 🏆', Icons.emoji_events_rounded);
    }
    if (x <= 89) {
      return const _AgeTier('Road-Senior', '80–89: Asphalt-Professor 🎓', Icons.school_rounded);
    }
    if (x <= 99) {
      return const _AgeTier('Hardcore Rider', '90–99: "Geht noch!" 💪', Icons.fitness_center_rounded);
    }
    return const _AgeTier('Grabsteher Biker', '100–110: unsterblich… fast 😄', Icons.star_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = _tierFor(_age);

    final bubbleRightInset = (MediaQuery.of(context).size.width * 0.30).clamp(120.0, 240.0);
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
                // HERO + bubble overlay (in-image look)
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          _heroAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            alignment: Alignment.center,
                            color: Colors.black.withOpacity(0.2),
                            child: const Text(
                              'Bild fehlt: 4bikerin_age.png',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.center,
                                colors: [
                                  Colors.black.withOpacity(0.30),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 292,
                        right: bubbleRightInset,
                        top: 1,
                        child: ComicThoughtBubble(
                          text: (widget.userName.trim().isNotEmpty)
                              ? '''Alles klar, ${widget.userName.trim()}!
Wie alt bist du?
Zieh am Regler 😄'''
                              : '''Wie alt bist du?
Zieh am Regler 😄''',
                          opacity: 0.95,
                          dotsOnRight: false,
                          textColor: Colors.black87,
                        ),
                      ),
                    ],
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
                              'Alter',
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
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.22)),
                            ),
                            child: Text(
                              '$_age',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 1.2.h),

                      // Replaces badges/seals with a clear tier row
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.22)),
                            ),
                            child: Icon(tier.icon, size: 24, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stufe: ${tier.label}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  tier.tagline,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 1.4.h),

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
                          min: 8,
                          max: 110,
                          divisions: 102,
                          value: _age.toDouble(),
                          label: '$_age',
                          onChanged: (v) => _setAge(v.round()),
                        ),
                      ),

                      SizedBox(height: 0.8.h),
                      Text(
                        'Tipp: Du kannst es spaeter im Profil aendern.',
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

class _AgeTier {
  final String label;
  final String tagline;
  final IconData icon;
  const _AgeTier(this.label, this.tagline, this.icon);
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
