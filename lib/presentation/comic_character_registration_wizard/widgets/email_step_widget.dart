import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'comic_speech_bubble.dart';
import 'mini_keyboard.dart';

class EmailStepWidget extends StatefulWidget {
  final String email;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNext;
  final String userName;
  final int submitAttempt;

  const EmailStepWidget({
    super.key,
    required this.email,
    this.onChanged,
    this.onNext,
    this.userName = '',
    this.submitAttempt = 0,
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/6bikerin_email.png';

  @override
  State<EmailStepWidget> createState() => _EmailStepWidgetState();
}

class _EmailStepWidgetState extends State<EmailStepWidget> {
  late final TextEditingController _c;
  late final MiniKeyboardController _kb;

  bool _settingText = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.email);
    _kb = MiniKeyboardController(_c, onChanged: () => widget.onChanged?.call(_c.text));
    _c.addListener(() {
      if (_settingText) return;
      final before = _c.text;
      final sanitized = _sanitizeEmail(before);
      if (sanitized != before) {
        _settingText = true;
        _c.value = _c.value.copyWith(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
          composing: TextRange.empty,
        );
        _settingText = false;
      }
      if (_showError && _isValidEmail(_c.text)) {
        setState(() => _showError = false);
      }
      if (mounted) setState(() {});
      widget.onChanged?.call(_c.text);
    });
}

  String _sanitizeEmail(String raw) {
    // remove spaces; keep user intention otherwise
    final s = raw.replaceAll(' ', '');
    if (s.length <= 70) return s;
    return s.substring(0, 70);
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    final at = s.indexOf('@');
    final dot = s.lastIndexOf('.');
    if (at <= 0) return false;
    if (dot <= at + 1) return false;
    if (dot >= s.length - 1) return false;
    return true;
  }

  @override
  void didUpdateWidget(covariant EmailStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submitAttempt != oldWidget.submitAttempt) {
      final v = _sanitizeEmail(_c.text);
      final ok = _isValidEmail(v);
      setState(() => _showError = !ok);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            EmailStepWidget._carbonAsset,
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
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final rightInset = (w * 170.0).clamp(170.0, 300.0);

                      final mainBubble = ComicSpeechBubble(
                        text: 'Fast geschafft! Welche E‑Mail\nsoll dein Account nutzen? 📧',
                        tailOnRight: true,
                        opacity: 0.95,
                        overlayShiftY: 0,
                      );

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              EmailStepWidget._heroAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                alignment: Alignment.center,
                                color: Colors.black.withOpacity(0.2),
                                child: const Text(
                                  'Bild fehlt: 6bikerin_email.png',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.28),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 82,
                            top: 1,
                            right: rightInset,
                            child: mainBubble,
                          ),

                    if (_showError)
                      Positioned(
                        left: 20,
                        top: 98,
                        child: SizedBox(
                          width: size.width * 0.70,
                          child: const ComicSpeechBubble(
                          text: 'Eingabe nötig!\nE-Mail muss @ und . enthalten.',
                          tailOnRight: true,
                          opacity: 0.98,
                          bubbleColor: Color(0xFFFFE8E8),
                          borderColor: Color(0xFFE53935),
                        ),
                        ),
                      ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 2.2.h),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'E‑Mail',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 1.2.h),

                      // Important: keep OS keyboard closed.
                      TextField(
                        controller: _c,
                        readOnly: true,
                        showCursor: true,
                        onTap: () => FocusScope.of(context).unfocus(),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          hintText: 'z.B. biker@bikergram.de',
                          filled: true,
                          fillColor: theme.colorScheme.surface.withOpacity(0.95),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.22)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.22)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                        ),
                      ),

                      SizedBox(height: 1.6.h),

                      // Mini EMAIL keyboard (default)
                      MiniEmailKeyboard(
                        kb: _kb,
                        showOk: false,
                        onOk: widget.onNext,
                      ),

                      SizedBox(height: 1.0.h),
                      Text(
                        'Wir schicken dir nur wichtige Infos – kein Spam.',
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
    final size = MediaQuery.of(context).size;
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
