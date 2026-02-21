import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'comic_speech_bubble.dart';
import 'mini_keyboard.dart';

class PostalCodeStepWidget extends StatefulWidget {
  final String postalCode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNext;
  final String userName;
  final int submitAttempt;

  const PostalCodeStepWidget({
    super.key,
    required this.postalCode,
    this.onChanged,
    this.onNext,
    this.userName = '',
    this.submitAttempt = 0,
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/5bikerin_plz.png';

  @override
  State<PostalCodeStepWidget> createState() => _PostalCodeStepWidgetState();
}

class _PostalCodeStepWidgetState extends State<PostalCodeStepWidget> {
  late final TextEditingController _c;
  late final MiniKeyboardController _kb;

  int _lastSubmitAttempt = 0;
  bool _showError = false;
  bool _settingText = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.postalCode);
    _kb = MiniKeyboardController(_c, onChanged: () => widget.onChanged?.call(_c.text));
    _c.addListener(() {
      if (_settingText) return;
      final before = _c.text;
      final sanitized = _sanitizePlz(before);
      if (sanitized != before) {
        _settingText = true;
        _c.value = _c.value.copyWith(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
          composing: TextRange.empty,
        );
        _settingText = false;
      }
      if (_showError && _isValidPlz(_c.text.trim())) {
        // hide error bubble once input becomes valid
        setState(() => _showError = false);
      }
      if (mounted) setState(() {});
      widget.onChanged?.call(_c.text);
    });
}

  String _sanitizePlz(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 6) return digits;
    return digits.substring(0, 6);
  }

  bool _isValidPlz(String v) => RegExp(r'^\d{4,6}$').hasMatch(v);

  @override
  void didUpdateWidget(covariant PostalCodeStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submitAttempt != oldWidget.submitAttempt) {
      _lastSubmitAttempt = widget.submitAttempt;
      final v = _sanitizePlz(_c.text.trim());
      final ok = _isValidPlz(v);
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
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            PostalCodeStepWidget._carbonAsset,
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
                // HERO + bubbles overlay (in-image look)
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
                      final rightInset = (w * 0.30).clamp(90.0, 200.0);

                      final v = _sanitizePlz(_c.text.trim());
                      final ok = _isValidPlz(v);
                      final showHint = _showError && !ok;

                      final mainBubble = ComicSpeechBubble(
                        text: 'Wo bist du zuhause?\nDeine Postleitzahl reicht 😊',
                        tailOnRight: true,
                        opacity: 0.95,
                        overlayShiftY: 0,
                      );

                      final hintBubble = const ComicSpeechBubble(
                        text: 'Bitte eine gültige PLZ eingeben!\n(4–6 Ziffern)',
                        tailOnRight: true,
                        opacity: 0.98,
                        bubbleColor: Color(0xFFFFE8E8),
                        borderColor: Color(0xFFE53935),
                      );

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              PostalCodeStepWidget._heroAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                alignment: Alignment.center,
                                color: Colors.black.withOpacity(0.2),
                                child: const Text(
                                  'Bild fehlt: 5bikerin_plz.png',
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
                                    Colors.black.withOpacity(0.30),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 390,
                            top: 1,
                            right: rightInset,
                            child: mainBubble,
                          ),
                          if (showHint)
                            Positioned(
                              right: 20,
                              top: 110,
                              child: SizedBox(
                                width: (w * 0.36).clamp(170.0, 250.0),
                                child: hintBubble,
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
                        'Postleitzahl',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 1.2.h),

                      // Important: keep OS keyboard closed.
                      TextField(
                        controller: _c,
                        readOnly: true,
                        showCursor: true,
                        onTap: () => FocusScope.of(context).unfocus(),
                        maxLength: 10,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          hintText: 'z.B. 80331',
                          counterText: '',
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

                      SizedBox(height: 1.2.h),

                      // Mini NUM keyboard (default)
                      MiniNumericKeyboard(
                        kb: _kb,
                        maxLength: 10,
                        showOk: false,
                        onOk: widget.onNext,
                      ),

                      SizedBox(height: 1.0.h),
                      Text(
                        'Keine Sorge – wir zeigen deine genaue Adresse nicht.',
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
