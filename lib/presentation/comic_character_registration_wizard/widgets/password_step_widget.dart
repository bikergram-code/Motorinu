import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import 'bikergram_carbon_background.dart';
import 'comic_speech_bubble.dart';
import 'glass_card.dart';
import 'mini_keyboard.dart';
import 'wizard_assets.dart';

class PasswordStepWidget extends StatefulWidget {
  final String? initialPassword;
  final ValueChanged<String>? onPasswordChanged;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNext;

  /// For direct addressing in the bubbles
  final String userName;

  /// Increments whenever the user presses "Weiter" with invalid input.
  final int submitAttempt;

  const PasswordStepWidget({
    super.key,
    this.initialPassword,
    this.onPasswordChanged,
    this.onChanged,
    this.onNext,
    this.userName = '',
    this.submitAttempt = 0,
  });

  @override
  State<PasswordStepWidget> createState() => _PasswordStepWidgetState();
}

class _PasswordStepWidgetState extends State<PasswordStepWidget> {
  late final TextEditingController _c;
  late final MiniKeyboardController _kb;

  bool _obscure = true;
  bool _isValid = false;

  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialPassword ?? '');
    _kb = MiniKeyboardController(_c);

    _emit(_c.text);

    _c.addListener(() {
      _emit(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant PasswordStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submitAttempt != oldWidget.submitAttempt) {
      // only show the warning bubble after an actual "submit" attempt
      setState(() => _showError = !_isValid);
    }
  }

  void _emit(String v) {
    final ok = v.trim().length >= 8;
    if (ok != _isValid) setState(() => _isValid = ok);

    // hide error bubble as soon as it becomes valid again
    if (_showError && ok) setState(() => _showError = false);

    widget.onPasswordChanged?.call(v);
    widget.onChanged?.call(v);
  }

  void _toggleObscure() {
    HapticFeedback.selectionClick();
    setState(() => _obscure = !_obscure);
  }

  @override
  void dispose() {
    _c.dispose();
    _kb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hero = Image.asset(
      WizardAssets.heroForStep(11),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final mainBubble = ComicSpeechBubble(
      text: widget.userName.trim().isNotEmpty
          ? '${widget.userName.trim()}, jetzt noch ein Passwort.\nMindestens 8 Zeichen 😊'
          : 'Jetzt noch ein Passwort.\nMindestens 8 Zeichen 😊',
      opacity: 0.96,
      tailOnRight: true,
      enableTypewriter: true,
      autoStart: true,
    );

    return BikergramCarbonBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final size = c.biggest;

            return Column(
              children: [
                // HERO + BUBBLES
                SizedBox(
                  height: size.height * 0.46,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 6.w,
                              right: 6.w,
                              top: 2.h,
                              bottom: 0,
                            ),
                            child: hero,
                          ),
                        ),
                      ),

                      Positioned(
                        left: 14,
                        top: 18,
                        child: SizedBox(
                          width: size.width * 0.74,
                          child: mainBubble,
                        ),
                      ),

                      if (_showError)
                        Positioned(
                          left: 14,
                          top: 108,
                          child: SizedBox(
                            width: size.width * 0.74,
                            child: ComicThoughtBubble(
                              text: 'Eingabe nötig!\nPasswort: mind. 8 Zeichen.',
                              opacity: 0.98,
                              dotsOnRight: false,
                              textColor: Colors.redAccent,
                              borderColor: Colors.redAccent,
                              bubbleColor: Colors.white,
                              enableTypewriter: false,
                              autoStart: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // INPUT AREA
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4.w, 1.2.h, 4.w, 2.h),
                    child: GlassCard(
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _c,
                                    obscureText: _obscure,
                                    enableInteractiveSelection: false,
                                    readOnly: true,
                                    showCursor: true,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Passwort',
                                      hintText: 'mind. 8 Zeichen',
                                      prefixIcon: Icon(
                                        _isValid ? Icons.lock : Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: _toggleObscure,
                                        icon: Icon(
                                          _obscure ? Icons.visibility : Icons.visibility_off,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.2.h),

                            MiniPasswordKeyboard(
                              kb: _kb,
                              showOk: false,
                              onOk: widget.onNext,
                            ),

                            SizedBox(height: 0.8.h),

                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _isValid ? 0.0 : 1.0,
                              child: Text(
                                'Mind. 8 Zeichen (am besten mit Zahlen).',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}
