import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bikergram/widgets/bikergram_progress_bar.dart';

/// A reusable "scene" wrapper for the comic registration wizard.
/// Carbon background + hero image + speech bubble + frosted content card.
///
/// IMPORTANT: uses Align/Padding instead of Positioned to avoid ParentDataWidget issues.
class WizardSceneShell extends StatelessWidget {
  final Widget child;
  final String? heroImageAsset;
  final String? carbonAsset;
  final String? tagline;
  final double? progress; // 0..1
  final Widget? topRight;

  const WizardSceneShell({
    super.key,
    required this.child,
    this.heroImageAsset,
    this.carbonAsset,
    this.tagline,
    this.progress,
    this.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isKeyboardOpen = media.viewInsets.bottom > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Background
              Positioned.fill(
                child: _CarbonBackground(asset: carbonAsset),
              ),

              // Foreground layout
              LayoutBuilder(
                builder: (context, c) {
                  final h = c.maxHeight;
                  final w = c.maxWidth;

                  final heroMaxH = (isKeyboardOpen ? h * 0.22 : h * 0.36).clamp(160.0, 360.0);
                  final cardTopGap = (isKeyboardOpen ? 10.0 : 18.0);

                  return Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 48),
                          const Spacer(),
                          if (topRight != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: topRight!,
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if ((tagline ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _SpeechBubble(text: tagline!.trim()),
                        ),

                      SizedBox(height: (tagline ?? '').trim().isNotEmpty ? 10 : 0),

                      if ((heroImageAsset ?? '').isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: heroMaxH,
                            maxWidth: w,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Image.asset(
                              heroImageAsset!,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ),

                      SizedBox(height: cardTopGap),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: _FrostCard(
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  brightness: Brightness.dark,
                                  scaffoldBackgroundColor: Colors.transparent,
                                  textTheme: Theme.of(context).textTheme.apply(
                                        bodyColor: Colors.white,
                                        displayColor: Colors.white,
                                      ),
                                  iconTheme: const IconThemeData(color: Colors.white),
                                  inputDecorationTheme: const InputDecorationTheme(
                                    labelStyle: TextStyle(color: Colors.white),
                                    hintStyle: TextStyle(color: Color(0xCCFFFFFF)),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0x66FFFFFF)),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                  ),
                                ),
                                child: _AutoFitScroll(child: child),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Progress overlay
              if (progress != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _TopProgress(value: progress!.clamp(0.0, 1.0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoFitScroll extends StatelessWidget {
  final Widget child;
  const _AutoFitScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 30),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

class _FrostCard extends StatelessWidget {
  final Widget child;
  const _FrostCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x99111111),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CarbonBackground extends StatelessWidget {
  final String? asset;
  const _CarbonBackground({this.asset});

  @override
  Widget build(BuildContext context) {
    if ((asset ?? '').isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF000000)],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset!, fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.35)),
      ],
    );
  }
}

class _TopProgress extends StatelessWidget {
  final double value;
  const _TopProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(18),
    );
    final paint = Paint()..color = const Color(0xCC1A1A1A);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x55FFFFFF);

    canvas.drawRRect(r, paint);
    canvas.drawRRect(r, border);

    final path = Path();
    final cx = size.width / 2;
    path.moveTo(cx - 10, size.height - 10);
    path.lineTo(cx, size.height);
    path.lineTo(cx + 10, size.height - 10);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}