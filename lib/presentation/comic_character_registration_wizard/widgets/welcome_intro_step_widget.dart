import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class WelcomeIntroStepWidget extends StatefulWidget {
  final VoidCallback onAutoNext;
  final Duration totalHold;

  const WelcomeIntroStepWidget({
    super.key,
    required this.onAutoNext,
    this.totalHold = const Duration(milliseconds: 4200),
  });

  @override
  State<WelcomeIntroStepWidget> createState() => _WelcomeIntroStepWidgetState();
}

class _WelcomeIntroStepWidgetState extends State<WelcomeIntroStepWidget> {
  static const String _text = 'Willkommen bei\nBikergram';
  static const String _heroAsset = 'assets/images/bikerin_idle23.png';
  static const String _carbonAsset = 'assets/images/carbon.png';

  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _autoNextTimer = Timer(widget.totalHold, () {
      if (mounted) widget.onAutoNext();
    });
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxWidth;
          final maxH = c.maxHeight;

          final heroSize = math.min(maxW * 0.78, maxH * 0.48);
          final titleSize = (42.sp).clamp(26.0, 42.0);

          return Stack(
            children: [
              // ✅ Carbon image background
              Positioned.fill(
                child: Image.asset(
                  _carbonAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  // Darken slightly for premium look & text contrast
                  color: Colors.black.withOpacity(0.18),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) {
                    // If carbon asset missing, fallback to solid surface
                    return Container(color: theme.colorScheme.surface);
                  },
                ),
              ),

              // ✅ Extra depth: top-to-bottom shade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        Colors.black.withOpacity(0.28),
                        Colors.black.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ✅ Subtle premium color wash
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface.withOpacity(0.35),
                        theme.colorScheme.surface.withOpacity(0.12),
                        theme.colorScheme.secondaryContainer.withOpacity(0.12),
                      ],
                    ),
                  ),
                ),
              ),

              // ✅ Content
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: maxH),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 3.h),

                          // HERO Circle
                          Center(
                            child: Container(
                              width: heroSize,
                              height: heroSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.22),
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Transform.scale(
                                          scale: 0.92,
                                          child: Image.asset(
                                            _heroAsset,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.black,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  size: 48,
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Premium overlay (no blur)
                                    Container(
                                      color: Colors.black.withOpacity(0.14),
                                    ),

                                    // Vignette
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          radius: 0.95,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.22),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 2.2.h),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    height: 1.02,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'cursive',
                                    color: theme.colorScheme.onSurface,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.30),
                                        blurRadius: 14,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 1.4.h),
                                Text(
                                  'die interaktive Biker App',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          Center(
                            child: SizedBox(
                              width: math.min(maxW * 0.82, 520),
                              height: 48,
                              child: const _BikerRoadLoader(),
                            ),
                          ),

                          SizedBox(height: 2.0.h),

                          Text(
                            'Motor an…',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          SizedBox(height: 3.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 🏍️ Loader (Stateful, eigener Controller -> garantiert nicht starr)
class _BikerRoadLoader extends StatefulWidget {
  const _BikerRoadLoader();

  @override
  State<_BikerRoadLoader> createState() => _BikerRoadLoaderState();
}

class _BikerRoadLoaderState extends State<_BikerRoadLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.22), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoadPainter(offset: t * 30),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final ease = Curves.easeInOut.transform(t);
                    final startX = -36.0;
                    final endX = c.maxWidth + 8.0;
                    final x = startX + (endX - startX) * ease;

                    final bob = math.sin(t * math.pi * 2) * 1.6;
                    final tilt = math.sin(t * math.pi * 2) * 0.06;

                    return Stack(
                      children: [
                        Positioned(
                          left: x,
                          top: (c.maxHeight - 28) / 2 + bob,
                          child: Transform.rotate(
                            angle: tilt,
                            child: Icon(
                              Icons.two_wheeler_rounded,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double offset;
  _RoadPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.32)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dash = 12.0;
    const gap = 10.0;
    final y = size.height / 2;

    double x = -(offset % (dash + gap));
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.offset != offset;
}
