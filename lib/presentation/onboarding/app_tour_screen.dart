import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';

/// Post-registration app tour — 6 slides showcasing key features.
class AppTourScreen extends ConsumerStatefulWidget {
  const AppTourScreen({super.key});

  @override
  ConsumerState<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends ConsumerState<AppTourScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = <_TourSlide>[
    _TourSlide(
      image: 'assets/images/1bikerin_welcome.png',
      title: 'Willkommen bei\nMotorinu!',
      subtitle:
          'Deine Community f\u00fcr Biker & Autofans.\nEntdecke was dich alles erwartet!',
      emoji: '\u{1F3CD}\uFE0F',
    ),
    _TourSlide(
      image: 'assets/images/7bikerin_riding.png',
      title: 'Feed, Reels\n& Stories',
      subtitle:
          'Teile Fotos, Videos und Storys mit der Community.\nFolge anderen Ridern und entdecke neuen Content.',
      emoji: '\u{1F4F8}',
    ),
    _TourSlide(
      image: 'assets/images/8bikerin_track.png',
      title: 'Navigation\n& Touren',
      subtitle:
          'Plane Routen, tracke deine Fahrten und\nsammle Kilometer. Jeder km bringt XP!',
      emoji: '\u{1F5FA}\uFE0F',
    ),
    _TourSlide(
      image: 'assets/images/9bike_how_many_bikes.png',
      title: 'Marktplatz',
      subtitle:
          'Kaufe und verkaufe Bikes, Teile & Zubeh\u00f6r.\nMit Sofortkauf, Angeboten und sicherem Chat.',
      emoji: '\u{1F6D2}',
    ),
    _TourSlide(
      image: 'assets/images/10bikerin_diy.png',
      title: 'XP, Level\n& Erfolge',
      subtitle:
          'Sammle XP f\u00fcr Posts, Likes, Fahrten und\nKommentare. Steige im Level auf und\nschalte Badges frei!',
      emoji: '\u{1F3C6}',
    ),
    _TourSlide(
      image: 'assets/images/13bikerin_profile.png',
      title: 'Los geht\u2019s!',
      subtitle:
          'Dein Profil ist bereit.\nStarte jetzt und werde Teil der Community!',
      emoji: '\u{1F680}',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      HapticFeedback.lightImpact();
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? const Color(0xFFCC0000);
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Skip button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Motorinu icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/motorino_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        '\u00dcberspringen',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Page content ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),

                        // ── Image ──
                        Image.asset(
                          slide.image,
                          height: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                            slide.emoji,
                            style: const TextStyle(fontSize: 120),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Emoji accent ──
                        Text(
                          slide.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),

                        const SizedBox(height: 16),

                        // ── Title ──
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Subtitle ──
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.5,
                          ),
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Dot indicator ──
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ── Next / Start button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? accentColor : accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast ? 'App starten \u{1F680}' : 'Weiter',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Data class for a single tour slide.
class _TourSlide {
  const _TourSlide({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.emoji,
  });

  final String image;
  final String title;
  final String subtitle;
  final String emoji;
}
