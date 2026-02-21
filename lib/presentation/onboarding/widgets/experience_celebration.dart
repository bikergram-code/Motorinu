import 'dart:math';

import 'package:flutter/material.dart';

/// Celebration overlay that shows falling trophies + particles.
///  - Gold rain (🏆 + ✨) for 40+ years experience
///  - Silver rain (🥈 + ⭐) for 30+ years experience
///
/// Usage:
/// ```dart
/// ExperienceCelebration.maybeShow(context, experienceYears);
/// ```
class ExperienceCelebration {
  ExperienceCelebration._();

  /// Show celebration if experience qualifies.
  /// Returns true if a celebration was shown.
  static bool maybeShow(BuildContext context, int experienceYears) {
    if (experienceYears >= 40) {
      _show(context, _CelebrationTier.gold);
      return true;
    }
    if (experienceYears >= 30) {
      _show(context, _CelebrationTier.silver);
      return true;
    }
    return false;
  }

  static void _show(BuildContext context, _CelebrationTier tier) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationOverlay(
        tier: tier,
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

enum _CelebrationTier { gold, silver }

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({
    required this.tier,
    required this.onComplete,
  });

  final _CelebrationTier tier;
  final VoidCallback onComplete;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _rainController;
  late final AnimationController _trophyController;
  late final AnimationController _fadeController;
  final _random = Random();
  late final List<_Particle> _particles;
  late final _Trophy _trophy;

  @override
  void initState() {
    super.initState();

    final isGold = widget.tier == _CelebrationTier.gold;

    // Generate particles
    _particles = List.generate(isGold ? 50 : 35, (_) {
      return _Particle(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.6,
        speed: 0.3 + _random.nextDouble() * 0.7,
        size: 10.0 + _random.nextDouble() * 16.0,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
        emoji: isGold
            ? _goldEmojis[_random.nextInt(_goldEmojis.length)]
            : _silverEmojis[_random.nextInt(_silverEmojis.length)],
      );
    });

    _trophy = _Trophy(
      emoji: isGold ? '\u{1F3C6}' : '\u{1F948}',
      label: isGold ? 'LEGENDE!' : 'VETERAN!',
      sublabel: isGold ? '40+ Jahre Erfahrung' : '30+ Jahre Erfahrung',
      color: isGold ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0),
      glowColor: isGold
          ? const Color(0xFFFF8F00)
          : const Color(0xFF90A4AE),
    );

    // Rain animation (particles falling)
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Trophy scale + bounce
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Fade out
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );

    _rainController.forward();
    _trophyController.forward();

    // Start fade out after 2.5s, remove after 3s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _fadeController.reverse();
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _rainController.dispose();
    _trophyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  static const _goldEmojis = [
    '\u{1F3C6}', // 🏆
    '\u2728',    // ✨
    '\u{1F31F}', // 🌟
    '\u{1F451}', // 👑
    '\u{1F525}', // 🔥
  ];

  static const _silverEmojis = [
    '\u{1F948}', // 🥈
    '\u2B50',    // ⭐
    '\u{1F4AB}', // 💫
    '\u26A1',    // ⚡
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _rainController,
        _trophyController,
        _fadeController,
      ]),
      builder: (context, _) {
        final fade = _fadeController.value;

        return IgnorePointer(
          child: Opacity(
            opacity: fade,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  // ── Particles ──
                  ..._particles.map((p) {
                    final progress = (_rainController.value - p.delay)
                        .clamp(0.0, 1.0) *
                        p.speed;
                    final y = -p.size + progress * (size.height + p.size * 2);
                    final x = p.x * size.width +
                        sin(progress * 3 + p.rotation) * 30;
                    final rotation =
                        p.rotation + progress * p.rotationSpeed * 2;
                    final opacity =
                        progress < 0.1 ? progress / 0.1 : 1.0;

                    return Positioned(
                      left: x,
                      top: y,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Text(
                            p.emoji,
                            style: TextStyle(fontSize: p.size),
                          ),
                        ),
                      ),
                    );
                  }),

                  // ── Center Trophy ──
                  Center(
                    child: _buildTrophy(size),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrophy(Size screenSize) {
    final scale = Curves.elasticOut.transform(
      _trophyController.value.clamp(0.0, 1.0),
    );
    final isGold = widget.tier == _CelebrationTier.gold;

    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glow circle behind trophy
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _trophy.glowColor.withValues(alpha: 0.4),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _trophy.emoji,
                style: const TextStyle(fontSize: 72),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _trophy.color.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _trophy.glowColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _trophy.label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _trophy.color,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: _trophy.glowColor.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _trophy.sublabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isGold
                        ? const Color(0xFFFFE082)
                        : const Color(0xFFB0BEC5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.emoji,
  });

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final String emoji;
}

class _Trophy {
  _Trophy({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.glowColor,
  });

  final String emoji;
  final String label;
  final String sublabel;
  final Color color;
  final Color glowColor;
}
